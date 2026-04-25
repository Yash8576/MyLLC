# BuzzCart Backend

Go/Gin backend for BuzzCart.

## Runtime stack

- Go API on Cloud Run or local Docker
- PostgreSQL database
- Firebase Storage / Google Cloud Storage for media and documents
- Redis optional
- WebSocket endpoint for messaging

## Important files

- [cmd/server/main.go](./cmd/server/main.go)
- [internal/config/config.go](./internal/config/config.go)
- [internal/middleware/middleware.go](./internal/middleware/middleware.go)
- [QUICKSTART.md](./QUICKSTART.md)
- [.env.example](./.env.example)
- [cloudrun.env.example](./cloudrun.env.example)
- [cloudrun.service.yaml.example](./cloudrun.service.yaml.example)
- [scripts/deploy-cloud-run.ps1](./scripts/deploy-cloud-run.ps1)

## Current deployment direction

- Production backend target: Cloud Run
- Production database target: Cloud SQL PostgreSQL
- Production media/documents target: Firebase Storage
- Chatbot and Ollama are intentionally not required in production

## Local startup

```bash
go run ./cmd/server
```

For the full deployment path from `MyLLC`, use [../CLOUD_RUN_FIREBASE_DEPLOYMENT.md](../CLOUD_RUN_FIREBASE_DEPLOYMENT.md).

## Cloud Run deployment

For a repo-local deployment flow on Windows PowerShell:

```powershell
Copy-Item .\cloudrun.env.example .\cloudrun.env
.\scripts\deploy-cloud-run.ps1 -EnvFile ..\cloudrun.env
```

You can also use [cloudrun.service.yaml.example](./cloudrun.service.yaml.example) as a checked-in starting point if you prefer deploying from a built container image instead of `gcloud run deploy --source`.
