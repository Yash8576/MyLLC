import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/models/models.dart';
import '../../../core/providers/app_refresh_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/url_helper.dart';

class ProductCardSocialPreview extends StatelessWidget {
  const ProductCardSocialPreview({
    super.key,
    required this.productId,
    this.maxAvatars = 2,
  });

  final String productId;
  final int maxAvatars;

  static final Map<String, Future<_ProductCardSocialPreviewData>> _cache =
      <String, Future<_ProductCardSocialPreviewData>>{};

  static void clearCache({String? productId}) {
    if (productId == null || productId.trim().isEmpty) {
      _cache.clear();
      return;
    }

    final prefix = '${productId.trim()}::';
    _cache.removeWhere((key, _) => key.startsWith(prefix));
  }

  Future<_ProductCardSocialPreviewData> _loadPreview(
    BuildContext context,
    int productVersion,
  ) {
    if (productId.trim().isEmpty) {
      return Future<_ProductCardSocialPreviewData>.value(
        const _ProductCardSocialPreviewData(),
      );
    }

    final cacheKey = '${productId.trim()}::$productVersion';
    return _cache.putIfAbsent(cacheKey, () async {
      final api = context.read<ApiService>();
      final buyers = List<ProductBuyerModel>.from(
        await api.getProductBuyers(productId),
      )
        ..sort(_compareBuyers);

      return _ProductCardSocialPreviewData(
        buyers: buyers,
      );
    });
  }

  static int _compareBuyers(ProductBuyerModel a, ProductBuyerModel b) {
    final connectionSort =
        (b.isConnection ? 1 : 0).compareTo(a.isConnection ? 1 : 0);
    if (connectionSort != 0) {
      return connectionSort;
    }
    return _parseDate(b.purchaseDate).compareTo(_parseDate(a.purchaseDate));
  }

  static DateTime _parseDate(String value) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productVersion =
        context.select<AppRefreshProvider, int>((provider) => provider.productVersion);

    return FutureBuilder<_ProductCardSocialPreviewData>(
      future: _loadPreview(context, productVersion),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 14);
        }

        final data = snapshot.data!;
        if (data.buyers.isEmpty) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CompactSocialRow<ProductBuyerModel>(
                icon: Icons.shopping_bag_outlined,
                items: data.buyers,
                maxAvatars: maxAvatars,
                imageUrl: (buyer) => (buyer.buyerAvatar ?? '').trim(),
                label: (buyer) {
                  final name = buyer.buyerName.trim();
                  return name.isEmpty ? 'Unknown' : name;
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProductCardSocialPreviewData {
  const _ProductCardSocialPreviewData({
    this.buyers = const <ProductBuyerModel>[],
  });

  final List<ProductBuyerModel> buyers;
}

class _CompactSocialRow<T> extends StatelessWidget {
  const _CompactSocialRow({
    required this.icon,
    required this.items,
    required this.maxAvatars,
    required this.imageUrl,
    required this.label,
  });

  final IconData icon;
  final List<T> items;
  final int maxAvatars;
  final String Function(T item) imageUrl;
  final String Function(T item) label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewItems = items.take(maxAvatars).toList();
    final overflowCount = items.length - previewItems.length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color: theme.textTheme.bodySmall?.color,
        ),
        const SizedBox(width: 4),
        ...previewItems.map(
          (item) => Padding(
            padding: const EdgeInsets.only(right: 3),
            child: _CompactAvatar(
              imageUrl: imageUrl(item),
              label: label(item),
            ),
          ),
        ),
        if (overflowCount > 0)
          Container(
            height: 18,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: Text(
              '+$overflowCount',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          ),
      ],
    );
  }
}

class _CompactAvatar extends StatelessWidget {
  const _CompactAvatar({
    required this.imageUrl,
    required this.label,
  });

  final String imageUrl;
  final String label;

  @override
  Widget build(BuildContext context) {
    final safeLabel = label.trim().isEmpty ? 'Unknown' : label.trim();

    return CircleAvatar(
      radius: 9,
      backgroundImage: imageUrl.isNotEmpty
          ? CachedNetworkImageProvider(UrlHelper.getPlatformUrl(imageUrl))
          : null,
      child: imageUrl.isEmpty
          ? Text(
              safeLabel.substring(0, 1).toUpperCase(),
              style: const TextStyle(fontSize: 8),
            )
          : null,
    );
  }
}
