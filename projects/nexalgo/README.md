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
NEXT_PUBLIC_NEXALGO_API_BASE_URL=http://localhost:8080/v1
```

## Required backend env vars

See [backend/.env.example](/abs/path/c:/Users/dravi/Downloads/Developer/MyLLC/projects/nexalgo/backend/.env.example).

## Cloud Run + Cloud SQL notes

- Deploy the backend as a dedicated Cloud Run service.
- Use the Cloud SQL connector instead of public-IP database access.
- Point `DATABASE_URL` at the Cloud SQL Postgres database created for NexAlgo.
- Keep Firebase Admin credentials and the OpenAI key in Cloud Run secrets or env vars.

## Local verification

1. Run the backend service after creating the database and Prisma client.
2. Run the Next.js site and open `/projects/nexalgo`.
3. Sign in with Firebase Auth.
4. Confirm the problem list loads from the backend.
5. Submit a draft and confirm it appears in the review queue for editor/admin users.
