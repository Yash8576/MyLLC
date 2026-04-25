import logging

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile

from .schemas import (
    DocumentSyncRequest,
    DocumentSyncResponse,
    HealthResponse,
    ProductChatRequest,
    ProductChatResponse,
    ProductDocumentStatusResponse,
)
from ..core.dependencies import get_chat_engine, get_document_processor
from ..rag.chat_engine import ChatEngine
from ..rag.document_processor import DocumentProcessor

logger = logging.getLogger(__name__)

health_router = APIRouter()
chat_router = APIRouter()
documents_router = APIRouter()


@health_router.get("/health", response_model=HealthResponse)
async def health_check() -> HealthResponse:
    return HealthResponse(
        status="healthy",
        service="chatbot",
        version="2.0.0",
    )


@chat_router.post("/message", response_model=ProductChatResponse)
async def send_message(
    request: ProductChatRequest,
    chat_engine: ChatEngine = Depends(get_chat_engine),
) -> ProductChatResponse:
    try:
        return await chat_engine.generate_response(
            product_id=request.product_id,
            query=request.query,
            product_name=request.product_name,
            document_url=request.document_url,
            force_document_sync=request.force_document_sync,
            user_id=request.user_id,
        )
    except Exception as exc:
        logger.error("Error generating chat response: %s", exc)
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@documents_router.post("/sync", response_model=DocumentSyncResponse)
async def sync_document(
    request: DocumentSyncRequest,
    doc_processor: DocumentProcessor = Depends(get_document_processor),
) -> DocumentSyncResponse:
    try:
        return await doc_processor.sync_product_document(
            product_id=request.product_id,
            document_url=request.document_url,
            filename=request.filename,
            force=request.force,
        )
    except Exception as exc:
        logger.error("Error syncing product document: %s", exc)
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@documents_router.post("/upload", response_model=DocumentSyncResponse)
async def upload_document(
    product_id: str = Form(...),
    force: bool = Form(True),
    file: UploadFile = File(...),
    doc_processor: DocumentProcessor = Depends(get_document_processor),
) -> DocumentSyncResponse:
    try:
        return await doc_processor.process_upload(
            product_id=product_id,
            file=file,
            force=force,
        )
    except Exception as exc:
        logger.error("Error uploading product document: %s", exc)
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@documents_router.get("/{product_id}", response_model=ProductDocumentStatusResponse)
async def get_document_status(
    product_id: str,
    doc_processor: DocumentProcessor = Depends(get_document_processor),
) -> ProductDocumentStatusResponse:
    try:
        status = await doc_processor.get_status(product_id)
        return ProductDocumentStatusResponse(**status)
    except Exception as exc:
        logger.error("Error loading product document status: %s", exc)
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@documents_router.delete("/{product_id}")
async def delete_document(
    product_id: str,
    doc_processor: DocumentProcessor = Depends(get_document_processor),
):
    try:
        await doc_processor.delete_document(product_id)
        return {"message": "Product document deleted successfully"}
    except Exception as exc:
        logger.error("Error deleting product document: %s", exc)
        raise HTTPException(status_code=500, detail=str(exc)) from exc
