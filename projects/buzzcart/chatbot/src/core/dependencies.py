from fastapi import Request

from ..rag.chat_engine import ChatEngine
from ..rag.document_processor import DocumentProcessor


async def get_chat_engine(request: Request) -> ChatEngine:
    return request.app.state.chat_engine


async def get_document_processor(request: Request) -> DocumentProcessor:
    return request.app.state.document_processor
