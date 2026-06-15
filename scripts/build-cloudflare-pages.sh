#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_DIR="${REPO_ROOT}/.tooling/flutter"
BUZZCART_HASH_FILE="${REPO_ROOT}/.tooling/buzzcart-tree-hash"
BUZZCART_SRC="${REPO_ROOT}/projects/buzzcart/frontend"
BUZZCART_PUBLIC="${REPO_ROOT}/public/nexacore/BuzzCart"

DEFAULT_BUZZCART_API_BASE_URL="https://buzzcart-backend-1038414138435.us-east4.run.app/api"
DEFAULT_BUZZCART_WS_BASE_URL="wss://buzzcart-backend-1038414138435.us-east4.run.app/ws"
DEFAULT_BUZZCART_STORAGE_BASE_URL="https://buzzcart-backend-1038414138435.us-east4.run.app/storage"
DEFAULT_NEXALGO_API_BASE_URL="https://nexalgo-backend-140224951663.us-east4.run.app/v1"
DEFAULT_NEXALGO_FIREBASE_API_KEY="AIzaSyChiOs7D_dHdXY4aadUfJyB-6f6XFXPPwo"
DEFAULT_NEXALGO_FIREBASE_AUTH_DOMAIN="nexalgo-ace83.firebaseapp.com"
DEFAULT_NEXALGO_FIREBASE_PROJECT_ID="nexalgo-ace83"
DEFAULT_NEXALGO_FIREBASE_STORAGE_BUCKET="nexalgo-ace83.firebasestorage.app"
DEFAULT_NEXALGO_FIREBASE_MESSAGING_SENDER_ID="140224951663"
DEFAULT_NEXALGO_FIREBASE_APP_ID="1:140224951663:web:5c5ba53ca43443ff36a49a"
DEFAULT_NANOLINK_API_BASE_URL="https://nanolink-backend-837491606409.us-east4.run.app"
DEFAULT_NANOLINK_FIREBASE_API_KEY="AIzaSyAN5o0-rdPPtfJfjn1zIMByw9qn1p25p8k"
DEFAULT_NANOLINK_FIREBASE_AUTH_DOMAIN="nanolink-c1bc5.firebaseapp.com"
DEFAULT_NANOLINK_FIREBASE_PROJECT_ID="nanolink-c1bc5"
DEFAULT_NANOLINK_FIREBASE_STORAGE_BUCKET="nanolink-c1bc5.firebasestorage.app"
DEFAULT_NANOLINK_FIREBASE_MESSAGING_SENDER_ID="623556334382"
DEFAULT_NANOLINK_FIREBASE_APP_ID="1:623556334382:web:995a5bb3a7404b3ebbe0bf"

# ── BuzzCart change detection ────────────────────────────────────────────────
# git tree hash of projects/buzzcart/frontend at HEAD — changes only when
# files inside that directory actually change.
CURRENT_BUZZCART_HASH="$(git -C "${REPO_ROOT}" rev-parse HEAD:projects/buzzcart/frontend 2>/dev/null || echo "unknown")"
CACHED_BUZZCART_HASH="$(cat "${BUZZCART_HASH_FILE}" 2>/dev/null || echo "")"

BUZZCART_CHANGED=true
if [[ "${CURRENT_BUZZCART_HASH}" != "unknown" && \
      "${CURRENT_BUZZCART_HASH}" == "${CACHED_BUZZCART_HASH}" && \
      -d "${BUZZCART_PUBLIC}" ]]; then
  echo "BuzzCart source unchanged (tree ${CURRENT_BUZZCART_HASH:0:12}) — skipping Flutter build."
  BUZZCART_CHANGED=false
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
  echo "BuzzCart source changed — building Flutter web..."
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

  # Save hash so next deploy can skip if nothing changed
  mkdir -p "${REPO_ROOT}/.tooling"
  echo "${CURRENT_BUZZCART_HASH}" > "${BUZZCART_HASH_FILE}"
fi

# ── Next.js build (always) ───────────────────────────────────────────────────
pushd "${REPO_ROOT}" >/dev/null
next build
popd >/dev/null
