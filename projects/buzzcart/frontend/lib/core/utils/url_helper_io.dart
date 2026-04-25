// Native platform (iOS, Android, Desktop) URL helper
import 'dart:io' show Platform;
import 'dart:core';

class UrlHelperPlatform {
  /// For Android emulator, replace localhost with 10.0.2.2
  /// For other platforms, keep as-is
  static String convertUrl(String url) {
    if (Platform.isAndroid) {
      return url.replaceAll('localhost', '10.0.2.2');
    }
    return url;
  }

  static String convertPlayableVideoUrl(String url, String apiBaseUrl) {
    final normalizedUrl = convertUrl(url);
    if (!Platform.isWindows) {
      return normalizedUrl;
    }

    final parsed = Uri.tryParse(normalizedUrl);
    final host = parsed?.host.toLowerCase() ?? '';
    if (host != 'firebasestorage.googleapis.com' &&
        host != 'storage.googleapis.com') {
      return normalizedUrl;
    }

    final encoded = Uri.encodeQueryComponent(normalizedUrl);
    return '$apiBaseUrl/media/stream?url=$encoded';
  }
}
