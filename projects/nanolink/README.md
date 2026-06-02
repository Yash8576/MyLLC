Nanolink

URL shortener project with an Express/Postgres backend and a Next/Firebase frontend.

Backend setup:

1. Copy `backend/.env.example` to `backend/.env`.
2. Fill in your GCP database values.
3. Run `backend/schema.sql` against the database.
4. Start the API from `backend` with `npm run dev`.

Frontend setup:

1. Copy `frontend/.env.example` to `frontend/.env.local`.
2. Fill in your Firebase web app config and API URL.
3. Start the frontend from `frontend` with `npm run dev`.
