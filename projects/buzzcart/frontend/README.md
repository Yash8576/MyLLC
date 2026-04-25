# BuzzCart Frontend

Flutter frontend for BuzzCart.

## Local development

Install dependencies:

```bash
flutter pub get
```

Run locally against a local backend:

```bash
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:8080/api \
  --dart-define=WS_BASE_URL=ws://localhost:8080/ws \
  --dart-define=CHATBOT_ENABLED=false
```

If no `dart-define` overrides are provided, the app still falls back to local-friendly defaults.

## Production build

Use [dart_defines.example](./dart_defines.example) as the source of truth for build-time values.

Example:

```bash
flutter build web --release \
  --base-href /nexacore/BuzzCart/ \
  --dart-define=API_BASE_URL=https://api.your-domain.com/api \
  --dart-define=WS_BASE_URL=wss://api.your-domain.com/ws \
  --dart-define=CHATBOT_ENABLED=false \
  --dart-define=PRODUCTION=true
```

The built web output is published into the shared Cloudflare Pages site under `/nexacore/BuzzCart/`.
