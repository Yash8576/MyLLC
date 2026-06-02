from typing import List, Dict, Optional
import logging
from datetime import datetime
import json
import uuid

from sqlalchemy import Column, String, DateTime, JSON, Text, delete, select
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession

from ..core.config import settings

logger = logging.getLogger(__name__)

Base = declarative_base()

class ChatMessage(Base):
    """Chat message model for storing conversation history."""
    __tablename__ = settings.CHAT_HISTORY_TABLE
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    conversation_id = Column(String, nullable=False, index=True)
    user_id = Column(String, nullable=False, index=True)
    user_message = Column(Text, nullable=False)
    bot_response = Column(Text, nullable=False)
    timestamp = Column(DateTime, default=datetime.utcnow, nullable=False)
    metadata = Column(JSON, nullable=True)

class ChatHistoryManager:
    """Manages chat history in PostgreSQL."""
    
    def __init__(self):
        # Convert postgresql:// to postgresql+asyncpg://
        async_db_url = settings.DATABASE_URL.replace(
            "postgresql://", "postgresql+asyncpg://"
        )
        self.engine = create_async_engine(async_db_url, echo=settings.DEBUG)
        self.SessionLocal = sessionmaker(
            self.engine, class_=AsyncSession, expire_on_commit=False
        )
    
    async def init_db(self):
        """Initialize database tables."""
        async with self.engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        logger.info("Chat history tables initialized")
    
    async def save_message(
        self,
        conversation_id: str,
        user_id: str,
        user_message: str,
        bot_response: str,
        metadata: Optional[Dict] = None
    ):
        """Save a chat message to the database."""
        try:
            async with self.SessionLocal() as session:
                message = ChatMessage(
                    conversation_id=conversation_id,
                    user_id=user_id,
                    user_message=user_message,
                    bot_response=bot_response,
                    metadata=metadata
                )
                session.add(message)
                await session.commit()
                logger.info(f"Saved message for conversation {conversation_id}")
        except Exception as e:
            logger.error(f"Error saving message: {e}")
            raise
    
    async def get_conversation_history(
        self,
        conversation_id: str,
        limit: int = 50
    ) -> List[Dict]:
        """Get conversation history by conversation ID."""
        try:
            async with self.SessionLocal() as session:
                result = await session.scalars(
                    select(ChatMessage)
                    .where(ChatMessage.conversation_id == conversation_id)
                    .order_by(ChatMessage.timestamp.desc())
                    .limit(limit)
                )
                messages = result.all()
                
                return [
                    {
                        "id": message.id,
                        "conversation_id": message.conversation_id,
                        "user_id": message.user_id,
                        "user_message": message.user_message,
                        "bot_response": message.bot_response,
                        "timestamp": message.timestamp,
                        "metadata": message.metadata
                    }
                    for message in reversed(messages)
                ]
        except Exception as e:
            logger.error(f"Error getting conversation history: {e}")
            return []
    
    async def get_user_history(
        self,
        user_id: str,
        limit: int = 50
    ) -> List[Dict]:
        """Get all chat history for a user."""
        try:
            async with self.SessionLocal() as session:
                result = await session.scalars(
                    select(ChatMessage)
                    .where(ChatMessage.user_id == user_id)
                    .order_by(ChatMessage.timestamp.desc())
                    .limit(limit)
                )
                messages = result.all()
                
                return [
                    {
                        "id": message.id,
                        "conversation_id": message.conversation_id,
                        "user_id": message.user_id,
                        "user_message": message.user_message,
                        "bot_response": message.bot_response,
                        "timestamp": message.timestamp,
                        "metadata": message.metadata
                    }
                    for message in messages
                ]
        except Exception as e:
            logger.error(f"Error getting user history: {e}")
            return []
    
    async def delete_conversation(self, conversation_id: str):
        """Delete a conversation."""
        try:
            async with self.SessionLocal() as session:
                await session.execute(
                    delete(ChatMessage).where(
                        ChatMessage.conversation_id == conversation_id
                    )
                )
                await session.commit()
                logger.info(f"Deleted conversation {conversation_id}")
        except Exception as e:
            logger.error(f"Error deleting conversation: {e}")
            raise
