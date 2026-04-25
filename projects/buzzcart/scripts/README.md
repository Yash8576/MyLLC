# BuzzCart Local Scripts

These scripts help run BuzzCart locally from `projects/buzzcart`.

## Default local stack

The default scripts start:

- Redis
- backend
- frontend

They do not start chatbot or Ollama by default.

## Windows scripts

### `start-all-services.bat`

Starts the default local stack.

### `rebuild-and-start.bat`

Rebuilds Docker images and starts the default local stack.

### `stop-all-services.bat`

Stops the local Docker stack.

## Unix script

### `start-all-services.sh`

Unix equivalent of the Windows startup script.

## Default service URLs

| Service | URL/Port |
|---|---|
| Redis | `localhost:6379` |
| Backend | `localhost:8080` |
| Frontend | `localhost:8081` |

## Chatbot profile

Chatbot and Ollama stay opt-in only:

```bash
docker compose -f docker/docker-compose.yml --profile chatbot up -d chatbot ollama ollama-init
```

## Database options

- Run backend directly against local Postgres
- Run Cloud SQL Auth Proxy separately with `scripts/firebase/start-cloud-sql-proxy.ps1`
- If backend runs in Docker while the database proxy runs on the host, use `host.docker.internal` in `backend/.env`

## Common commands

```bash
docker compose -f docker/docker-compose.yml logs -f
docker compose -f docker/docker-compose.yml logs -f backend
docker compose -f docker/docker-compose.yml restart backend
docker compose -f docker/docker-compose.yml down
```
