import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/models/models.dart';
import '../../../core/utils/url_helper.dart';
import '../../products/widgets/product_card_social_preview.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CartProvider>().fetchCart();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();
    final cart = cartProvider.cart;
    final showPageAppBar = MediaQuery.of(context).size.width >= 1024;
    const contentTopPadding = 0.0;

    if (cartProvider.isLoading) {
      return Scaffold(
        appBar: showPageAppBar ? AppBar(title: const Text('Your Cart')) : null,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (cart.items.isEmpty) {
      return Scaffold(
        appBar: showPageAppBar ? AppBar(title: const Text('Your Cart')) : null,
        body: SafeArea(
          top: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24 + contentTopPadding, 24, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.shopping_bag_outlined,
                      size: 80,
                      color: AppColors.lightMutedForeground,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Your cart is empty',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add some products to get started!',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.lightMutedForeground,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => context.go('/shop'),
                      icon: const Icon(Icons.shopping_bag),
                      label: const Text('Continue Shopping'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: showPageAppBar
          ? AppBar(
              title: Text('Your Cart (${cart.itemCount} items)'),
            )
          : null,
      body: Column(
        children: [
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, contentTopPadding, 16, 16),
                itemCount: cart.items.length,
                itemBuilder: (context, index) {
                  final item = cart.items[index];
                  return _CartItemCard(item: item);
                },
              ),
            ),
          ),
          // Cart summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Subtotal',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Text(
                      '\$${cart.subtotal.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Discount',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Text(
                      '-\$${cart.discount.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.successGreen,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      '\$${cart.total.toStringAsFixed(2)}',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/checkout'),
                    icon: const Icon(Icons.credit_card),
                    label: Text(
                      'Proceed to Checkout - \$${cart.total.toStringAsFixed(2)}',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItemModel item;

  const _CartItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();
    final maxQuantity = cartProvider.stockLimitFor(
      item.product.id,
      fallbackStock: item.product.stockQuantity,
    );
    final isAtMax = maxQuantity != null && item.quantity >= maxQuantity;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product image
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.lightMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: item.product.images.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl:
                            UrlHelper.getPlatformUrl(item.product.images[0]),
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.shopping_bag),
                      ),
                    )
                  : const Icon(Icons.shopping_bag),
            ),
            const SizedBox(width: 12),
            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.product.sellerName,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (item.product.stockQuantity > 0 &&
                      item.product.stockQuantity < 10) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Low stock',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '\$${item.product.price.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.electricBlue,
                        ),
                  ),
                  if (item.product.compareAtPrice != null &&
                      item.product.compareAtPrice! > item.product.price)
                    Text(
                      '\$${item.product.compareAtPrice!.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            decoration: TextDecoration.lineThrough,
                            color: AppColors.lightMutedForeground,
                          ),
                    ),
                  const SizedBox(height: 6),
                  ProductCardSocialPreview(
                    productId: item.product.id,
                    maxAvatars: 2,
                  ),
                ],
              ),
            ),
            // Quantity controls
            Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: item.quantity > 1
                          ? () => cartProvider.updateQuantity(
                                item.product.id,
                                item.quantity - 1,
                                maxQuantity: maxQuantity,
                              )
                          : null,
                    ),
                    Text(
                      '${item.quantity}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: !isAtMax
                          ? () => cartProvider.updateQuantity(
                                item.product.id,
                                item.quantity + 1,
                                maxQuantity: maxQuantity,
                              )
                          : null,
                    ),
                    if (isAtMax)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          'Max',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey[700],
                                  ),
                        ),
                      ),
                  ],
                ),
                IconButton(
                  onPressed: () async {
                    final shouldRemove = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) {
                        return AlertDialog(
                          title: const Text('Remove item?'),
                          content: Text(
                            'Remove ${item.product.title} from your cart?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(true),
                              child: const Text('Remove'),
                            ),
                          ],
                        );
                      },
                    );

                    if (shouldRemove == true) {
                      await cartProvider.removeFromCart(item.product.id);
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                  color: AppColors.destructive,
                  tooltip: 'Remove from cart',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
