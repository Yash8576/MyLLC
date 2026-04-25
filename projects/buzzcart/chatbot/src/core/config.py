from typing import List

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    API_HOST: str = "0.0.0.0"
    API_PORT: int = 8001
    DEBUG: bool = False

    DATABASE_URL: str = "postgresql://like2share_user:like2share_dev_password@postgres:5432/like2share_db"
    CHAT_HISTORY_TABLE: str = "chat_messages"

    EMBEDDING_MODEL_NAME: str = "BAAI/bge-m3"
    RERANKER_MODEL_NAME: str = "BAAI/bge-reranker-v2-m3"
    MODEL_DEVICE: str = "auto"
    MODEL_DEVICE_INDEX: int = 0
    ENABLE_TF32: bool = True
    EMBEDDING_BATCH_SIZE: int = 32
    RERANK_BATCH_SIZE: int = 24
    OLLAMA_BASE_URL: str = "http://ollama:11434"
    OLLAMA_MODEL: str = "mistral"
    OLLAMA_TIMEOUT_SECONDS: int = 60

    VECTOR_STORE_DIR: str = "/app/data/vector_store"
    DOCUMENTS_PATH: str = "/app/data/documents"
    MODEL_CACHE_DIR: str = "/app/models/cache"
    ALLOWED_EXTENSIONS: List[str] = [".pdf"]

    CHUNK_SIZE_TOKENS: int = 400
    CHUNK_OVERLAP_TOKENS: int = 80
    TOP_K_RESULTS: int = 10
    RETRIEVAL_CANDIDATE_POOL: int = 24
    LEXICAL_SEARCH_LIMIT: int = 24
    RERANK_TOP_K: int = 3
    SENTENCE_TOP_K: int = 8
    NEIGHBOR_WINDOW: int = 1
    MAX_EVIDENCE_BLOCKS: int = 3
    DIRECT_SEARCH_TOP_K: int = 14
    DIRECT_MATCH_MIN_SCORE: float = 0.58

    DOCUMENT_URL_REWRITE_FROM: List[str] = Field(
        default_factory=lambda: ["localhost", "127.0.0.1", "10.0.2.2"]
    )
    DOCUMENT_URL_REWRITE_TO: str = "minio:9000"

    CORS_ORIGINS: List[str] = Field(default_factory=lambda: ["*"])

    @field_validator(
        "ALLOWED_EXTENSIONS",
        "DOCUMENT_URL_REWRITE_FROM",
        "CORS_ORIGINS",
        mode="before",
    )
    @classmethod
    def parse_csv_list(cls, value):
        if isinstance(value, str):
            stripped = value.strip()
            if not stripped:
                return []
            if stripped.startswith("["):
                return value
            return [item.strip() for item in stripped.split(",") if item.strip()]
        return value

    model_config = SettingsConfigDict(
        env_file=".env",
        case_sensitive=True,
        extra="ignore",
    )


settings = Settings()
