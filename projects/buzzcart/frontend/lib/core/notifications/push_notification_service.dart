import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import 'firebase_web_options.dart';

/// Must be a top-level (or static) function: FCM invokes this in a separate
/// isolate when a data message arrives while the app is fully backgrounded
/// or terminated. The "notification" payload is shown by the OS
/// automatically — this handler exists only so the plugin has somewhere to
/// dispatch to; no extra work is needed today.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await _ensureFirebaseInitialized();
}

Future<void> _ensureFirebaseInitialized() async {
  if (Firebase.apps.isNotEmpty) {
    return;
  }
  if (kIsWeb) {
    if (!isWebFirebaseConfigured) {
      // Web app's apiKey/appId not filled in yet — see
      // firebase_web_options.dart. Stay uninitialized rather than throw.
      return;
    }
    await Firebase.initializeApp(options: firebaseWebOptions);
  } else {
    // Android/iOS pick up config from google-services.json /
    // GoogleService-Info.plist automatically — no explicit options needed.
    await Firebase.initializeApp();
  }
}

/// OS-level push notifications, delivered only while the app is backgrounded
/// or terminated (the backend checks app-foreground presence server-side
/// before sending). Foreground messages are handled entirely by the
/// in-app banner system — see InAppNotificationCenter.
///
/// iOS is intentionally excluded from token registration until the project
/// has a paid Apple Developer Program membership: FCM delivery to iOS
/// requires an APNs authentication key uploaded to Firebase and the Push
/// Notifications entitlement on the app, neither of which a free account can
/// provide. iOS still gets full in-app banner coverage in the meantime.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  GoRouter? _router;
  String? _registeredToken;
  StreamSubscription<String>? _tokenRefreshSubscription;
  bool _initialized = false;

  bool get _tokenSupportedOnThisPlatform {
    if (kIsWeb) {
      return true;
    }
    return defaultTargetPlatform == TargetPlatform.android;
  }

  /// Sets up tap-to-open handling and Firebase Core. Call once at startup,
  /// before login state is known. Safe to call even when push is disabled
  /// for this platform/build (Firebase init failures are swallowed).
  Future<void> initialize(GoRouter router) async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _router = router;

    try {
      await _ensureFirebaseInitialized();
    } catch (_) {
      // Firebase config missing or invalid for this platform — push stays
      // disabled, in-app banners remain the only notification channel.
      return;
    }
    if (Firebase.apps.isEmpty) {
      // e.g. web without apiKey/appId filled in yet — see
      // firebase_web_options.dart.
      return;
    }

    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }

    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    final initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    final conversationId = message.data['conversation_id'] as String?;
    final router = _router;
    if (conversationId == null || conversationId.isEmpty || router == null) {
      return;
    }
    router.push(
      '/messages',
      extra: MessagesRouteIntent(conversationId: conversationId),
    );
  }

  /// Requests permission and registers this device's FCM token with the
  /// backend. Call on login / app resume with an authenticated user.
  /// Best-effort: any failure just leaves push disabled for this session.
  Future<void> registerForUser(ApiService api) async {
    if (!_tokenSupportedOnThisPlatform || Firebase.apps.isEmpty) {
      return;
    }

    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      final token = kIsWeb
          ? await FirebaseMessaging.instance
              .getToken(vapidKey: webPushVapidKey)
          : await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        return;
      }

      _registeredToken = token;
      await api.registerPushToken(token: token, platform: _platformLabel);

      unawaited(_tokenRefreshSubscription?.cancel());
      _tokenRefreshSubscription =
          FirebaseMessaging.instance.onTokenRefresh.listen((refreshed) {
        _registeredToken = refreshed;
        unawaited(
          api.registerPushToken(token: refreshed, platform: _platformLabel),
        );
      });
    } catch (_) {
      // Push registration is best-effort; in-app banners remain primary.
    }
  }

  /// Unregisters this device (logout). Best-effort.
  Future<void> unregisterForUser(ApiService api) async {
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;

    final token = _registeredToken;
    _registeredToken = null;
    if (token == null) {
      return;
    }
    await api.unregisterPushToken(token);
  }

  String get _platformLabel {
    if (kIsWeb) {
      return 'web';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'other';
    }
  }
}
