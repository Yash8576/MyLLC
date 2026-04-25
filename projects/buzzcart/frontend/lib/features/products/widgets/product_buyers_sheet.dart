import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/models/models.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/url_helper.dart';

Future<void> showProductBuyersSheet({
  required BuildContext context,
  required ProductModel product,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProductBuyersSheet(product: product),
  );
}

class _ProductBuyersSheet extends StatefulWidget {
  const _ProductBuyersSheet({
    required this.product,
  });

  final ProductModel product;

  @override
  State<_ProductBuyersSheet> createState() => _ProductBuyersSheetState();
}

class _ProductBuyersSheetState extends State<_ProductBuyersSheet> {
  late final ApiService _api;

  List<ProductBuyerModel> _buyers = <ProductBuyerModel>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiService>();
    _loadBuyers();
  }

  Future<void> _loadBuyers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final buyers = await _api.getProductBuyers(widget.product.id);
      final sortedBuyers = List<ProductBuyerModel>.from(buyers)
        ..sort(_compareBuyers);

      if (!mounted) {
        return;
      }

      setState(() {
        _buyers = sortedBuyers;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Failed to load buyers';
      });
    }
  }

  int _compareBuyers(ProductBuyerModel a, ProductBuyerModel b) {
    final connectionSort =
        (b.isConnection ? 1 : 0).compareTo(a.isConnection ? 1 : 0);
    if (connectionSort != 0) {
      return connectionSort;
    }
    return _parseDate(b.purchaseDate).compareTo(_parseDate(a.purchaseDate));
  }

  DateTime _parseDate(String value) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buyerCount = _buyers.length;

    return FractionallySizedBox(
      heightFactor: 0.82,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    const Icon(Icons.people_outline_rounded, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Who bought this',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '$buyerCount ${buyerCount == 1 ? 'buyer' : 'buyers'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: theme.dividerColor),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _loadBuyers,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_buyers.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadBuyers,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          children: const [
            SizedBox(height: 120),
            Icon(Icons.shopping_bag_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 14),
            Center(
              child: Text(
                'No buyers to show yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(height: 8),
            Center(
              child: Text(
                'When people purchase this product, they will show up here.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBuyers,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: _buyers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final currentUserId = context.read<AuthProvider>().user?.id;
          final buyer = _buyers[index];
          return _BuyerListItem(
            buyer: buyer,
            isCurrentUser:
                currentUserId != null && currentUserId == buyer.buyerId,
          );
        },
      ),
    );
  }
}

class _BuyerListItem extends StatelessWidget {
  const _BuyerListItem({
    required this.buyer,
    required this.isCurrentUser,
  });

  final ProductBuyerModel buyer;
  final bool isCurrentUser;

  DateTime _parseDate(String value) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallbackName =
        buyer.buyerName.trim().isEmpty ? 'Unknown' : buyer.buyerName.trim();
    final buyerName = isCurrentUser ? '$fallbackName (You)' : fallbackName;
    final purchaseLabel = buyer.totalQuantity > 1
        ? 'Bought ${buyer.totalQuantity}'
        : 'Bought this';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: (buyer.buyerAvatar ?? '').trim().isNotEmpty
                ? NetworkImage(
                    UrlHelper.getPlatformUrl(buyer.buyerAvatar!),
                  )
                : null,
            child: (buyer.buyerAvatar ?? '').trim().isEmpty
                ? Text(
                    fallbackName.substring(0, 1).toUpperCase(),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        buyerName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      timeago.format(_parseDate(buyer.purchaseDate)),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  purchaseLabel,
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (buyer.isConnection) ...[
                  const SizedBox(height: 10),
                  const _BuyerBadge(
                    label: 'Connection',
                    color: AppColors.electricBlue,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BuyerBadge extends StatelessWidget {
  const _BuyerBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
