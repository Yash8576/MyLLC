import '../config/app_config.dart';
import 'url_helper_platform.dart'
    if (dart.library.html) 'url_helper_web.dart'
    if (dart.library.io) 'url_helper_io.dart';

/// Helper class for handling cross-platform URLs
class UrlHelper {
  /// Converts backend URLs to platform-specific URLs.
  ///
  /// For Android emulator, replaces localhost with 10.0.2.2
  /// For other platforms, keeps the URL as-is
  static String getPlatformUrl(String? url) {
    if (url == null || url.isEmpty) {
      return '';
    }

    return UrlHelperPlatform.convertUrl(url);
  }

  static String getPlayableVideoUrl(String? url) {
    final resolvedUrl = getPlatformUrl(url);
    if (resolvedUrl.isEmpty) {
      return '';
    }

    return UrlHelperPlatform.convertPlayableVideoUrl(
      resolvedUrl,
      AppConfig.apiBaseUrl,
    );
  }

  /// Gets the full storage URL for a media path.
  ///
  /// If the path is already a full URL, converts it to platform-specific
  /// If it's a relative path, prepends the storage base URL
  static String getStorageUrl(String? path) {
    if (path == null || path.isEmpty) {
      return '';
    }

    // If it's already a full URL, make it platform-specific
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return getPlatformUrl(path);
    }

    // If it's a relative path, prepend storage base URL
    // Remove leading slash if present to avoid double slashes
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '${AppConfig.storageBaseUrl}/$cleanPath';
  }
}
