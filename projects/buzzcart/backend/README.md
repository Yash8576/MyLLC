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

## Redis on Cloud Run

Redis caching is already active in the backend whenever `REDIS_URL` is set successfully at startup.

For Cloud Run, use Google Cloud Memorystore for Redis and set:

```env
REDIS_URL=redis://YOUR_MEMORYSTORE_PRIVATE_IP:6379/0
```

Cloud Run also needs private network access to reach Memorystore, so deploy with a VPC connector:

```powershell
.\scripts\deploy-cloud-run.ps1 `
  -EnvFile ..\cloudrun.env `
  -VpcConnector projects/YOUR_GCP_PROJECT_ID/locations/us-east4/connectors/YOUR_VPC_CONNECTOR
```

Notes:

- Use the Memorystore private IP address, not a public hostname.
- Keep `--vpc-egress private-ranges-only` unless you intentionally want broader egress.
- If `REDIS_URL` is blank, the backend runs normally with caching disabled.
