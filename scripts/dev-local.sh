#!/usr/bin/env bash
# dev-local.sh — starts the full local dev environment with production data
#
# What this starts:
#   Cloud SQL Proxy  — tunnels all 3 production DBs to localhost
#     localhost:5433 → nexalgo    DB
#     localhost:5434 → nanolink   DB
#     localhost:5435 → buzzcart   DB
#   localhost:3000  — Next.js frontend (NexAlgo + Todo + root site)
#   localhost:8080  — NexAlgo backend  (Express + Prisma → prod DB)
#   localhost:8082  — NanoLink backend (Express → prod DB)
#
# BuzzCart backend (Go) is NOT started here — run it separately:
#   cd projects/buzzcart/backend && go run ./cmd/server
#   (or: docker compose -f projects/buzzcart/docker/docker-compose.yml up)
#
# Prerequisites (run once):
#   gcloud auth application-default login
#
# Usage:
#   bash scripts/dev-local.sh

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROXY="$REPO_ROOT/scripts/cloud-sql-proxy"

# ── Check ADC ────────────────────────────────────────────────
if ! gcloud auth application-default print-access-token &>/dev/null; then
  echo "ERROR: Application Default Credentials not found."
  echo "Run: gcloud auth application-default login"
  exit 1
fi

# ── Download proxy if missing ────────────────────────────────
if [[ ! -x "$PROXY" ]]; then
  echo "==> Downloading Cloud SQL Auth Proxy..."
  curl -sL -o "$PROXY" \
    "https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.14.1/cloud-sql-proxy.darwin.arm64"
  chmod +x "$PROXY"
fi

# ── Install backend dependencies ─────────────────────────────
echo "==> Installing backend dependencies..."
(cd "$REPO_ROOT/projects/nexalgo/backend" && npm install --silent)
(cd "$REPO_ROOT/projects/nanolink/backend" && npm install --silent)

trap 'echo ""; echo "Stopping all services..."; kill 0' EXIT INT TERM

# ── Cloud SQL Proxy ──────────────────────────────────────────
echo "==> Starting Cloud SQL Auth Proxy..."
"$PROXY" --port=5433 "nexalgo-mig01:us-east4:nexalgo-mig01-instance"   &
"$PROXY" --port=5434 "nanolink-mig01:us-east4:nanolink-mig01-instance" &
"$PROXY" --port=5435 "buzzcart-mig01:us-east4:buzzcart-mig01-instance"  &

echo "    Waiting for proxies to be ready..."
sleep 3

# ── NexAlgo Prisma migrate ───────────────────────────────────
echo "==> Checking NexAlgo DB schema..."
(cd "$REPO_ROOT/projects/nexalgo/backend" && npx prisma migrate deploy 2>/dev/null || true)

# ── Start services ───────────────────────────────────────────
echo ""
echo "==> Starting services (Ctrl+C to stop all)"
echo "    Frontend:         http://localhost:3000"
echo "    NexAlgo backend:  http://localhost:8080"
echo "    NanoLink backend: http://localhost:8082"
echo ""

(cd "$REPO_ROOT/projects/nexalgo/backend" && npm run dev) &
(cd "$REPO_ROOT/projects/nanolink/backend" && npm run dev) &
(cd "$REPO_ROOT" && npm run dev) &

wait
