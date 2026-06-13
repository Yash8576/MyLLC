// Native platform (iOS, Android, Desktop) URL helper
import 'dart:io' show Platform;
import 'dart:core';

import '../config/app_config.dart';

class UrlHelperPlatform {
  /// For Android emulator, replace localhost with 10.0.2.2
  /// For other platforms, keep as-is
  static String convertUrl(String url) {
    final normalizedUrl = _normalizeLocalhost(url);
    if (_isFirebaseStorageImage(normalizedUrl)) {
      final encoded = Uri.encodeQueryComponent(normalizedUrl);
      return '${AppConfig.apiBaseUrl}/media/proxy?url=$encoded';
    }

    return normalizedUrl;
  }

  static String _normalizeLocalhost(String url) {
    if (Platform.isAndroid) {
      return url.replaceAll('localhost', '10.0.2.2');
    }
    return url;
  }

  static String convertPlayableVideoUrl(String url, String apiBaseUrl) {
    final normalizedUrl = _normalizeLocalhost(url);
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

  static bool _isFirebaseStorageImage(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return false;
    }

    final host = uri.host.toLowerCase();
    final isFirebaseStorage = host == 'firebasestorage.googleapis.com' ||
        host == 'storage.googleapis.com';
    if (!isFirebaseStorage) {
      return false;
    }

    final decodedPath = Uri.decodeComponent(uri.path).toLowerCase();
    return decodedPath.endsWith('.jpg') ||
        decodedPath.endsWith('.jpeg') ||
        decodedPath.endsWith('.png') ||
        decodedPath.endsWith('.gif') ||
        decodedPath.endsWith('.webp') ||
        decodedPath.endsWith('.bmp') ||
        decodedPath.endsWith('.heic') ||
        decodedPath.endsWith('.heif');
  }
}
