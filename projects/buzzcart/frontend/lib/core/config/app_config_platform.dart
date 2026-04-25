// Platform-agnostic interface
// This file should never be used directly - it's replaced by conditional imports

class PlatformConfig {
  static String get baseHost => throw UnsupportedError(
      'Cannot determine platform. This should be replaced by conditional import.');

  static String get initialRouteOverride => '';
}
