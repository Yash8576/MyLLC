// Web-specific URL helper
import '../config/app_config.dart';

class UrlHelperPlatform {
  /// On web, route Firebase image URLs through the backend image proxy.
  ///
  /// This avoids browser/CanvasKit decode failures on Firebase-hosted PNGs with
  /// metadata while keeping non-image URLs, such as PDFs, direct.
  static String convertUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return url;
    }

    final host = uri.host.toLowerCase();
    final isFirebaseStorage = host == 'firebasestorage.googleapis.com' ||
        host == 'storage.googleapis.com';
    if (!isFirebaseStorage || !_looksLikeImageUrl(uri)) {
      return url;
    }

    return '${AppConfig.apiBaseUrl}/media/proxy?url=${Uri.encodeComponent(url)}';
  }

  static String convertPlayableVideoUrl(String url, String apiBaseUrl) {
    return url;
  }

  static bool _looksLikeImageUrl(Uri uri) {
    final decodedPath = Uri.decodeComponent(uri.path).toLowerCase();
    return decodedPath.endsWith('.jpg') ||
        decodedPath.endsWith('.jpeg') ||
        decodedPath.endsWith('.png') ||
        decodedPath.endsWith('.gif') ||
        decodedPath.endsWith('.webp') ||
        decodedPath.endsWith('.heic') ||
        decodedPath.endsWith('.heif');
  }
}
