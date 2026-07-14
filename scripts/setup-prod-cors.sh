#!/usr/bin/env bash
# setup-prod-cors.sh — one-time setup to allow localhost in production CORS
#
# This lets your local frontend (localhost:3000 / localhost:3001) hit the
# production GCP backends with real data, without running anything locally.
#
# Run once, then just use: npm run dev
#
# Prerequisites: gcloud CLI installed and authenticated
#   gcloud auth login
#   gcloud config set project nexalgo-mig01   (or nanolink-mig01)

set -e

echo "==> Fetching production Cloud Run URLs..."

NEXALGO_URL=$(gcloud run services describe nexalgo-backend \
  --project nexalgo-mig01 \
  --region us-east4 \
  --format='value(status.url)' 2>/dev/null) || { echo "ERROR: Could not fetch nexalgo-backend URL. Is gcloud authenticated?"; exit 1; }

NANOLINK_URL=$(gcloud run services describe nanolink-backend \
  --project nanolink-mig01 \
  --region us-east4 \
  --format='value(status.url)' 2>/dev/null) || { echo "ERROR: Could not fetch nanolink-backend URL."; exit 1; }

echo "    NexAlgo:  $NEXALGO_URL"
echo "    NanoLink: $NANOLINK_URL"

# ── Update CORS on production services ──────────────────────
echo ""
echo "==> Updating CORS on NexAlgo backend (adds http://localhost:3000)..."
gcloud run services update nexalgo-backend \
  --project nexalgo-mig01 \
  --region us-east4 \
  --update-env-vars "^;^CORS_ORIGIN=https://nexacoreglobal.org,http://localhost:3000"

echo "==> Updating CORS on NanoLink backend (adds http://localhost:3000,http://localhost:3001)..."
gcloud run services update nanolink-backend \
  --project nanolink-mig01 \
  --region us-east4 \
  --update-env-vars "^;^CORS_ORIGIN=https://nexacoreglobal.org/projects/nanolink,http://localhost:3000,http://localhost:3001"

# ── Patch .env.local files with real URLs ───────────────────
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo ""
echo "==> Writing production URLs into .env.local files..."

# Root site
sed -i '' \
  "s|^NEXT_PUBLIC_NEXALGO_API_BASE_URL=.*|NEXT_PUBLIC_NEXALGO_API_BASE_URL=${NEXALGO_URL}/v1|" \
  "$REPO_ROOT/.env.local"

# NanoLink frontend
sed -i '' \
  "s|^NEXT_PUBLIC_NANOLINK_API_BASE_URL=.*|NEXT_PUBLIC_NANOLINK_API_BASE_URL=${NANOLINK_URL}|" \
  "$REPO_ROOT/projects/nanolink/frontend/.env.local"

echo ""
echo "Done! You can now run:"
echo "  npm run dev                               # root site (NexAlgo + Todo)"
echo "  cd projects/nanolink/frontend && npm run dev  # NanoLink"
echo ""
echo "Both will hit production backends with real data."
echo "No backend or Docker needed for frontend-only changes."
