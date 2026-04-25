# BuzzCart Cloud Run + Cloudflare Pages Deployment Guide

This is the recommended production setup for BuzzCart in the `MyLLC` repo.

## Target architecture

- Flutter web frontend deployed under `/nexacore/BuzzCart/` on the same Cloudflare Pages site as `MyLLC`
- Go backend deployed to Cloud Run
- PostgreSQL on Cloud SQL
- Firebase Storage for images, videos, and product PDFs
- Redis optional
- Chatbot and Ollama disabled for now

In this repo, BuzzCart is located at `projects/buzzcart`.

The backend folder also includes:

- `backend/scripts/deploy-cloud-run.ps1` for a repo-local PowerShell deploy
- `backend/cloudrun.service.yaml.example` for service-based Cloud Run deployments from a built image

## 1. Required production configuration

### Backend env vars

```env
DATABASE_URL=postgres://buzzcart_app:PASSWORD@/buzzcart-daeb6-database?host=/cloudsql/buzzcart-daeb6:us-east4:buzzcart-daeb6-instance
JWT_SECRET=replace-with-a-long-random-secret
PORT=8080
REDIS_URL=
ALLOWED_FRONTEND_ORIGINS=https://your-frontend-domain.web.app,https://your-custom-domain.com
FIREBASE_PROJECT_ID=buzzcart-daeb6
FIREBASE_STORAGE_BUCKET=gs://buzzcart-daeb6.firebasestorage.app
FIREBASE_STORAGE_LOCATION=us-east1
FIREBASE_STORAGE_PUBLIC_BASE_URL=https://firebasestorage.googleapis.com/v0/b
```

Notes:

- Leave `REDIS_URL` blank to disable Redis.
- On Cloud Run, prefer the attached service account. You usually do not need `GOOGLE_APPLICATION_CREDENTIALS`.
- `GOOGLE_APPLICATION_CREDENTIALS` is mainly for local development or non-Google runtimes.
- `FIREBASE_STORAGE_CREDENTIALS_FILE` is optional and mainly useful for local development.

### Frontend build-time values

`frontend/` reads these from `--dart-define`:

```text
API_BASE_URL
WS_BASE_URL
STORAGE_BASE_URL
CHATBOT_ENABLED
CHATBOT_BASE_URL
PRODUCTION
```

Recommended production values:

```text
API_BASE_URL=https://api.your-domain.com/api
WS_BASE_URL=wss://api.your-domain.com/ws
STORAGE_BASE_URL=
CHATBOT_ENABLED=false
CHATBOT_BASE_URL=
PRODUCTION=true
```

`STORAGE_BASE_URL` can stay empty if your backend already returns Firebase Storage URLs directly.

## 2. Deploy Cloud SQL

Create or reuse a PostgreSQL Cloud SQL instance, then create:

- the application database
- an application DB user
- a strong password

Example connection name:

```text
buzzcart-daeb6:us-east4:buzzcart-daeb6-instance
```

## 3. Deploy backend to Cloud Run

Make sure the Cloud Run service account has:

- `Cloud SQL Client`
- storage access to your Firebase/GCS bucket, such as `Storage Object Admin` or a tighter custom role

Example deploy command:

```bash
gcloud run deploy buzzcart-backend \
  --source ./backend \
  --region us-east4 \
  --allow-unauthenticated \
  --add-cloudsql-instances buzzcart-daeb6:us-east4:buzzcart-daeb6-instance \
  --set-env-vars PORT=8080,JWT_SECRET=YOUR_SECRET,ALLOWED_FRONTEND_ORIGINS=https://YOUR_FRONTEND_DOMAIN \
  --set-env-vars FIREBASE_PROJECT_ID=buzzcart-daeb6,FIREBASE_STORAGE_BUCKET=gs://buzzcart-daeb6.firebasestorage.app,FIREBASE_STORAGE_LOCATION=us-east1 \
  --set-env-vars REDIS_URL= \
  --set-env-vars DATABASE_URL='postgres://buzzcart_app:DB_PASSWORD@/buzzcart-daeb6-database?host=/cloudsql/buzzcart-daeb6:us-east4:buzzcart-daeb6-instance'
```

