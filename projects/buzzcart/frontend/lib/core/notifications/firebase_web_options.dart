import 'package:firebase_core/firebase_core.dart';

/// Firebase Web SDK config for project "buzzcart-mig01". `projectId`,
/// `storageBucket`, and `messagingSenderId` are shared across every platform
/// app in the project and are already correct below (pulled from the
/// Android/iOS config files).
///
/// `apiKey` and `appId` are unique to the Web app registration and are still
/// placeholders — get them from Firebase console → Project settings →
/// General → "Your apps" → the Web app → SDK setup and configuration →
/// Config, and paste them in below. Until then, web push registration is
/// skipped (isWebFirebaseConfigured is false) — the in-app banners still
/// work fully on web regardless.
const String _webApiKey = 'REPLACE_WITH_WEB_API_KEY';
const String _webAppId = 'REPLACE_WITH_WEB_APP_ID';

const FirebaseOptions firebaseWebOptions = FirebaseOptions(
  apiKey: _webApiKey,
  appId: _webAppId,
  messagingSenderId: '1063811069935',
  projectId: 'buzzcart-mig01',
  authDomain: 'buzzcart-mig01.firebaseapp.com',
  storageBucket: 'buzzcart-mig01.firebasestorage.app',
);

bool get isWebFirebaseConfigured =>
    _webApiKey != 'REPLACE_WITH_WEB_API_KEY' &&
    _webAppId != 'REPLACE_WITH_WEB_APP_ID';

/// Web Push certificate public key (VAPID), from Firebase console →
/// Cloud Messaging → Web configuration → Web Push certificates.
const String webPushVapidKey =
    'BLmS3f24i8B-5xj_YLGX1rArcM04Yg6G5lRiKTettZlV4oEGi-eKoUjbHpIvjL6kl8ELuEz77dqxSNN2b6JetKg';
