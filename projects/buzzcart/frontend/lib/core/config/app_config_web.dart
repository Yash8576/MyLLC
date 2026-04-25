// Web-specific configuration

class PlatformConfig {
  static String get baseHost {
    final host = Uri.base.host.trim();
    return host.isEmpty ? 'localhost' : host;
  }

  static String get initialRouteOverride {
    final initialRoute = Uri.base.queryParameters['initialRoute']?.trim() ?? '';
    return initialRoute;
  }
}
