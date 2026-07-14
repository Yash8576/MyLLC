#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_DIR="${REPO_ROOT}/.tooling/flutter"
BUZZCART_SRC="${REPO_ROOT}/projects/buzzcart/frontend"
BUZZCART_PUBLIC="${REPO_ROOT}/public/nexacore/BuzzCart"
# This file is committed alongside the BuzzCart build output — no external cache needed.
BUZZCART_SRC_HASH_FILE="${BUZZCART_PUBLIC}/.buzzcart-src-hash"

DEFAULT_BUZZCART_API_BASE_URL="https://buzzcart-backend-1063811069935.us-east4.run.app/api"
DEFAULT_BUZZCART_WS_BASE_URL="wss://buzzcart-backend-1063811069935.us-east4.run.app/ws"
DEFAULT_BUZZCART_STORAGE_BASE_URL="https://buzzcart-backend-1063811069935.us-east4.run.app/storage"
DEFAULT_NEXALGO_API_BASE_URL="https://nexalgo-backend-335068424622.us-east4.run.app/v1"
DEFAULT_NEXALGO_FIREBASE_API_KEY="AIzaSyAUX-zIMiYyjHBEik2tXkP91jbxbH-4ojU"
DEFAULT_NEXALGO_FIREBASE_AUTH_DOMAIN="nexalgo-mig01.firebaseapp.com"
DEFAULT_NEXALGO_FIREBASE_PROJECT_ID="nexalgo-mig01"
DEFAULT_NEXALGO_FIREBASE_STORAGE_BUCKET="nexalgo-mig01.firebasestorage.app"
DEFAULT_NEXALGO_FIREBASE_MESSAGING_SENDER_ID="335068424622"
DEFAULT_NEXALGO_FIREBASE_APP_ID="1:335068424622:web:5a847f185fe6a532bd003f"
DEFAULT_NANOLINK_API_BASE_URL="https://nanolink-backend-641342211371.us-east4.run.app"
DEFAULT_NANOLINK_FIREBASE_API_KEY="AIzaSyCVAZICdH2u38DE1nTNa2jp_0dvpVa-bME"
DEFAULT_NANOLINK_FIREBASE_AUTH_DOMAIN="nanolink-mig01.firebaseapp.com"
DEFAULT_NANOLINK_FIREBASE_PROJECT_ID="nanolink-mig01"
DEFAULT_NANOLINK_FIREBASE_STORAGE_BUCKET="nanolink-mig01.firebasestorage.app"
DEFAULT_NANOLINK_FIREBASE_MESSAGING_SENDER_ID="641342211371"
DEFAULT_NANOLINK_FIREBASE_APP_ID="1:641342211371:web:12315b2c84e70673c7716e"

# ── BuzzCart change detection ────────────────────────────────────────────────
# Git tree hash of projects/buzzcart/frontend at HEAD. We compare it against
# .buzzcart-src-hash which is committed inside public/nexacore/BuzzCart — so
# it travels with the repo and survives a fresh clone. No external cache file.
CURRENT_BUZZCART_HASH="$(git -C "${REPO_ROOT}" rev-parse HEAD:projects/buzzcart/frontend 2>/dev/null || echo "unknown")"
COMMITTED_BUZZCART_HASH="$(cat "${BUZZCART_SRC_HASH_FILE}" 2>/dev/null || echo "")"

BUZZCART_CHANGED=true
if [[ "${CURRENT_BUZZCART_HASH}" != "unknown" && \
      "${CURRENT_BUZZCART_HASH}" == "${COMMITTED_BUZZCART_HASH}" ]]; then
  echo "BuzzCart source unchanged (${CURRENT_BUZZCART_HASH:0:12}) — skipping Flutter build."
  BUZZCART_CHANGED=false
else
  echo "BuzzCart source changed (src=${CURRENT_BUZZCART_HASH:0:12} cached=${COMMITTED_BUZZCART_HASH:0:12}) — building Flutter web..."
fi

# ── Flutter (only needed when BuzzCart changed) ──────────────────────────────
install_flutter_if_missing() {
  if command -v flutter >/dev/null 2>&1; then
    return
  fi

  mkdir -p "${REPO_ROOT}/.tooling"
  if [ ! -d "${FLUTTER_DIR}" ]; then
    git clone https://github.com/flutter/flutter.git --branch stable --depth 1 "${FLUTTER_DIR}"
  fi

  export PATH="${FLUTTER_DIR}/bin:${PATH}"
}

if [[ "${BUZZCART_CHANGED}" == "true" ]]; then
  install_flutter_if_missing

  if [[ -d "${FLUTTER_DIR}" ]]; then
    export PATH="${FLUTTER_DIR}/bin:${PATH}"
  fi

  # Only write config when web isn't already enabled
  if ! flutter config 2>/dev/null | grep -q 'enable-web: true'; then
    flutter config --enable-web
  fi
fi