After deployment:

- copy the Cloud Run URL
- confirm `https://YOUR_BACKEND_URL/health` returns healthy or degraded

From Windows PowerShell in `projects/buzzcart/backend`, you can also use the included script:

```powershell
Copy-Item .\cloudrun.env.example .\cloudrun.env
.\scripts\deploy-cloud-run.ps1 -EnvFile ..\cloudrun.env
```

## 4. Connect Firebase Storage

BuzzCart backend uploads media directly to the configured Firebase/GCS bucket.

Required backend env vars:

```env
FIREBASE_PROJECT_ID=buzzcart-daeb6
FIREBASE_STORAGE_BUCKET=gs://buzzcart-daeb6.firebasestorage.app
FIREBASE_STORAGE_LOCATION=us-east1
```

In production on Cloud Run:

- do not mount a local credentials file
- use the Cloud Run service account
- grant that service account bucket permissions

## 5. Build Flutter web for production

Example build command:

```bash
flutter build web \
  --base-href /nexacore/BuzzCart/ \
  --dart-define=API_BASE_URL=https://api.your-domain.com/api \
  --dart-define=WS_BASE_URL=wss://api.your-domain.com/ws \
  --dart-define=CHATBOT_ENABLED=false \
  --dart-define=PRODUCTION=true
```

If you need a backend-relative storage proxy in production:

```bash
flutter build web \
  --base-href /nexacore/BuzzCart/ \
  --dart-define=API_BASE_URL=https://api.your-domain.com/api \
  --dart-define=WS_BASE_URL=wss://api.your-domain.com/ws \
  --dart-define=STORAGE_BASE_URL=https://api.your-domain.com/storage \
  --dart-define=CHATBOT_ENABLED=false \
  --dart-define=PRODUCTION=true
```

## 6. Publish Flutter web into the Cloudflare Pages output

From the repo root, the Cloudflare Pages build should run:

```bash
npm run build:pages
```

That script:

1. builds the Flutter web frontend with `--base-href /nexacore/BuzzCart/`
2. copies the generated web files into `public/nexacore/BuzzCart`
3. runs the Next.js static export so Cloudflare Pages publishes both the LLC site and BuzzCart from the same output

Cloudflare Pages settings should use:

```text
Build command: npm run build:pages
Build output directory: out
```

Required Cloudflare Pages environment variables:

```text
BUZZCART_API_BASE_URL=https://api.your-domain.com/api
BUZZCART_WS_BASE_URL=wss://api.your-domain.com/ws
BUZZCART_STORAGE_BASE_URL=
```

The repository also includes `public/_redirects` with:

```text
/nexacore/BuzzCart/* /nexacore/BuzzCart/index.html 200
```

That keeps Flutter SPA deep links working on Cloudflare Pages.

## 7. Chatbot status

- Product chatbot UI is intentionally disabled for production.
- Clicking the product assistant action now shows `Coming soon`.
- Product create/edit flows still keep the specification PDF upload.
- No chatbot document sync, delete, or indexing calls are required.
- Ollama is not part of production deployment.

## 8. Redis status

- Redis is optional.
- If `REDIS_URL` is blank, the backend starts with caching disabled.
- If `REDIS_URL` is set but unavailable, the backend logs a warning and continues.

## 9. Recommended rollout order

1. Provision Cloud SQL and run schema migrations.
2. Configure Firebase Storage bucket and permissions.
3. Deploy backend to Cloud Run.
4. Verify `/health`, auth, product listing, uploads, and WebSocket messaging.
5. Configure the Cloudflare Pages build env vars for BuzzCart.
6. Run the shared Pages build so `/buzzcart/` is published with the LLC site.
7. Add the production frontend origin to `ALLOWED_FRONTEND_ORIGINS`.

## 10. Repo workflows

This repo includes:

- `.github/workflows/buzzcart-backend-deploy.yml` for Cloud Run backend deploys
- `.github/workflows/buzzcart-validate.yml` for project validation on BuzzCart changes
