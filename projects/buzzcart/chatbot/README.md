# Like2Share RAG Chatbot

A Retrieval Augmented Generation (RAG) powered chatbot service for the Like2Share social media platform.

## Features

- **RAG-Powered Responses**: Uses vector similarity search to provide context-aware answers
- **Multiple Document Formats**: Supports PDF, TXT, MD, DOCX, and HTML documents
- **Conversation History**: Maintains chat history in PostgreSQL
- **Vector Database**: Uses ChromaDB for efficient similarity search
- **RESTful API**: FastAPI-based API for easy integration
- **Scalable Architecture**: Containerized and ready for production deployment

## Architecture

```
chatbot/
├── src/
│   ├── api/           # FastAPI routes and schemas
│   ├── rag/           # RAG components (vector store, chat engine, document processor)
│   ├── db/            # Database models and managers
│   └── core/          # Configuration and dependencies
├── data/
│   ├── documents/     # Uploaded documents
│   └── embeddings/    # Vector database storage
├── config/            # Configuration files
└── models/            # Local models (if using)
```

## Setup

### Prerequisites

- Python 3.11+
- PostgreSQL database
- OpenAI API key (or alternative LLM provider)
- Docker (optional, for containerized deployment)

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
```

Required variables:
- `OPENAI_API_KEY`: Your OpenAI API key
- `DATABASE_URL`: PostgreSQL connection string
- `BACKEND_API_URL`: Like2Share backend URL

### Installation

#### Local Development

```bash
# Install dependencies
pip install -r requirements.txt

# Initialize database
# (This will be done automatically on first run)

# Run the service
uvicorn src.api.main:app --reload --host 0.0.0.0 --port 8000
```

#### Docker Deployment

```bash
# Build image
docker build -t like2share-chatbot .

# Run container
docker run -p 8000:8000 --env-file .env like2share-chatbot
```

## API Endpoints

### Health Check
```
GET /api/v1/health
```

### Chat

**Send Message**
```
POST /api/v1/chat/message
{
  "message": "How do I create a post?",
  "user_id": "user123",
  "conversation_id": "conv456"
}
```

**Get Chat History**
```
GET /api/v1/chat/history/{user_id}?conversation_id=conv456&limit=50
```

**Clear Conversation**
```
DELETE /api/v1/chat/history/{conversation_id}
```

### Documents

**Upload Document**
```
POST /api/v1/documents/upload
Content-Type: multipart/form-data

file: <file>
user_id: user123
```

**List Documents**
```
GET /api/v1/documents/list
```

**Delete Document**
```
DELETE /api/v1/documents/{document_id}
```

## Usage

### Adding Knowledge Base Documents

Upload documents to populate the chatbot's knowledge base:

```bash
curl -X POST "http://localhost:8000/api/v1/documents/upload" \
  -F "file=@/path/to/document.pdf" \
  -F "user_id=admin"
```

### Chatting with the Bot

```bash
curl -X POST "http://localhost:8000/api/v1/chat/message" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "What features does Like2Share have?",
    "user_id": "user123"
  }'
```

## Integration with Like2Share

### Backend Integration

The chatbot can be integrated with the Like2Share backend to:
- Fetch user context and preferences
- Retrieve platform-specific information
- Log chat interactions

### Frontend Integration

Add the chatbot widget to your Flutter frontend:

```dart
// Example integration code
class ChatbotWidget extends StatefulWidget {
  // Widget implementation
}
```

## Configuration

### Vector Database Options

The chatbot supports multiple vector databases:
- **ChromaDB** (default): Local, persistent vector store
- **Pinecone**: Managed cloud vector database
- **Qdrant**: Open-source vector database

Change the vector database in `.env`:
```
VECTOR_DB_TYPE=chroma  # or pinecone, qdrant
```

### LLM Configuration

Configure the language model:
```
OPENAI_MODEL=gpt-4-turbo-preview
TEMPERATURE=0.7
MAX_TOKENS=500
```

### RAG Parameters

Tune RAG performance:
```
CHUNK_SIZE=1000
CHUNK_OVERLAP=200
TOP_K_RESULTS=5
```

## Development

### Adding Custom Document Loaders

Extend `DocumentProcessor` in `src/rag/document_processor.py`:

```python
async def _load_document(self, file_path: str, file_ext: str):
    if file_ext == ".custom":
        loader = CustomLoader(file_path)
        # ...
```

### Custom Prompt Templates

Modify the prompt in `src/rag/chat_engine.py`:

```python
self.prompt_template = """Your custom prompt here..."""
```

## Monitoring

The service includes:
- Health check endpoint
- Prometheus metrics (planned)
- Structured logging

## Troubleshooting

### Common Issues

**Vector store initialization fails**
- Check that `CHROMA_PERSIST_DIR` is writable
- Verify OpenAI API key is valid

**Database connection errors**
- Verify PostgreSQL is running
- Check `DATABASE_URL` format

**Out of memory errors**
- Reduce `CHUNK_SIZE` and `TOP_K_RESULTS`
- Use a smaller embedding model

## License

Part of the Like2Share project.
