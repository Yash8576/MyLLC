# BuzzCart Storage Notes

BuzzCart stores uploaded images, videos, avatars, and product PDFs in Firebase Storage / Google Cloud Storage.

## Current project values

```env
FIREBASE_PROJECT_ID=buzzcart-daeb6
FIREBASE_STORAGE_BUCKET=gs://buzzcart-daeb6.firebasestorage.app
FIREBASE_STORAGE_LOCATION=us-east1
FIREBASE_STORAGE_PUBLIC_BASE_URL=https://firebasestorage.googleapis.com/v0/b
```

## Local development

Use a service account JSON file locally and point one of these env vars at it:

```env
GOOGLE_APPLICATION_CREDENTIALS=C:\absolute\path\to\service-account.json
FIREBASE_STORAGE_CREDENTIALS_FILE=C:\absolute\path\to\service-account.json
```

## Cloud Run production

- Do not mount a local credentials file.
- Use the Cloud Run service account.
- Grant that runtime identity access to the Firebase/GCS bucket.

## Notes

- Product specification PDFs remain enabled.
- Product assistant/chatbot indexing is intentionally disabled.
- Full deployment steps are in [../../CLOUD_RUN_FIREBASE_DEPLOYMENT.md](../../CLOUD_RUN_FIREBASE_DEPLOYMENT.md).
