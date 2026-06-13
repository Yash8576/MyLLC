# Workflow Routing

This repository is a monorepo. Keep CI and deploy checks scoped to the
deployable surface they validate so unrelated projects do not show unrelated
checks on pushes or pull requests.

## Routing Matrix

| Workflow | Triggered by |
| --- | --- |
| `Root Site Cloudflare Build` | Root Next.js site files, shared public assets, root package/build config, Cloudflare build scripts |
| `BuzzCart Backend Deploy` | `projects/buzzcart/backend/**` or its workflow file |
| `BuzzCart Frontend Build` | `projects/buzzcart/frontend/**` or its workflow file |
| `NexAlgo Backend Deploy` | `projects/nexalgo/backend/**` or its workflow file |
| `Nanolink Backend Deploy` | `projects/nanolink/backend/**` or its workflow file |
| `Nanolink Frontend Build` | `projects/nanolink/frontend/**` or its workflow file |

## Rules

- Do not add project frontend/backend paths to a shared workflow unless that
  workflow actually deploys that project.
- Keep each Cloud Run workflow tied to exactly one GCP project and one service.
- If a shared script changes, trigger only the workflow that owns that script's
  deployed output.
- Workflow-file edits should trigger only the workflow being edited.
