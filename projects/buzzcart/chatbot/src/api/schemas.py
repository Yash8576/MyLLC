from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, Field


class ProductChatRequest(BaseModel):
    product_id: str = Field(..., description="Product identifier for strict filtering")
    query: str = Field(..., description="User question about the product document")
    product_name: Optional[str] = Field(
        default=None,
        description="Optional product title used to render natural answers",
    )
    user_id: Optional[str] = Field(default=None, description="Optional user identifier")
    document_url: Optional[str] = Field(
        default=None,
        description="Optional PDF URL used for lazy indexing or refresh",
    )
    force_document_sync: bool = Field(
        default=False,
        description="Rebuild the product index before answering",
    )


class AnswerSource(BaseModel):
    page: int
    chunk_id: int


class ProductChatResponse(BaseModel):
    answer: str
    source: Optional[AnswerSource] = None
    confidence: Literal["high", "medium", "low"]


class DocumentSyncRequest(BaseModel):
    product_id: str
    document_url: str
    filename: Optional[str] = None
    force: bool = False


class DocumentSyncResponse(BaseModel):
    product_id: str
    indexed: bool
    chunks_created: int
    pages_processed: int
    source_name: Optional[str] = None
    document_url: Optional[str] = None
    status: str
    message: str
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class ProductDocumentStatusResponse(BaseModel):
    product_id: str
    indexed: bool
    chunks_created: int = 0
    pages_processed: int = 0
    source_name: Optional[str] = None
    document_url: Optional[str] = None
    updated_at: Optional[datetime] = None


class HealthResponse(BaseModel):
    status: str
    service: str
    version: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)
