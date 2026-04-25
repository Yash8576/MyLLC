# BuzzCart Backend Quick Start

## Prerequisites

- Go 1.21+
- PostgreSQL
- Firebase Storage / GCS bucket access
- Redis optional

## Environment setup

Start from [`.env.example`](./.env.example).

Key variables:

```env
DATABASE_URL=postgres://buzzcart_app:password@localhost:5432/buzzcart-daeb6-database?sslmode=disable
JWT_SECRET=replace-with-a-long-random-secret
PORT=8080
ALLOWED_FRONTEND_ORIGINS=http://localhost:3000,http://localhost:5000,http://localhost:8080,http://localhost:8081
REDIS_URL=
FIREBASE_PROJECT_ID=buzzcart-daeb6
FIREBASE_STORAGE_BUCKET=gs://buzzcart-daeb6.firebasestorage.app
FIREBASE_STORAGE_LOCATION=us-east1
GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/service-account.json
```

Notes:

- Set `REDIS_URL=` to disable Redis.
- On Cloud Run, prefer the attached service account and do not set `GOOGLE_APPLICATION_CREDENTIALS`.

## Run locally

```bash
go run ./cmd/server
```

If you are running the backend inside Docker and your database proxy is on the host machine, use `host.docker.internal` in `DATABASE_URL` instead of `127.0.0.1`.

## Health check

```bash
curl http://localhost:8080/health
```

Expected behavior:

- `database` must be `ok`
- `storage` must be `ok`
- `cache` may be `ok`, `degraded`, or `disabled`

## Production notes

- Backend is designed for Cloud Run.
- Cloud SQL is the recommended PostgreSQL target.
- Firebase Storage is the recommended media/document store.
- Chatbot and Ollama are intentionally not required in production.

See [../CLOUD_RUN_FIREBASE_DEPLOYMENT.md](../CLOUD_RUN_FIREBASE_DEPLOYMENT.md) for the full deploy flow.
