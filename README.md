# MyLLC Repo

This repository now hosts the main Next.js company site plus standalone product projects that are operated from the same repo.

## Active Projects

- `src/` and `public/`: the main Next.js/Tailwind marketing site
- `projects/buzzcart/`: BuzzCart social commerce app
  - Flutter web frontend published under `/nexacore/BuzzCart/` on the same Cloudflare Pages site
  - Go backend deployed to Cloud Run
  - PostgreSQL on Cloud SQL
  - Firebase Hosting plus Firebase Storage for the web app and media
  - Redis optional
  - Chatbot and Ollama intentionally disabled for production

See [projects/README.md](/abs/path/c:/Users/dravi/Downloads/Developer/MyLLC/projects/README.md) for the project index.

## Main Site

Install dependencies and start the landing site:

```bash
npm install
npm run dev
```

Open `http://localhost:3000`.

## Repo Layout

- `src/app`: Next.js app routes, layouts, and components
- `projects/`: standalone product projects integrated into this repo
- `.github/workflows/`: repo CI and project-specific deployment workflows

## BuzzCart

BuzzCart lives at [projects/buzzcart](/abs/path/c:/Users/dravi/Downloads/Developer/MyLLC/projects/buzzcart). The repo includes:

- GitHub Actions for BuzzCart validation and Cloud Run backend deploys
- a Cloudflare Pages build path that publishes the Flutter frontend to `/nexacore/BuzzCart/`
- Cloud Run env template in `projects/buzzcart/backend/cloudrun.env.example`
- local Docker/dev scripts with chatbot kept opt-in only

Start with [projects/buzzcart/README.md](/abs/path/c:/Users/dravi/Downloads/Developer/MyLLC/projects/buzzcart/README.md) for setup and operations.
