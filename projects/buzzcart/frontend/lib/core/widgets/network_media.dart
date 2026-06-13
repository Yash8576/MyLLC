import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../utils/url_helper.dart';

class AppMediaCacheManager {
  AppMediaCacheManager._();

  static final BaseCacheManager instance = CacheManager(
    Config(
      'buzzcartMediaCache',
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 2000,
    ),
  );
}

class AppImageProviders {
  AppImageProviders._();

  static ImageProvider? network(String? imageUrl) {
    final resolvedUrl = UrlHelper.getPlatformUrl(imageUrl);
    if (resolvedUrl.isEmpty) {
      return null;
    }

    return CachedNetworkImageProvider(
      resolvedUrl,
      cacheManager: AppMediaCacheManager.instance,
    );
  }
}

class AppCachedImage extends StatelessWidget {
  const AppCachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Alignment alignment;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = UrlHelper.getPlatformUrl(imageUrl);
    final fallback = errorWidget ??
        Container(
          width: width,
          height: height,
          color: Colors.grey[300],
          alignment: Alignment.center,
          child: const Icon(Icons.image),
        );

    Widget child;
    if (resolvedUrl.isEmpty) {
      child = fallback;
    } else {
      child = CachedNetworkImage(
        imageUrl: resolvedUrl,
        cacheManager: AppMediaCacheManager.instance,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        fadeInDuration: const Duration(milliseconds: 120),
        fadeOutDuration: Duration.zero,
        placeholderFadeInDuration: Duration.zero,
        useOldImageOnUrlChange: true,
        memCacheWidth:
            width != null && width!.isFinite ? width!.round() * 2 : null,
        memCacheHeight:
            height != null && height!.isFinite ? height!.round() * 2 : null,
        placeholder: (_, __) =>
            placeholder ??
            Container(
              width: width,
              height: height,
              color: Colors.grey[200],
            ),
        errorWidget: (_, __, ___) => fallback,
      );
    }

    if (borderRadius == null) {
      return child;
    }

    return ClipRRect(
      borderRadius: borderRadius!,
      child: child,
    );
  }
}

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    required this.avatarUrl,
    this.radius = 20,
    this.backgroundColor,
    this.textStyle,
  });

  final String name;
  final String? avatarUrl;
  final double radius;
  final Color? backgroundColor;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final provider = AppImageProviders.network(avatarUrl);
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? AppColorsFallback.avatarBackground,
      backgroundImage: provider,
      child: provider == null
          ? Text(
              initial,
              style: textStyle ??
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            )
          : null,
    );
  }
}

class AppColorsFallback {
  static const avatarBackground = Color(0xFF2388FF);
}
