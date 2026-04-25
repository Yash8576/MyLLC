from __future__ import annotations

import logging
import re
from datetime import datetime
from io import BytesIO
from pathlib import Path
from typing import Any, Dict, List, Optional
from urllib.parse import urlparse, urlunparse

import requests
from fastapi import UploadFile
from pypdf import PdfReader

from ..api.schemas import DocumentSyncResponse
from ..core.config import settings
from .vector_store import VectorStoreManager

logger = logging.getLogger(__name__)


class DocumentProcessor:
    """Processes seller PDFs into product-scoped FAISS indexes."""

    def __init__(self, vector_store: VectorStoreManager) -> None:
        self.vector_store = vector_store
        self.documents_path = Path(settings.DOCUMENTS_PATH)
        self.documents_path.mkdir(parents=True, exist_ok=True)

    async def sync_product_document(
        self,
        product_id: str,
        document_url: str,
        filename: Optional[str] = None,
        force: bool = False,
    ) -> DocumentSyncResponse:
        if not force and not self.vector_store.should_reindex(product_id, document_url):
            status = self.vector_store.get_product_status(product_id)
            return DocumentSyncResponse(
                product_id=product_id,
                indexed=True,
                chunks_created=status["chunks_created"],
                pages_processed=status["pages_processed"],
                source_name=status["source_name"],
                document_url=status["document_url"],
                status="already_indexed",
                message="Existing product document index is up to date.",
                updated_at=self._parse_timestamp(status["updated_at"]),
            )

        resolved_url = self._resolve_document_url(document_url)
        response = requests.get(resolved_url, timeout=90)
        response.raise_for_status()
        payload = response.content

        source_name = filename or self._derive_filename(document_url) or f"{product_id}.pdf"
        return self._index_pdf_bytes(
            product_id=product_id,
            payload=payload,
            source_name=source_name,
            document_url=document_url,
        )

    async def process_upload(
        self,
        product_id: str,
        file: UploadFile,
        force: bool = True,
    ) -> DocumentSyncResponse:
        file_ext = Path(file.filename or "").suffix.lower()
        if file_ext not in settings.ALLOWED_EXTENSIONS:
            raise ValueError(
                f"File type {file_ext or '<unknown>'} not allowed. "
                f"Allowed types: {settings.ALLOWED_EXTENSIONS}"
            )

        if not force and not self.vector_store.should_reindex(product_id, None):
            status = self.vector_store.get_product_status(product_id)
            return DocumentSyncResponse(
                product_id=product_id,
                indexed=True,
                chunks_created=status["chunks_created"],
                pages_processed=status["pages_processed"],
                source_name=status["source_name"],
                document_url=status["document_url"],
                status="already_indexed",
                message="Existing product document index is up to date.",
                updated_at=self._parse_timestamp(status["updated_at"]),
            )

        payload = await file.read()
        return self._index_pdf_bytes(
            product_id=product_id,
            payload=payload,
            source_name=file.filename or f"{product_id}.pdf",
            document_url=None,
        )

    async def get_status(self, product_id: str) -> Dict[str, Any]:
        return self.vector_store.get_product_status(product_id)

    async def ensure_index_current(
        self,
        product_id: str,
        document_url: Optional[str] = None,
    ) -> None:
        if not self.vector_store.should_reindex(product_id, document_url):
            return

        manifest = self.vector_store.get_product_manifest(product_id)
        if document_url:
            await self.sync_product_document(
                product_id=product_id,
                document_url=document_url,
                filename=manifest.get("source_name"),
                force=True,
            )
            return

        saved_path_value = manifest.get("saved_path")
        if not saved_path_value:
            return

        saved_path = Path(saved_path_value)
        if not saved_path.exists():
            return

        payload = saved_path.read_bytes()
        self._index_pdf_bytes(
            product_id=product_id,
            payload=payload,
            source_name=manifest.get("source_name") or saved_path.name,
            document_url=manifest.get("document_url"),
        )

    async def delete_document(self, product_id: str) -> None:
        product_dir = self.documents_path / self._safe_product_id(product_id)
        if product_dir.exists():
            for path in product_dir.iterdir():
                path.unlink(missing_ok=True)
            product_dir.rmdir()
        self.vector_store.delete_product_index(product_id)

    def _index_pdf_bytes(
        self,
        product_id: str,
        payload: bytes,
        source_name: str,
        document_url: Optional[str],
    ) -> DocumentSyncResponse:
        if not payload:
            raise ValueError("The uploaded PDF is empty")

        pages = self._extract_pages(payload)
        chunks = self._chunk_pages(product_id, pages)
        if not chunks:
            raise ValueError("No indexable text was found in the PDF")

        saved_path = self._save_pdf(product_id, source_name, payload)
        self.vector_store.build_product_index(
            product_id=product_id,
            chunks=chunks,
            manifest={
                "pages_processed": len(pages),
                "source_name": source_name,
                "document_url": document_url,
                "saved_path": str(saved_path),
            },
        )

        return DocumentSyncResponse(
            product_id=product_id,
            indexed=True,
            chunks_created=len(chunks),
            pages_processed=len(pages),
            source_name=source_name,
            document_url=document_url,
            status="indexed",
            message="Product document indexed successfully.",
            updated_at=datetime.utcnow(),
        )

    def _extract_pages(self, payload: bytes) -> List[Dict[str, Any]]:
        reader = PdfReader(BytesIO(payload))
        pages: List[Dict[str, Any]] = []

        for page_index, page in enumerate(reader.pages, start=1):
            raw_text = self._extract_page_text(page)
            text = self._normalize_text(raw_text)
            if text:
                pages.append({"page": page_index, "text": text})

        return pages

    def _chunk_pages(
        self,
        product_id: str,
        pages: List[Dict[str, Any]],
    ) -> List[Dict[str, Any]]:
        chunks: List[Dict[str, Any]] = []
        chunk_id = 0

        for page in pages:
            page_chunks = self.vector_store.chunk_text_by_tokens(page["text"])
            for page_chunk_index, page_chunk in enumerate(page_chunks):
                chunks.append(
                    {
                        "text": page_chunk,
                        "metadata": {
                            "product_id": product_id,
                            "page": page["page"],
                            "chunk_id": chunk_id,
                            "page_chunk_index": page_chunk_index,
                            "section_title": self._guess_section_title(page_chunk),
                            "token_count": self.vector_store.count_tokens(page_chunk),
                        },
                    }
                )
                chunk_id += 1

        return chunks

    def _save_pdf(self, product_id: str, source_name: str, payload: bytes) -> Path:
        product_dir = self.documents_path / self._safe_product_id(product_id)
        product_dir.mkdir(parents=True, exist_ok=True)

        file_name = Path(source_name).name or f"{product_id}.pdf"
        if not file_name.lower().endswith(".pdf"):
            file_name = f"{file_name}.pdf"

        for existing in product_dir.iterdir():
            existing.unlink(missing_ok=True)

        target_path = product_dir / file_name
        target_path.write_bytes(payload)
        return target_path

    def _resolve_document_url(self, document_url: str) -> str:
        parsed = urlparse(document_url.strip())
        if not parsed.scheme or not parsed.netloc:
            raise ValueError("document_url must be an absolute URL")

        rewrite_hosts = {host.strip().lower() for host in settings.DOCUMENT_URL_REWRITE_FROM}
        hostname = (parsed.hostname or "").lower()
        if hostname and hostname in rewrite_hosts and settings.DOCUMENT_URL_REWRITE_TO:
            rewritten = parsed._replace(netloc=settings.DOCUMENT_URL_REWRITE_TO)
            return urlunparse(rewritten)

        return document_url

    def _derive_filename(self, document_url: str) -> Optional[str]:
        path = urlparse(document_url).path
        if not path:
            return None
        filename = Path(path).name.strip()
        return filename or None

    def _safe_product_id(self, product_id: str) -> str:
        safe_value = "".join(
            char for char in product_id if char.isalnum() or char in {"-", "_"}
        )
        if not safe_value:
            raise ValueError("Invalid product_id")
        return safe_value

    def _extract_page_text(self, page: Any) -> str:
        try:
            layout_text = page.extract_text(extraction_mode="layout") or ""
            if layout_text.strip():
                return layout_text
        except TypeError:
            logger.debug("Layout extraction mode is unavailable; falling back to default")
        except Exception as exc:
            logger.warning("Layout extraction failed, falling back to default: %s", exc)

        return page.extract_text() or ""

    def _normalize_text(self, text: str) -> str:
        cleaned = text.replace("\x00", " ")
        cleaned = re.sub(r"(\w)-\s*[\r\n]+\s*(\w)", r"\1\2", cleaned)
        normalized_lines: List[str] = []

        for raw_line in re.split(r"[\r\n]+", cleaned):
            line = raw_line.strip()
            if not line:
                continue

            # Many PDF extracts collapse section headers into adjacent words.
            line = re.sub(r"(?<=[a-z])(?=[A-Z])", " ", line)
            line = re.sub(r"(?<=[A-Z])(?=[A-Z][a-z])", " ", line)
            line = re.sub(r"\s+", " ", line)
            line = line.strip(" |")
            if line:
                normalized_lines.append(line)

        return "\n".join(normalized_lines)

    def _guess_section_title(self, text: str) -> Optional[str]:
        for raw_line in re.split(r"[\r\n]+", text):
            line = raw_line.strip()
            if not line:
                continue
            if len(line) > 90 or len(line.split()) > 12:
                continue
            if line.endswith((".", "?", "!")):
                continue
            capitalized_words = sum(1 for word in line.split() if word[:1].isupper())
            if capitalized_words >= max(1, len(line.split()) - 1):
                return line
        return None

    def _parse_timestamp(self, value: Optional[str]) -> datetime:
        if not value:
            return datetime.utcnow()
        try:
            return datetime.fromisoformat(value)
        except ValueError:
            logger.warning("Failed to parse timestamp %s", value)
            return datetime.utcnow()
