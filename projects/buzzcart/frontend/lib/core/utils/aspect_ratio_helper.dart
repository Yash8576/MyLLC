import 'package:flutter/material.dart';

/// Helper class for managing Instagram-style aspect ratios
class AspectRatioHelper {
  /// Photo aspect ratio options (Instagram style)
  static const Map<String, AspectRatioOption> photoAspectRatios = {
    'square': AspectRatioOption(
      name: '1:1',
      description: 'Square (Instagram Classic)',
      ratio: 1.0,
      icon: Icons.crop_square,
    ),
    'portrait': AspectRatioOption(
      name: '4:5',
      description: 'Portrait',
      ratio: 4 / 5,
      icon: Icons.crop_portrait,
    ),
    'landscape': AspectRatioOption(
      name: '16:9',
      description: 'Landscape',
      ratio: 16 / 9,
      icon: Icons.crop_landscape,
    ),
  };

  /// Reel aspect ratio (vertical video)
  static const AspectRatioOption reelAspectRatio = AspectRatioOption(
    name: '9:16',
    description: 'Vertical Video (Reels)',
    ratio: 9 / 16,
    icon: Icons.smartphone,
  );

  /// Long-form video aspect ratio (landscape video)
  static const AspectRatioOption videoAspectRatio = AspectRatioOption(
    name: '16:9',
    description: 'Landscape Video',
    ratio: 16 / 9,
    icon: Icons.video_library,
  );

  /// Get aspect ratio for content type
  static AspectRatioOption getAspectRatioForType(String contentType, {String? photoRatio}) {
    switch (contentType) {
      case 'reel':
        return reelAspectRatio;
      case 'video':
        return videoAspectRatio;
      case 'photo':
        if (photoRatio != null && photoAspectRatios.containsKey(photoRatio)) {
          return photoAspectRatios[photoRatio]!;
        }
        return photoAspectRatios['square']!; // Default to square
      default:
        return photoAspectRatios['square']!;
    }
  }

  /// Get aspect ratio description for content type
  static String getAspectRatioDescription(String contentType) {
    switch (contentType) {
      case 'photo':
        return 'Choose your photo format (1:1, 4:5, or 16:9)';
      case 'reel':
        return 'Vertical video format (9:16)';
      case 'video':
        return 'Landscape video format (16:9)';
      default:
        return '';
    }
  }
}

/// Model for aspect ratio options
class AspectRatioOption {
  final String name;
  final String description;
  final double ratio;
  final IconData icon;

  const AspectRatioOption({
    required this.name,
    required this.description,
    required this.ratio,
    required this.icon,
  });
}
