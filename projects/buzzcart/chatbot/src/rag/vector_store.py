from __future__ import annotations

import json
import logging
import re
from collections import Counter
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

import faiss
import numpy as np
import torch
from sentence_transformers import CrossEncoder, SentenceTransformer
from transformers import AutoTokenizer

from ..core.config import settings

logger = logging.getLogger(__name__)
INDEX_SCHEMA_VERSION = 3


@dataclass
class SearchMatch:
    text: str
    metadata: Dict[str, Any]
    score: float
    dense_score: float = 0.0
    lexical_score: float = 0.0


class VectorStoreManager:
    """Stores one FAISS index per product and retrieves with dense+lexical fusion."""

    def __init__(self) -> None:
        self.vector_store_dir = Path(settings.VECTOR_STORE_DIR)
        self.model_cache_dir = Path(settings.MODEL_CACHE_DIR)
        self.embedding_model: Optional[SentenceTransformer] = None
        self.reranker: Optional[CrossEncoder] = None
        self.tokenizer = None
        self.model_device = "cpu"

    async def initialize(self) -> None:
        self.vector_store_dir.mkdir(parents=True, exist_ok=True)
        self.model_cache_dir.mkdir(parents=True, exist_ok=True)
        self.model_device = self._resolve_model_device()
        self._configure_torch_runtime()

        logger.info("Using model device: %s", self.model_device)
        if self.model_device.startswith("cuda") and torch.cuda.is_available():
            device_index = self._device_index_from_name(self.model_device)
            logger.info("CUDA device: %s", torch.cuda.get_device_name(device_index))
            try:
                free_memory, total_memory = torch.cuda.mem_get_info(device_index)
                logger.info(
                    "CUDA memory free %.2f GB / %.2f GB",
                    free_memory / (1024 ** 3),
                    total_memory / (1024 ** 3),
                )
            except Exception:
                logger.debug("Could not read CUDA memory info", exc_info=True)

        logger.info("Loading embedding model: %s", settings.EMBEDDING_MODEL_NAME)
        self.embedding_model = SentenceTransformer(
            settings.EMBEDDING_MODEL_NAME,
            cache_folder=str(self.model_cache_dir),
            device=self.model_device,
        )

        logger.info("Loading tokenizer: %s", settings.EMBEDDING_MODEL_NAME)
        self.tokenizer = AutoTokenizer.from_pretrained(
            settings.EMBEDDING_MODEL_NAME,
            cache_dir=str(self.model_cache_dir),
        )

        logger.info("Loading reranker model: %s", settings.RERANKER_MODEL_NAME)
        self.reranker = CrossEncoder(
            settings.RERANKER_MODEL_NAME,
            max_length=512,
            device=self.model_device,
        )

    def count_tokens(self, text: str) -> int:
        if not self.tokenizer:
            raise RuntimeError("Tokenizer not initialized")
        return len(self.tokenizer.encode(text, add_special_tokens=False))

    def chunk_text_by_tokens(self, text: str) -> List[str]:
        if not self.tokenizer:
            raise RuntimeError("Tokenizer not initialized")

        lines = [
            " ".join(line.split())
            for line in re.split(r"[\r\n]+", text)
            if line.strip()
        ]
        if not lines:
            return []

        segments = self._build_segments(lines)
        chunks: List[str] = []
        current_segments: List[str] = []
        current_tokens = 0

        for segment in segments:
            for piece in self._split_long_segment(segment):
                piece_tokens = self.count_tokens(piece)
                if current_segments and current_tokens + piece_tokens > settings.CHUNK_SIZE_TOKENS:
                    chunks.append("\n".join(current_segments).strip())
                    current_segments = self._tail_overlap_segments(current_segments)
                    current_tokens = sum(self.count_tokens(item) for item in current_segments)

                current_segments.append(piece)
                current_tokens += piece_tokens

        if current_segments:
            chunks.append("\n".join(current_segments).strip())

        return chunks

    def build_product_index(
        self,
        product_id: str,
        chunks: List[Dict[str, Any]],
        manifest: Dict[str, Any],
    ) -> None:
        if not self.embedding_model:
            raise RuntimeError("Embedding model not initialized")
        if not chunks:
            raise ValueError("No chunks available to index")

        normalized_chunks: List[Dict[str, Any]] = []
        texts: List[str] = []
        for chunk in chunks:
            text = str(chunk["text"]).strip()
            if not text:
                continue
            metadata = dict(chunk.get("metadata", {}))
            metadata.setdefault("token_count", self.count_tokens(text))
            metadata.setdefault("section_title", self._detect_section_title(text))
            normalized_chunks.append({"text": text, "metadata": metadata})
            texts.append(text)

        if not normalized_chunks:
            raise ValueError("No non-empty chunks available to index")

        embeddings = self.embedding_model.encode(
            texts,
            batch_size=settings.EMBEDDING_BATCH_SIZE,
            normalize_embeddings=True,
            show_progress_bar=False,
            convert_to_numpy=True,
        ).astype("float32")

        index = faiss.IndexFlatIP(embeddings.shape[1])
        index.add(embeddings)

        product_dir = self._product_dir(product_id)
        product_dir.mkdir(parents=True, exist_ok=True)

        faiss.write_index(index, str(product_dir / "index.faiss"))
        (product_dir / "chunks.json").write_text(
            json.dumps(normalized_chunks, ensure_ascii=True, indent=2),
            encoding="utf-8",
        )

        manifest_payload = {
            **manifest,
            "product_id": product_id,
            "chunks_created": len(normalized_chunks),
            "index_version": INDEX_SCHEMA_VERSION,
            "updated_at": datetime.utcnow().isoformat(),
        }
        (product_dir / "manifest.json").write_text(
            json.dumps(manifest_payload, ensure_ascii=True, indent=2),
            encoding="utf-8",
        )
        logger.info("Indexed %s chunks for product %s", len(normalized_chunks), product_id)

    def similarity_search(
        self,
        product_id: str,
        query: str,
        k: Optional[int] = None,
    ) -> List[SearchMatch]:
        if not self.embedding_model:
            raise RuntimeError("Embedding model not initialized")

        product_dir = self._product_dir(product_id)
        index_path = product_dir / "index.faiss"
        chunks = self._load_chunk_payloads(product_id)
        if not chunks or not index_path.exists():
            return []

        index = faiss.read_index(str(index_path))
        query_vector = self.embedding_model.encode(
            [query],
            batch_size=1,
            normalize_embeddings=True,
            show_progress_bar=False,
            convert_to_numpy=True,
        ).astype("float32")

        dense_limit = min(
            max(k or settings.TOP_K_RESULTS, settings.RETRIEVAL_CANDIDATE_POOL),
            len(chunks),
        )
        scores, indices = index.search(query_vector, dense_limit)
        dense_rank: Dict[int, int] = {}
        dense_score_map: Dict[int, float] = {}
        for row_index, score in zip(indices[0], scores[0]):
            if row_index < 0 or row_index >= len(chunks):
                continue
            dense_rank[row_index] = len(dense_rank)
            dense_score_map[row_index] = max(float(score), 0.0)

        lexical_candidates = self._lexical_scores(query, chunks)
        lexical_candidates.sort(key=lambda item: item["score"], reverse=True)
        lexical_candidates = lexical_candidates[: min(settings.LEXICAL_SEARCH_LIMIT, len(lexical_candidates))]
        lexical_rank = {item["index"]: rank for rank, item in enumerate(lexical_candidates)}
        lexical_score_map = {item["index"]: float(item["score"]) for item in lexical_candidates}

        candidate_indices = set(dense_rank) | set(lexical_rank)
        if not candidate_indices:
            return []

        max_dense = max(dense_score_map.values(), default=1.0)
        max_lexical = max(lexical_score_map.values(), default=1.0)
        matches: List[SearchMatch] = []

        for row_index in candidate_indices:
            chunk = chunks[row_index]
            if chunk.get("metadata", {}).get("product_id") != product_id:
                continue

            dense_component = dense_score_map.get(row_index, 0.0) / max(max_dense, 1e-9)
            lexical_component = lexical_score_map.get(row_index, 0.0) / max(max_lexical, 1e-9)
            dense_rrf = 1.0 / (60.0 + dense_rank[row_index]) if row_index in dense_rank else 0.0
            lexical_rrf = 1.0 / (60.0 + lexical_rank[row_index]) if row_index in lexical_rank else 0.0
            hybrid_score = (
                dense_component * 0.45
                + lexical_component * 0.30
                + dense_rrf * 12.0
                + lexical_rrf * 12.0
            )

            matches.append(
                SearchMatch(
                    text=chunk["text"],
                    metadata=chunk["metadata"],
                    score=hybrid_score,
                    dense_score=dense_component,
                    lexical_score=lexical_component,
                )
            )

        matches.sort(key=lambda item: item.score, reverse=True)
        return matches[: min(k or settings.TOP_K_RESULTS, len(matches))]

    def load_product_chunks(self, product_id: str) -> List[SearchMatch]:
        chunks = self._load_chunk_payloads(product_id)
        matches: List[SearchMatch] = []
        for chunk in chunks:
            metadata = chunk.get("metadata", {})
            if metadata.get("product_id") != product_id:
                continue
            matches.append(
                SearchMatch(
                    text=str(chunk.get("text", "")),
                    metadata=metadata,
                    score=0.0,
                )
            )
        return matches

    def expand_matches_with_neighbors(
        self,
        product_id: str,
        matches: List[SearchMatch],
        window: Optional[int] = None,
    ) -> List[SearchMatch]:
        if not matches:
            return []

        chunk_payloads = self._load_chunk_payloads(product_id)
        if not chunk_payloads:
            return matches

        chunk_map = {
            int(chunk.get("metadata", {}).get("chunk_id", -1)): chunk
            for chunk in chunk_payloads
            if chunk.get("metadata", {}).get("product_id") == product_id
        }
        selected: Dict[int, SearchMatch] = {}
        neighbor_window = max(window or settings.NEIGHBOR_WINDOW, 0)

        for match in matches:
            chunk_id = int(match.metadata.get("chunk_id", -1))
            if chunk_id < 0:
                continue
            selected.setdefault(chunk_id, match)

            for delta in range(1, neighbor_window + 1):
                for neighbor_id in (chunk_id - delta, chunk_id + delta):
                    payload = chunk_map.get(neighbor_id)
                    if not payload or neighbor_id in selected:
                        continue
                    selected[neighbor_id] = SearchMatch(
                        text=str(payload.get("text", "")),
                        metadata=dict(payload.get("metadata", {})),
                        score=max(match.score * (0.92**delta), 0.0),
                        dense_score=max(match.dense_score * (0.92**delta), 0.0),
                        lexical_score=max(match.lexical_score * (0.92**delta), 0.0),
                    )

        expanded = list(selected.values())
        expanded.sort(key=lambda item: item.score, reverse=True)
        return expanded

    def rerank_chunks(self, query: str, matches: List[SearchMatch]) -> List[SearchMatch]:
        if not self.reranker or not matches:
            return matches[: settings.RERANK_TOP_K]

        scores = self.reranker.predict(
            [(query, match.text) for match in matches],
            batch_size=settings.RERANK_BATCH_SIZE,
            show_progress_bar=False,
        )
        reranked = [
            SearchMatch(
                text=match.text,
                metadata=match.metadata,
                score=float(score),
                dense_score=match.dense_score,
                lexical_score=match.lexical_score,
            )
            for match, score in zip(matches, scores)
        ]
        reranked.sort(key=lambda item: item.score, reverse=True)
        return reranked[: settings.RERANK_TOP_K]

    def rerank_sentences(
        self,
        query: str,
        candidates: List[Dict[str, Any]],
    ) -> List[Dict[str, Any]]:
        if not self.reranker or not candidates:
            return candidates[: settings.SENTENCE_TOP_K]

        scores = self.reranker.predict(
            [(query, candidate["text"]) for candidate in candidates],
            batch_size=settings.RERANK_BATCH_SIZE,
            show_progress_bar=False,
        )
        ranked: List[Dict[str, Any]] = []
        for candidate, score in zip(candidates, scores):
            enriched = dict(candidate)
            enriched["score"] = float(score)
            ranked.append(enriched)

        ranked.sort(key=lambda item: item["score"], reverse=True)
        return ranked[: settings.SENTENCE_TOP_K]

    def get_product_status(self, product_id: str) -> Dict[str, Any]:
        manifest_path = self._product_dir(product_id) / "manifest.json"
        if not manifest_path.exists():
            return {
                "product_id": product_id,
                "indexed": False,
                "chunks_created": 0,
                "pages_processed": 0,
                "source_name": None,
                "document_url": None,
                "index_version": 0,
                "updated_at": None,
            }

        payload = json.loads(manifest_path.read_text(encoding="utf-8"))
        return {
            "product_id": product_id,
            "indexed": True,
            "chunks_created": int(payload.get("chunks_created", 0)),
            "pages_processed": int(payload.get("pages_processed", 0)),
            "source_name": payload.get("source_name"),
            "document_url": payload.get("document_url"),
            "index_version": int(payload.get("index_version", 0)),
            "updated_at": payload.get("updated_at"),
        }

    def get_product_manifest(self, product_id: str) -> Dict[str, Any]:
        manifest_path = self._product_dir(product_id) / "manifest.json"
        if not manifest_path.exists():
            return {}
        return json.loads(manifest_path.read_text(encoding="utf-8"))

    def should_reindex(self, product_id: str, document_url: Optional[str]) -> bool:
        status = self.get_product_status(product_id)
        if not status["indexed"]:
            return True
        if int(status.get("index_version", 0)) < INDEX_SCHEMA_VERSION:
            return True
        if not document_url:
            return False
        return status.get("document_url") != document_url

    def delete_product_index(self, product_id: str) -> None:
        product_dir = self._product_dir(product_id)
        if not product_dir.exists():
            return
        for path in product_dir.iterdir():
            path.unlink(missing_ok=True)
        product_dir.rmdir()
        logger.info("Deleted vector index for product %s", product_id)

    def _build_segments(self, lines: List[str]) -> List[str]:
        segments: List[str] = []
        buffer: List[str] = []

        for line in lines:
            if self._looks_like_heading(line) or self._looks_like_list_item(line):
                if buffer:
                    segments.append(" ".join(buffer).strip())
                    buffer = []
                segments.append(line.strip())
                continue

            if not buffer:
                buffer = [line]
                continue

            if self._should_join_with_previous(buffer[-1], line):
                buffer.append(line)
            else:
                segments.append(" ".join(buffer).strip())
                buffer = [line]

        if buffer:
            segments.append(" ".join(buffer).strip())

        return [segment for segment in segments if segment]

    def _split_long_segment(self, segment: str) -> List[str]:
        if self.count_tokens(segment) <= settings.CHUNK_SIZE_TOKENS:
            return [segment]

        sentences = [piece.strip() for piece in re.split(r"(?<=[.!?])\s+", segment) if piece.strip()]
        if len(sentences) <= 1:
            return self._hard_split_text(segment)

        parts: List[str] = []
        current: List[str] = []
        current_tokens = 0
        for sentence in sentences:
            sentence_tokens = self.count_tokens(sentence)
            if current and current_tokens + sentence_tokens > settings.CHUNK_SIZE_TOKENS:
                parts.append(" ".join(current).strip())
                current = [sentence]
                current_tokens = sentence_tokens
                continue
            current.append(sentence)
            current_tokens += sentence_tokens

        if current:
            parts.append(" ".join(current).strip())
        return parts

    def _hard_split_text(self, text: str) -> List[str]:
        encoded = self.tokenizer(
            text,
            add_special_tokens=False,
            return_offsets_mapping=True,
            truncation=False,
        )
        input_ids = encoded["input_ids"]
        offsets = encoded["offset_mapping"]
        if not input_ids:
            return []

        pieces: List[str] = []
        start = 0
        step = max(settings.CHUNK_SIZE_TOKENS - settings.CHUNK_OVERLAP_TOKENS, 1)
        while start < len(input_ids):
            end = min(start + settings.CHUNK_SIZE_TOKENS, len(input_ids))
            char_start = offsets[start][0]
            char_end = offsets[end - 1][1]
            piece = text[char_start:char_end].strip()
            if piece:
                pieces.append(piece)
            if end >= len(input_ids):
                break
            start += step
        return pieces

    def _tail_overlap_segments(self, segments: List[str]) -> List[str]:
        overlap_segments: List[str] = []
        overlap_tokens = 0
        for segment in reversed(segments):
            segment_tokens = self.count_tokens(segment)
            if overlap_segments and overlap_tokens + segment_tokens > settings.CHUNK_OVERLAP_TOKENS:
                break
            overlap_segments.insert(0, segment)
            overlap_tokens += segment_tokens
        return overlap_segments

    def _looks_like_heading(self, line: str) -> bool:
        stripped = line.strip()
        if len(stripped) > 90 or len(stripped.split()) > 12:
            return False
        if stripped.endswith((".", "!", "?")):
            return False
        capitalized_words = sum(1 for word in stripped.split() if word[:1].isupper())
        return capitalized_words >= max(1, len(stripped.split()) - 1)

    def _looks_like_list_item(self, line: str) -> bool:
        return bool(re.match(r"^(?:[-*]|\u2022|\d+[.)])\s+", line)) or ":" in line

    def _should_join_with_previous(self, previous: str, current: str) -> bool:
        if previous.endswith((":", ";")):
            return True
        if current[:1].islower():
            return True
        if len(previous) < 80 and not previous.endswith((".", "!", "?")):
            return True
        return False

    def _detect_section_title(self, text: str) -> Optional[str]:
        for raw_line in re.split(r"[\r\n]+", text):
            line = raw_line.strip()
            if line and self._looks_like_heading(line):
                return line
        return None

    def _load_chunk_payloads(self, product_id: str) -> List[Dict[str, Any]]:
        chunks_path = self._product_dir(product_id) / "chunks.json"
        if not chunks_path.exists():
            return []
        return json.loads(chunks_path.read_text(encoding="utf-8"))

    def _lexical_scores(
        self,
        query: str,
        chunks: List[Dict[str, Any]],
    ) -> List[Dict[str, float]]:
        query_terms = self._tokenize_search_text(query)
        if not query_terms:
            return [{"index": index, "score": 0.0} for index, _ in enumerate(chunks)]

        doc_term_counts: List[Counter[str]] = []
        doc_lengths: List[int] = []
        document_frequency: Counter[str] = Counter()

        for chunk in chunks:
            counts = Counter(self._tokenize_search_text(str(chunk.get("text", ""))))
            doc_term_counts.append(counts)
            doc_lengths.append(sum(counts.values()))
            for term in counts:
                document_frequency[term] += 1

        avg_doc_length = (sum(doc_lengths) / len(doc_lengths)) if doc_lengths else 1.0
        total_docs = max(len(chunks), 1)
        scores: List[Dict[str, float]] = []

        for index, term_counts in enumerate(doc_term_counts):
            doc_length = max(doc_lengths[index], 1)
            score = 0.0
            for term in query_terms:
                tf = term_counts.get(term, 0)
                if tf <= 0:
                    continue
                df = document_frequency.get(term, 0)
                idf = np.log(1 + ((total_docs - df + 0.5) / (df + 0.5)))
                denominator = tf + 1.2 * (1 - 0.75 + 0.75 * (doc_length / avg_doc_length))
                score += idf * ((tf * 2.2) / max(denominator, 1e-9))
            scores.append({"index": index, "score": float(score)})

        return scores

    def _tokenize_search_text(self, text: str) -> List[str]:
        return [token for token in re.findall(r"[a-z0-9]+", text.lower()) if len(token) > 1]

    def _resolve_model_device(self) -> str:
        configured = settings.MODEL_DEVICE.strip().lower()
        if configured and configured != "auto":
            return configured
        if torch.cuda.is_available():
            preferred_index = self._pick_best_cuda_device()
            return f"cuda:{preferred_index}"
        return "cpu"

    def _configure_torch_runtime(self) -> None:
        if settings.ENABLE_TF32:
            try:
                torch.set_float32_matmul_precision("high")
            except Exception:
                logger.debug("float32 matmul precision setting unavailable", exc_info=True)

        if torch.cuda.is_available():
            try:
                torch.backends.cuda.matmul.allow_tf32 = settings.ENABLE_TF32
                torch.backends.cudnn.allow_tf32 = settings.ENABLE_TF32
                torch.backends.cudnn.benchmark = True
            except Exception:
                logger.debug("CUDA backend optimization settings unavailable", exc_info=True)

    def _pick_best_cuda_device(self) -> int:
        preferred_index = max(settings.MODEL_DEVICE_INDEX, 0)
        device_count = torch.cuda.device_count()
        if device_count <= 0:
            return 0
        if preferred_index < device_count:
            return preferred_index

        best_index = 0
        best_free_memory = -1
        for device_index in range(device_count):
            try:
                free_memory, _ = torch.cuda.mem_get_info(device_index)
            except Exception:
                free_memory = 0
            if free_memory > best_free_memory:
                best_index = device_index
                best_free_memory = free_memory
        return best_index

    def _device_index_from_name(self, device_name: str) -> int:
        if ":" not in device_name:
            return 0
        try:
            return int(device_name.split(":", 1)[1])
        except ValueError:
            return 0

    def _product_dir(self, product_id: str) -> Path:
        safe_product_id = "".join(char for char in product_id if char.isalnum() or char in {"-", "_"})
        if not safe_product_id:
            raise ValueError("Invalid product_id")
        return self.vector_store_dir / safe_product_id
