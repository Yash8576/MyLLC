import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .routes import chat_router, documents_router, health_router
from ..core.config import settings
from ..rag.chat_engine import ChatEngine
from ..rag.document_processor import DocumentProcessor
from ..rag.vector_store import VectorStoreManager

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Initializing strict product RAG chatbot service...")
    vector_store = VectorStoreManager()
    await vector_store.initialize()
    document_processor = DocumentProcessor(vector_store)
    chat_engine = ChatEngine(vector_store, document_processor)

    app.state.vector_store = vector_store
    app.state.document_processor = document_processor
    app.state.chat_engine = chat_engine
    logger.info("Chatbot service initialized successfully")

    yield

    logger.info("Shutting down RAG chatbot service...")


app = FastAPI(
    title="Like2Share Product RAG Chatbot API",
    description="Strict product-document RAG service for Like2Share ecommerce",
    version="2.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health_router, prefix="/api/v1")
app.include_router(chat_router, prefix="/api/v1/chat", tags=["chat"])
app.include_router(documents_router, prefix="/api/v1/documents", tags=["documents"])


@app.get("/")
async def root():
    return {
        "service": "Like2Share Product RAG Chatbot",
        "version": "2.0.0",
        "status": "running",
    }
