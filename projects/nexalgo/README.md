# NexAlgo

NexAlgo is being rebuilt as a separate product stack inside this repo.

## Architecture

- Web app: existing Next.js site route at `/projects/nexalgo`
- Auth: Firebase Auth from a new Firebase project
- Backend: dedicated Cloud Run service in [backend](/abs/path/c:/Users/dravi/Downloads/Developer/MyLLC/projects/nexalgo/backend)
- Database: Cloud SQL PostgreSQL via Prisma
- Extension: Chrome MV3 scaffold in [extension](/abs/path/c:/Users/dravi/Downloads/Developer/MyLLC/projects/nexalgo/extension)

## Required frontend env vars

```bash
NEXT_PUBLIC_FIREBASE_API_KEY=
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=
NEXT_PUBLIC_FIREBASE_PROJECT_ID=
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=
NEXT_PUBLIC_FIREBASE_APP_ID=
NEXT_PUBLIC_NEXALGO_API_BASE_URL=https://nexalgo-backend-140224951663.us-east4.run.app/v1
```

For production on `https://nexacoreglobal.org`, set `NEXT_PUBLIC_NEXALGO_API_BASE_URL`
to the deployed Cloud Run service URL with `/v1`, for example:

```bash
NEXT_PUBLIC_NEXALGO_API_BASE_URL=https://nexalgo-backend-140224951663.us-east4.run.app/v1
```

## Required backend env vars

See [backend/.env.example](/abs/path/c:/Users/dravi/Downloads/Developer/MyLLC/projects/nexalgo/backend/.env.example).

## Cloud Run + Cloud SQL notes

- Deploy the backend as a dedicated Cloud Run service.
- Use the Cloud SQL connector instead of public-IP database access.
- Point `DATABASE_URL` at the Cloud SQL Postgres database created for NexAlgo.
- Keep Firebase Admin credentials and the OpenAI key in Cloud Run secrets or env vars.
- Use `projects/nexalgo/backend/cloudrun.env.example` as the production env template.
- Local deploy helper:

```powershell
.\scripts\deploy-nexalgo-cloud-run.ps1 `
  -ProjectId nexalgo-ace83 `
  -Region us-east4 `
  -ServiceName nexalgo-backend `
  -CloudSqlInstance "PROJECT:REGION:INSTANCE" `
  -EnvFile "projects\nexalgo\backend\cloudrun.env.yaml"
```

## Chrome extension packaging

Build a Chrome Web Store zip after the backend is deployed:

```powershell
.\scripts\package-nexalgo-extension.ps1 `
  -ApiBaseUrl "https://nexalgo-backend-140224951663.us-east4.run.app/v1" `
  -WebBaseUrl "https://nexacoreglobal.org/projects/nexalgo"
```

The zip is written to `projects/nexalgo/extension/dist/nexalgo-extension.zip`.

Publish an existing Chrome Web Store item with the official Chrome Web Store API:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\scripts\publish-nexalgo-extension.ps1 -Publish
```

The publish script reads Chrome Web Store secrets from
`projects/nexalgo/extension/.env.webstore.local`.

For first-time publication, create the item and complete the listing/privacy fields in the
Chrome Web Store Developer Dashboard before calling the publish API.

## Local verification

1. Run the backend service after creating the database and Prisma client.
2. Run the Next.js site and open `/projects/nexalgo`.
3. Sign in with Firebase Auth.
4. Confirm the problem list loads from the backend.
5. Submit a draft and confirm it appears in the review queue for editor/admin users.