# ── Env vars ─────────────────────────────────────────────────────────────────
BUZZCART_API_BASE_URL="${BUZZCART_API_BASE_URL:-${DEFAULT_BUZZCART_API_BASE_URL}}"
BUZZCART_WS_BASE_URL="${BUZZCART_WS_BASE_URL:-${DEFAULT_BUZZCART_WS_BASE_URL}}"
BUZZCART_STORAGE_BASE_URL="${BUZZCART_STORAGE_BASE_URL:-${DEFAULT_BUZZCART_STORAGE_BASE_URL}}"
export NEXT_PUBLIC_NEXALGO_API_BASE_URL="${NEXT_PUBLIC_NEXALGO_API_BASE_URL:-${DEFAULT_NEXALGO_API_BASE_URL}}"
export NEXT_PUBLIC_FIREBASE_API_KEY="${NEXT_PUBLIC_FIREBASE_API_KEY:-${DEFAULT_NEXALGO_FIREBASE_API_KEY}}"
export NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN="${NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN:-${DEFAULT_NEXALGO_FIREBASE_AUTH_DOMAIN}}"
export NEXT_PUBLIC_FIREBASE_PROJECT_ID="${NEXT_PUBLIC_FIREBASE_PROJECT_ID:-${DEFAULT_NEXALGO_FIREBASE_PROJECT_ID}}"
export NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET="${NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET:-${DEFAULT_NEXALGO_FIREBASE_STORAGE_BUCKET}}"
export NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID="${NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID:-${DEFAULT_NEXALGO_FIREBASE_MESSAGING_SENDER_ID}}"
export NEXT_PUBLIC_FIREBASE_APP_ID="${NEXT_PUBLIC_FIREBASE_APP_ID:-${DEFAULT_NEXALGO_FIREBASE_APP_ID}}"
export NEXT_PUBLIC_NANOLINK_API_BASE_URL="${NEXT_PUBLIC_NANOLINK_API_BASE_URL:-${DEFAULT_NANOLINK_API_BASE_URL}}"
export NEXT_PUBLIC_NANOLINK_FIREBASE_API_KEY="${NEXT_PUBLIC_NANOLINK_FIREBASE_API_KEY:-${DEFAULT_NANOLINK_FIREBASE_API_KEY}}"
export NEXT_PUBLIC_NANOLINK_FIREBASE_AUTH_DOMAIN="${NEXT_PUBLIC_NANOLINK_FIREBASE_AUTH_DOMAIN:-${DEFAULT_NANOLINK_FIREBASE_AUTH_DOMAIN}}"
export NEXT_PUBLIC_NANOLINK_FIREBASE_PROJECT_ID="${NEXT_PUBLIC_NANOLINK_FIREBASE_PROJECT_ID:-${DEFAULT_NANOLINK_FIREBASE_PROJECT_ID}}"
export NEXT_PUBLIC_NANOLINK_FIREBASE_STORAGE_BUCKET="${NEXT_PUBLIC_NANOLINK_FIREBASE_STORAGE_BUCKET:-${DEFAULT_NANOLINK_FIREBASE_STORAGE_BUCKET}}"
export NEXT_PUBLIC_NANOLINK_FIREBASE_MESSAGING_SENDER_ID="${NEXT_PUBLIC_NANOLINK_FIREBASE_MESSAGING_SENDER_ID:-${DEFAULT_NANOLINK_FIREBASE_MESSAGING_SENDER_ID}}"
export NEXT_PUBLIC_NANOLINK_FIREBASE_APP_ID="${NEXT_PUBLIC_NANOLINK_FIREBASE_APP_ID:-${DEFAULT_NANOLINK_FIREBASE_APP_ID}}"

# ── BuzzCart Flutter build (skipped when unchanged) ──────────────────────────
if [[ "${BUZZCART_CHANGED}" == "true" ]]; then
  pushd "${BUZZCART_SRC}" >/dev/null
  flutter pub get
  flutter build web --release \
    --base-href /nexacore/BuzzCart/ \
    --dart-define=API_BASE_URL="${BUZZCART_API_BASE_URL}" \
    --dart-define=WS_BASE_URL="${BUZZCART_WS_BASE_URL}" \
    --dart-define=STORAGE_BASE_URL="${BUZZCART_STORAGE_BASE_URL}" \
    --dart-define=CHATBOT_ENABLED=false \
    --dart-define=PRODUCTION=true
  popd >/dev/null

  pushd "${REPO_ROOT}" >/dev/null
  node ./scripts/sync-buzzcart-build.mjs
  popd >/dev/null

  # Write the source hash into the committed output directory so the next
  # deploy (fresh clone) can compare without any external cache.
  echo "${CURRENT_BUZZCART_HASH}" > "${BUZZCART_SRC_HASH_FILE}"
  echo "Wrote BuzzCart src hash ${CURRENT_BUZZCART_HASH:0:12} to ${BUZZCART_SRC_HASH_FILE}"
fi

# ── Next.js build (always) ───────────────────────────────────────────────────
pushd "${REPO_ROOT}" >/dev/null
next build
popd >/dev/null
