# Projects

Standalone applications integrated into the `MyLLC` repo live here.

## Current Projects

### BuzzCart

- Path: [projects/buzzcart](/abs/path/c:/Users/dravi/Downloads/Developer/MyLLC/projects/buzzcart)
- Frontend: Flutter web, published under `/nexacore/BuzzCart/` on the Cloudflare Pages site
- Backend: Go, deployed to Cloud Run
- Data: PostgreSQL on Cloud SQL
- Storage: Firebase Storage / GCS
- Cache: Redis optional
- Production exclusions: chatbot and Ollama remain disabled

Primary docs:

- [BuzzCart README](/abs/path/c:/Users/dravi/Downloads/Developer/MyLLC/projects/buzzcart/README.md)
- [Cloud Run + Firebase deployment](/abs/path/c:/Users/dravi/Downloads/Developer/MyLLC/projects/buzzcart/CLOUD_RUN_FIREBASE_DEPLOYMENT.md)
- [Cloud SQL migration runbook](/abs/path/c:/Users/dravi/Downloads/Developer/MyLLC/projects/buzzcart/FIREBASE_CLOUDSQL_MIGRATION_RUNBOOK.md)

### NexAlgo

- Path: [projects/nexalgo](/abs/path/c:/Users/dravi/Downloads/Developer/MyLLC/projects/nexalgo)
- Web app: Next.js route under `/projects/nexalgo`
- Backend: dedicated Cloud Run service scaffolded in TypeScript + Prisma
- Data: PostgreSQL on Cloud SQL
- Auth: Firebase Auth from a new Firebase project
- Extension: Chrome MV3 scaffold for LeetCode and GeeksforGeeks lookups

Primary docs:

- [NexAlgo README](/abs/path/c:/Users/dravi/Downloads/Developer/MyLLC/projects/nexalgo/README.md)
