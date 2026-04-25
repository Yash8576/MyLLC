#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_DIR="${REPO_ROOT}/.tooling/flutter"

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

install_flutter_if_missing

if [[ -d "${FLUTTER_DIR}" ]]; then
  export PATH="${FLUTTER_DIR}/bin:${PATH}"
fi

flutter config --enable-web

pushd "${REPO_ROOT}/projects/buzzcart/frontend" >/dev/null
flutter pub get
flutter build web --release \
  --base-href /nexacore/BuzzCart/ \
  --dart-define=API_BASE_URL="${BUZZCART_API_BASE_URL}" \
  --dart-define=WS_BASE_URL="${BUZZCART_WS_BASE_URL}" \
  --dart-define=STORAGE_BASE_URL="${BUZZCART_STORAGE_BASE_URL:-}" \
  --dart-define=CHATBOT_ENABLED=false \
  --dart-define=PRODUCTION=true
popd >/dev/null

pushd "${REPO_ROOT}" >/dev/null
node ./scripts/sync-buzzcart-build.mjs
next build
popd >/dev/null
