# BuzzCart Deployment Pipeline

BuzzCart uses two separate deployment systems:

- Cloudflare Pages deploys the frontend when site changes are pushed.
- GitHub Actions deploys the backend to Cloud Run when backend changes are pushed to `main`.

## Workflow locations

- Frontend site build: Cloudflare Pages using the repo root build command `npm run build`
- Backend deploy workflow: `.github/workflows/buzzcart-backend-deploy.yml`
- BuzzCart validation workflow: `.github/workflows/buzzcart-validate.yml`

## Backend deploy trigger

The Cloud Run deploy workflow runs on:

- pushes to `main` that change `projects/buzzcart/backend/**`
- changes to `.github/workflows/buzzcart-backend-deploy.yml`
- manual `workflow_dispatch`

Frontend-only changes do not trigger the Cloud Run deploy workflow.

## Backend release flow

1. GitHub Actions checks out the repo.
2. The workflow runs `go test ./...` in `projects/buzzcart/backend`.
3. If tests pass, GitHub authenticates to GCP using Workload Identity Federation.
4. The workflow writes the Cloud Run runtime env file from GitHub Secrets and Vars.
5. The workflow deploys `projects/buzzcart/backend` to the `buzzcart-backend` Cloud Run service in `us-east4`.
6. The workflow fetches the service URL and calls `/health` to verify the live revision.

## Required GitHub configuration

Secrets:

- `GCP_WORKLOAD_IDENTITY_PROVIDER`
- `GCP_SERVICE_ACCOUNT_EMAIL`
- `BUZZCART_DATABASE_URL`
- `BUZZCART_JWT_SECRET`
- `BUZZCART_REDIS_URL`

Repository variables:

- `BUZZCART_ALLOWED_FRONTEND_ORIGINS`

## Rollback

If a bad backend release reaches production:

1. Open Cloud Run revisions for `buzzcart-backend`.
2. Route traffic back to the previous healthy revision.
3. Revert or fix the backend commit in GitHub.
4. Push the fix to `main` to trigger a clean redeploy.

## Notes

- Production env values are not committed to the repo.
- Database migrations are not part of the automatic Cloud Run deploy flow.
- `projects/buzzcart/backend/scripts/deploy-cloud-run.ps1` remains the manual fallback path for local operator-driven deploys.
