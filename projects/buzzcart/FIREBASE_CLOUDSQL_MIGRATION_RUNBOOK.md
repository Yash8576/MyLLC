# Firebase + Cloud SQL Migration Runbook

This runbook migrates BuzzCart backend to Cloud SQL PostgreSQL and aligns storage with Firebase-backed production infrastructure.

## Confirmed target values

- Project ID: buzzcart-daeb6
- Project Number: 1038414138435
- Region: us-east4
- Cloud SQL instance: buzzcart-daeb6-instance
- DB name: buzzcart-daeb6-database
- Instance connection name: buzzcart-daeb6:us-east4:buzzcart-daeb6-instance
- Public IP: 34.86.72.243
- Port: 5432

## Chosen defaults

- App DB user: buzzcart_app
- Connection path: Cloud SQL Auth Proxy
- Downtime window: 15 minutes

## One-time prerequisites

1. Install Cloud SQL Auth Proxy and ensure `cloud-sql-proxy` is in `PATH`.
2. Install PostgreSQL client tools and ensure `psql` is in `PATH`.
3. Ensure your Google account has Cloud SQL Admin rights on project `buzzcart-daeb6`.

## Step 1: Start Cloud SQL proxy

Open a dedicated terminal and run:

```powershell
Set-Location projects/buzzcart
./scripts/firebase/start-cloud-sql-proxy.ps1
```

Keep this terminal running until migration and smoke tests are done.

## Step 2: Prepare role SQL passwords

Edit `scripts/firebase/setup_roles.sql` and replace:

- `REPLACE_APP_PASSWORD`

Use a strong random password.

## Step 3: Apply schema migrations and grants

From the repository root:

```powershell
Set-Location projects/buzzcart
./scripts/firebase/migrate-to-cloudsql.ps1 -AdminUser <cloudsql_admin_user>
```

This applies SQL files from `database/migrations` in order, then applies role grants.

## Step 4: Configure backend database env

Set backend `DATABASE_URL` to:

```env
DATABASE_URL=postgres://buzzcart_app:<APP_PASSWORD>@127.0.0.1:5432/buzzcart-daeb6-database?sslmode=disable
```

## Step 5: Configure production env

Recommended production additions:

```env
JWT_SECRET=replace-with-a-long-random-secret
PORT=8080
ALLOWED_FRONTEND_ORIGINS=https://your-frontend-domain.web.app,https://your-custom-domain.com
FIREBASE_PROJECT_ID=buzzcart-daeb6
FIREBASE_STORAGE_BUCKET=gs://buzzcart-daeb6.firebasestorage.app
FIREBASE_STORAGE_LOCATION=us-east1
REDIS_URL=
```

On Cloud Run, prefer the attached service account instead of `GOOGLE_APPLICATION_CREDENTIALS`.

## Step 6: Cutover checklist

1. Announce maintenance mode.
2. Stop write traffic to the old database.
3. Execute final data sync/import.
4. Restart backend with the new `DATABASE_URL`.
5. Run smoke tests.
6. Exit maintenance mode.

## Step 7: Smoke tests

Backend:

1. Login endpoint works.
2. Product list and product detail endpoints return data.
3. Cart add/update/remove works.
4. Create product review works.
5. Product image/video/PDF uploads succeed.

Database:

1. Row counts for key tables are expected.
2. New rows appear from backend writes.
3. Uploaded product media and PDFs still resolve correctly from Firebase Storage.

## Rollback plan

1. Keep the old database untouched during the initial verification period.
2. If failures appear, switch `DATABASE_URL` back to the old database.
3. Restart services and reopen traffic.

## Notes

- Chatbot and Ollama are intentionally disabled for the current production deployment.
- Local storage/media currently has zero files in this workspace, so Firebase Storage migration is not needed right now.
- If media becomes populated later, migrate media separately and update URL generation paths.
- Full deployment steps are in [CLOUD_RUN_FIREBASE_DEPLOYMENT.md](./CLOUD_RUN_FIREBASE_DEPLOYMENT.md).
