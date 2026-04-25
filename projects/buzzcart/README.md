# BuzzCart

BuzzCart is integrated into the `MyLLC` repo as a standalone project at `projects/buzzcart`.

## Production architecture

- `frontend/`: Flutter web frontend published under `/nexacore/BuzzCart/` on the MyLLC Cloudflare Pages site
- `backend/`: Go API and WebSocket server deployed to Cloud Run
- Database: PostgreSQL on Cloud SQL
- Media and documents: Firebase Storage / Google Cloud Storage
- Redis: optional cache only
- Chatbot and Ollama: intentionally disabled for production

Cloud Run is the cleanest fit for the backend in this repo because BuzzCart already has a self-contained Go service, a Dockerfile, and Cloud SQL plus GCS dependencies that map directly onto Cloud Run without disturbing the existing Cloudflare Pages deployment for the website frontend.

## Repo integration

- Repo path: `projects/buzzcart`
- Cloudflare Pages build script: `scripts/build-cloudflare-pages.sh`
- BuzzCart asset sync script: `scripts/sync-buzzcart-build.mjs`
- SPA redirect rule: `public/_redirects`
- Cloud Run env template: `backend/cloudrun.env.example`
- GitHub Actions:
  - `.github/workflows/buzzcart-validate.yml`
  - `.github/workflows/buzzcart-backend-deploy.yml`

## Local development

- Frontend remains `dart-define` driven for production builds and still falls back to local backend URLs when overrides are not provided.
- Backend supports local Postgres and starts even if Redis is blank or unavailable.
- Optional local chatbot containers remain available behind the Docker Compose `chatbot` profile, but they are not part of the production path.

## Key docs

- [Cloud Run + Cloudflare Pages deployment guide](./CLOUD_RUN_FIREBASE_DEPLOYMENT.md)
- [Cloud SQL migration runbook](./FIREBASE_CLOUDSQL_MIGRATION_RUNBOOK.md)
- [Backend quick start](./backend/QUICKSTART.md)
- [Backend env example](./backend/.env.example)
- [Cloud Run env example](./backend/cloudrun.env.example)
- [Frontend guide](./frontend/README.md)
- [Frontend dart-define example](./frontend/dart_defines.example)
- [Local scripts](./scripts/README.md)
