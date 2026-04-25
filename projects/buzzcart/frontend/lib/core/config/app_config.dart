// Core application configuration
import 'app_config_platform.dart'
    if (dart.library.html) 'app_config_web.dart'
    if (dart.library.io) 'app_config_io.dart';

class AppConfig {
  static const String _port = '8080';
  static const String _apiBaseUrlOverride =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const String _wsBaseUrlOverride =
      String.fromEnvironment('WS_BASE_URL', defaultValue: '');
  static const String _storageBaseUrlOverride =
      String.fromEnvironment('STORAGE_BASE_URL', defaultValue: '');
  static const String _chatbotBaseUrlOverride =
      String.fromEnvironment('CHATBOT_BASE_URL', defaultValue: '');

  static String get _baseHost => PlatformConfig.baseHost;

  static String get _defaultApiOrigin => 'http://$_baseHost:$_port';

  static String get _defaultWebSocketOrigin => 'ws://$_baseHost:$_port';

  static String _normalizeBaseUrl(String value) {
    return value.trim().replaceFirst(RegExp(r'/+$'), '');
  }

  static String _originFromUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return '';
    }

    final hasExplicitPort = uri.hasPort &&
        !((uri.scheme == 'http' && uri.port == 80) ||
            (uri.scheme == 'https' && uri.port == 443) ||
            (uri.scheme == 'ws' && uri.port == 80) ||
            (uri.scheme == 'wss' && uri.port == 443));

    return hasExplicitPort
        ? '${uri.scheme}://${uri.host}:${uri.port}'
        : '${uri.scheme}://${uri.host}';
  }

  // API Configuration - Cross-platform compatible URLs
  static String get apiBaseUrl => _normalizeBaseUrl(
        _apiBaseUrlOverride.isNotEmpty
            ? _apiBaseUrlOverride
            : '$_defaultApiOrigin/api',
      );

  static String get wsBaseUrl {
    if (_wsBaseUrlOverride.isNotEmpty) {
      return _normalizeBaseUrl(_wsBaseUrlOverride);
    }

    final apiOrigin = _originFromUrl(apiBaseUrl);
    if (apiOrigin.startsWith('https://')) {
      return '${apiOrigin.replaceFirst('https://', 'wss://')}/ws';
    }
    if (apiOrigin.startsWith('http://')) {
      return '${apiOrigin.replaceFirst('http://', 'ws://')}/ws';
    }

    return '$_defaultWebSocketOrigin/ws';
  }

  // Storage Configuration
  static String get storageBaseUrl {
    if (_storageBaseUrlOverride.isNotEmpty) {
      return _normalizeBaseUrl(_storageBaseUrlOverride);
    }

    final apiOrigin = _originFromUrl(apiBaseUrl);
    if (apiOrigin.isNotEmpty) {
      return '$apiOrigin/storage';
    }

    return '$_defaultApiOrigin/storage';
  }

  static String get chatbotBaseUrl =>
      _normalizeBaseUrl(_chatbotBaseUrlOverride);

  static String get initialRouteOverride =>
      PlatformConfig.initialRouteOverride.trim();

  // App Configuration
  static const String appName = 'Buzz Social Cart';
  static const String appVersion = '1.0.0';

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(minutes: 5);

  // Cache
  static const Duration cacheExpiry = Duration(hours: 1);
  static const int maxCacheSize = 100 * 1024 * 1024; // 100 MB

  // Media
  static const int maxImageSizeBytes = 10 * 1024 * 1024; // 10 MB
  static const int maxVideoSizeBytes = 120 * 1024 * 1024; // 120 MB
  static const Duration maxReelDuration = Duration(seconds: 60);
  static const Duration maxVideoDuration = Duration(minutes: 10);

  // Authentication
  static const String jwtTokenKey = 'jwt_token';
  static const String refreshTokenKey = 'refresh_token';
  static const Duration sessionTimeout = Duration(hours: 24);

  // Features
  static const bool enableAnalytics = true;
  static const bool enableChatbot =
      bool.fromEnvironment('CHATBOT_ENABLED', defaultValue: false);
  static const bool enablePushNotifications = true;

  // Environment
  static bool get isProduction =>
      const bool.fromEnvironment('PRODUCTION', defaultValue: false);
  static bool get isDevelopment => !isProduction;
}
