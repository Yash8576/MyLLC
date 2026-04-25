// Platform-agnostic interface for URL conversion
// This file should never be used directly - it's replaced by conditional imports

class UrlHelperPlatform {
  static String convertUrl(String url) {
    throw UnsupportedError(
        'Cannot determine platform. This should be replaced by conditional import.');
  }

  static String convertPlayableVideoUrl(String url, String apiBaseUrl) {
    throw UnsupportedError(
        'Cannot determine platform. This should be replaced by conditional import.');
  }
}
