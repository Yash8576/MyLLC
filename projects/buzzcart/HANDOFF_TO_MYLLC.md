# BuzzCart Handoff For MyLLC Repo

BuzzCart now lives in `MyLLC/projects/buzzcart` as a standalone project.

## What is already done here

- Flutter web config is build-time driven with `--dart-define`
- Product chatbot UI is disabled and now shows `Coming soon`
- Product create/edit keeps PDF upload but skips chatbot indexing
- Backend runs without chatbot or Ollama
- Backend runs without Redis if `REDIS_URL` is blank
- CORS is environment-driven through `ALLOWED_FRONTEND_ORIGINS`
- Cloud Run + Cloud SQL + Firebase Storage deployment docs are included

## Files the other agent should read first

- [README.md](./README.md)
- [CLOUD_RUN_FIREBASE_DEPLOYMENT.md](./CLOUD_RUN_FIREBASE_DEPLOYMENT.md)
- [FIREBASE_CLOUDSQL_MIGRATION_RUNBOOK.md](./FIREBASE_CLOUDSQL_MIGRATION_RUNBOOK.md)
- [backend/.env.example](./backend/.env.example)
- [frontend/dart_defines.example](./frontend/dart_defines.example)

## Current known project values

- GCP / Firebase project: `buzzcart-daeb6`
- Cloud SQL region: `us-east4`
- Cloud SQL instance: `buzzcart-daeb6-instance`
- Cloud SQL database: `buzzcart-daeb6-database`
- Firebase Storage bucket: `gs://buzzcart-daeb6.firebasestorage.app`
- Firebase Storage location: `us-east1`
- Backend port: `8080`

## Secrets

Sensitive values were not copied into the public markdown docs on purpose.

- Local working secrets live in `backend/.env`
- Local root dev secrets live in `.env`
- Docker local mounts point at local service-account JSON files on disk

If you want a private handoff bundle, use `PRIVATE_VALUES.local.md` locally when copying this directory into the MyLLC repo.

## Integrated repo notes

1. The tracked project folder is `projects/buzzcart`.
2. Machine-specific service-account paths were removed from tracked Docker config and docs.
3. Use `backend/.env.example`, `backend/cloudrun.env.example`, and `frontend/dart_defines.example` as templates.
4. Use the repo GitHub Actions workflows for Cloud Run and Firebase Hosting deployment.
5. Keep `chatbot` and `ollama` out of production deployment.
