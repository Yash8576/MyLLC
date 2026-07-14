#!/usr/bin/env bash
# cloud-sql-proxy.sh — starts Cloud SQL Auth Proxy for all 3 production instances
#
# Ports:
#   5433 — NexAlgo    (nexalgo-mig01:us-east4:nexalgo-mig01-instance)
#   5434 — NanoLink   (nanolink-mig01:us-east4:nanolink-mig01-instance)
#   5435 — BuzzCart   (buzzcart-mig01:us-east4:buzzcart-mig01-instance)
#
# Prerequisites (one-time):
#   gcloud auth application-default login
#
# Usage:
#   bash scripts/cloud-sql-proxy.sh          # runs in foreground, Ctrl+C to stop
#   bash scripts/cloud-sql-proxy.sh &        # runs in background

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROXY="$REPO_ROOT/scripts/cloud-sql-proxy"

if [[ ! -x "$PROXY" ]]; then
  echo "Cloud SQL Proxy not found. Downloading..."
  curl -sL -o "$PROXY" \
    "https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.14.1/cloud-sql-proxy.darwin.arm64"
  chmod +x "$PROXY"
fi

# Check ADC is configured
if ! gcloud auth application-default print-access-token &>/dev/null; then
  echo "ERROR: Application Default Credentials not set up."
  echo "Run: gcloud auth application-default login"
  exit 1
fi

echo "==> Starting Cloud SQL Auth Proxy..."
echo "    5433 → nexalgo-mig01:us-east4:nexalgo-mig01-instance"
echo "    5434 → nanolink-mig01:us-east4:nanolink-mig01-instance"
echo "    5435 → buzzcart-mig01:us-east4:buzzcart-mig01-instance"
echo "    Ctrl+C to stop"
echo ""

trap 'kill 0' EXIT INT TERM

"$PROXY" \
  --port=5433 "nexalgo-mig01:us-east4:nexalgo-mig01-instance" &

"$PROXY" \
  --port=5434 "nanolink-mig01:us-east4:nanolink-mig01-instance" &

"$PROXY" \
  --port=5435 "buzzcart-mig01:us-east4:buzzcart-mig01-instance" &

wait
