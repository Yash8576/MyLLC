import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/app_refresh_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/url_helper.dart';
import '../../products/widgets/product_card_social_preview.dart';
import '../../products/widgets/product_buyers_sheet.dart';
import '../../products/widgets/product_reviews_sheet.dart';

class ShopPage extends StatefulWidget {
  final String? productId;
  final bool allowOwnProductPreview;

  const ShopPage({
    super.key,
    this.productId,
    this.allowOwnProductPreview = false,
  });

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  static const double _gridSpacing = 12;
  static const double _minTileWidth = 170;
  static const double _maxTileWidth = 260;
  static const double _detailImageMaxSize = 420;
  static const double _detailImageMinSize = 240;
  static const int _infiniteCarouselSeed = 1000;

  final PageController _mediaPageController = PageController(
    initialPage: _infiniteCarouselSeed,
  );

  int _calculateGridColumns(double availableWidth) {
    if (availableWidth <= 0) return 1;

    var columns =
        ((availableWidth + _gridSpacing) / (_minTileWidth + _gridSpacing))
            .floor();
    if (columns < 1) columns = 1;

    while (columns > 1) {
      final tileWidth =
          (availableWidth - (columns - 1) * _gridSpacing) / columns;
      if (tileWidth <= _maxTileWidth) {
        break;
      }
      columns++;
    }

    return columns;
  }

  late final ApiService _api;
  List<ProductModel> _allProducts = [];
  List<ProductModel> _products = [];
  ProductModel? _productDetail;
  List<ProductBuyerModel> _productBuyers = [];
  List<ReviewPreviewModel> _productReviewsPreview = [];
  int _productReviewsCount = 0;
  bool _loading = true;
  bool _buyersLoading = false;
  bool _reviewsPreviewLoading = false;
  String _category = '';
  int _currentImageIndex = 0;
  int _quantity = 1;
  final Map<String, int> _pendingCartQuantities = {};
  final Set<String> _updatingCartProductIds = {};
  AppRefreshProvider? _appRefreshProvider;
  int _lastProductVersion = 0;

  void _handleBackNavigation() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/shop');
  }

  @override
  void dispose() {
    _appRefreshProvider?.removeListener(_handleProductRefresh);
    _mediaPageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiService>();
    if (widget.productId != null) {
      _fetchProductDetail();
    } else {
      _fetchProducts();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<AppRefreshProvider>();
    if (!identical(_appRefreshProvider, provider)) {
      _appRefreshProvider?.removeListener(_handleProductRefresh);
      _appRefreshProvider = provider;
      _lastProductVersion = provider.productVersion;
      provider.addListener(_handleProductRefresh);
    }
  }

  void _handleProductRefresh() {
    final provider = _appRefreshProvider;
    if (provider == null || provider.productVersion == _lastProductVersion) {
      return;
    }

    _lastProductVersion = provider.productVersion;

    if (!mounted) {
      return;
    }

    if (widget.productId != null) {
      _fetchProductDetail();
    } else {
      _fetchProducts();
    }
  }

  Future<void> _fetchProducts() async {
    try {
      ProductCardSocialPreview.clearCache();
      setState(() => _loading = true);
      final currentUserId = context.read<AuthProvider>().user?.id;
      final data = await _api.getProducts();
      setState(() {
        _allProducts =
            data.where((product) => product.sellerId != currentUserId).toList();
        _applyCategoryFilter();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchProductDetail() async {
    try {
      setState(() => _loading = true);
      final currentUserId = context.read<AuthProvider>().user?.id;
      final productId = widget.productId!;
      final buyersFuture = _loadProductBuyers(productId);
      final reviewsFuture = _loadProductReviewsPreview(productId);
      unawaited(_api.warmProductReviewsRanked(productId));
      final data = await _api.getProduct(productId);
      if (!widget.allowOwnProductPreview && data.sellerId == currentUserId) {
        if (!mounted) {
          return;
        }
        context.go('/profile');
        return;
      }
      setState(() {
        _productDetail = data;
        _productReviewsCount = data.reviewsCount;
        _quantity = data.stockQuantity > 0 ? 1 : 0;
        _loading = false;
      });
      await Future.wait([buyersFuture, reviewsFuture]);
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadProductBuyers(String productId) async {
    if (productId.trim().isEmpty) {
      return;
    }

    if (mounted) {
      setState(() {
        _buyersLoading = true;
      });
    }

    try {
      final buyers = await _api.getProductBuyers(productId);
      final sortedBuyers = List<ProductBuyerModel>.from(buyers)
        ..sort(_compareBuyers);
      if (!mounted) {
        return;
      }
      setState(() {
        _productBuyers = sortedBuyers;
        _buyersLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _productBuyers = <ProductBuyerModel>[];
        _buyersLoading = false;
      });
    }
  }

  Future<void> _loadProductReviewsPreview(String productId) async {
    if (productId.trim().isEmpty) {
      return;
    }

    if (mounted) {
      setState(() {
        _reviewsPreviewLoading = true;
      });
    }

    try {
      final preview = await _api.getProductReviewPreview(productId, limit: 3);
      if (!mounted) {
        return;
      }
      setState(() {
        _productReviewsPreview = preview.reviews;
        _productReviewsCount = preview.reviewCount;
        _reviewsPreviewLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _productReviewsPreview = <ReviewPreviewModel>[];
        _reviewsPreviewLoading = false;
      });
    }
  }

  int _cartQuantityForProduct(List<CartItemModel> items, String productId) {
    for (final item in items) {
      if (item.product.id == productId) {
        return item.quantity;
      }
    }
    return 0;
  }

  int _remainingStockForProduct(ProductModel product, int inCartQuantity) {
    if (product.stockQuantity <= 0) {
      return 0;
    }
    final remaining = product.stockQuantity - inCartQuantity;
    return remaining > 0 ? remaining : 0;
  }

  int _effectiveCartQuantity(
    ProductModel product,
    List<CartItemModel> items,
  ) {
    return _pendingCartQuantities[product.id] ??
        _cartQuantityForProduct(items, product.id);
  }

  Future<bool> _confirmRemoveFromCart(ProductModel product) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove item?'),
          content: Text('Remove ${product.title} from your cart?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    return shouldRemove == true;
  }

  Future<void> _handleGridAddToCart(ProductModel product) async {
    if (_updatingCartProductIds.contains(product.id)) {
      return;
    }

    final cartItems = context.read<CartProvider>().cart.items;
    final inCartQuantity = _effectiveCartQuantity(product, cartItems);
    final remainingStock = _remainingStockForProduct(product, inCartQuantity);

    if (remainingStock <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Max stock already in cart')),
        );
      }
      return;
    }

    setState(() {
      _pendingCartQuantities[product.id] = inCartQuantity + 1;
      _updatingCartProductIds.add(product.id);
    });

    final added = await context
        .read<CartProvider>()
        .addToCart(product.id, maxQuantity: remainingStock);
    if (!mounted) return;

    setState(() {
      if (added) {
        _pendingCartQuantities.remove(product.id);
      } else {
        _pendingCartQuantities[product.id] = inCartQuantity;
      }
      _updatingCartProductIds.remove(product.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added ? 'Added to cart!' : 'Failed to add to cart',
        ),
      ),
    );
  }

  Future<void> _handleGridQuantityChange(
    ProductModel product,
    int targetQuantity,
  ) async {
    if (_updatingCartProductIds.contains(product.id)) {
      return;
    }

    final cartProvider = context.read<CartProvider>();
    final maxQuantity =
        product.stockQuantity > 0 ? product.stockQuantity : null;
    final cartItems = cartProvider.cart.items;
    final previousQuantity = _effectiveCartQuantity(product, cartItems);

    if (targetQuantity <= 0) {
      final shouldRemove = await _confirmRemoveFromCart(product);
      if (!shouldRemove) {
        return;
      }
    }

    setState(() {
      _pendingCartQuantities[product.id] =
          targetQuantity > 0 ? targetQuantity : 0;
      _updatingCartProductIds.add(product.id);
    });

    final updated = targetQuantity <= 0
        ? await cartProvider.removeFromCart(product.id)
        : await cartProvider.updateQuantity(
            product.id,
            targetQuantity,
            maxQuantity: maxQuantity,
          );

    if (!mounted) {
      return;
    }

    setState(() {
      if (updated) {
        _pendingCartQuantities.remove(product.id);
      } else {
        _pendingCartQuantities[product.id] = previousQuantity;
      }
      _updatingCartProductIds.remove(product.id);
    });

    if (updated) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to update cart')),
    );
  }

  Widget _buildGridCartAction(
    ProductModel product,
    int inCartQuantity,
    int remainingStock,
  ) {
    final canAddToCart = remainingStock > 0;
    final isUpdating = _updatingCartProductIds.contains(product.id);

    if (inCartQuantity < 1) {
      return Material(
        color: canAddToCart ? Colors.white : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(999),
        elevation: 2,
        child: InkWell(
          onTap: canAddToCart && !isUpdating
              ? () => _handleGridAddToCart(product)
              : null,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: isUpdating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : Icon(
                    Icons.add_shopping_cart_rounded,
                    size: 20,
                    color: canAddToCart ? Colors.black : Colors.grey,
                  ),
          ),
        ),
      );
    }

    final theme = Theme.of(context);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      elevation: 2,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildGridQuantityIconButton(
              icon: Icons.remove_circle_outline,
              onTap: isUpdating
                  ? null
                  : () => _handleGridQuantityChange(
                        product,
                        inCartQuantity - 1,
                      ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: SizedBox(
                width: 18,
                child: Text(
                  '$inCartQuantity',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            _buildGridQuantityIconButton(
              icon: Icons.add_circle_outline,
              onTap: !isUpdating && canAddToCart
                  ? () => _handleGridQuantityChange(
                        product,
                        inCartQuantity + 1,
                      )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridQuantityIconButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: Icon(
          icon,
          size: 21,
          color: isEnabled ? Colors.black87 : Colors.grey,
        ),
      ),
    );
  }

  Future<void> _handleAddToCart(
      ProductModel product, int remainingStock) async {
    final quantityToAdd = math.min(_quantity, remainingStock);
    if (quantityToAdd < 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Max stock already in cart')),
        );
      }
      return;
    }

    final added = await context.read<CartProvider>().addToCart(
          widget.productId!,
          quantity: quantityToAdd,
          maxQuantity: remainingStock,
        );
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? 'Added $quantityToAdd item(s) to cart!'
              : 'Failed to add to cart',
        ),
      ),
    );
  }

  bool _isLowStock(ProductModel product) =>
      product.stockQuantity > 0 && product.stockQuantity < 10;

  bool _hasDiscount(ProductModel product) =>
      product.compareAtPrice != null && product.compareAtPrice! > product.price;

  int _percentOff(ProductModel product) {
    final compareAt = product.compareAtPrice;
    if (compareAt == null || compareAt <= product.price) {
      return 0;
    }
    return (((compareAt - product.price) / compareAt) * 100).round();
  }

  int _selectedQuantityFor(int remainingStock) {
    if (remainingStock <= 0) {
      return 0;
    }
    return math.min(_quantity, remainingStock);
  }

  Widget _buildQuantitySelector(ProductModel product, int remainingStock) {
    final selectedQuantity = _selectedQuantityFor(remainingStock);
    final canDecrease = selectedQuantity > 1;
    final canIncrease =
        selectedQuantity > 0 && selectedQuantity < remainingStock;
    final showMax = remainingStock == 0 || selectedQuantity >= remainingStock;

    Widget buildStepButton({
      required IconData icon,
      required VoidCallback? onTap,
    }) {
      final theme = Theme.of(context);
      final isEnabled = onTap != null;

      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isEnabled
                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                : theme.colorScheme.onSurface.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 16,
            color: isEnabled
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      );
    }

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(
            'Qty',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          buildStepButton(
            icon: Icons.remove,
            onTap: canDecrease
                ? () => setState(() => _quantity = selectedQuantity - 1)
                : null,
          ),
          Text(
            '$selectedQuantity',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          if (canIncrease)
            buildStepButton(
              icon: Icons.add,
              onTap: () => setState(() => _quantity = selectedQuantity + 1),
            )
          else
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  showMax ? (product.stockQuantity > 0 ? 'Max' : 'Out') : 'Out',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _applyCategoryFilter() {
    if (_category.isEmpty) {
      _products = List<ProductModel>.from(_allProducts);
      return;
    }
    _products = _allProducts
        .where((product) =>
            product.category.toLowerCase() == _category.toLowerCase())
        .toList();
  }

  Future<void> _openExternalUrl(String rawUrl) async {
    final resolvedUrl = UrlHelper.getPlatformUrl(rawUrl);
    final uri = Uri.tryParse(resolvedUrl);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openReviewsSheet(ProductModel product) async {
    final didChange = await showProductReviewsSheet(
      context: context,
      product: product,
      onReviewChanged: widget.productId != null ? _fetchProductDetail : null,
    );
    if (didChange == true && mounted && widget.productId != null) {
      await _fetchProductDetail();
    }
  }

  Widget _buildCachedImage(
    String imageUrl, {
    BoxFit fit = BoxFit.cover,
    Widget? errorWidget,
  }) {
    final resolvedUrl = UrlHelper.getPlatformUrl(imageUrl);
    return CachedNetworkImage(
      imageUrl: resolvedUrl,
      cacheKey: resolvedUrl,
      fit: fit,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      useOldImageOnUrlChange: true,
      errorWidget: (_, __, ___) => errorWidget ?? const SizedBox.shrink(),
    );
  }

  Future<void> _openBuyersSheet(ProductModel product) async {
    await showProductBuyersSheet(
      context: context,
      product: product,
    );
  }

  Future<void> _openDocumentAssistant(ProductModel product) async {
    if (!mounted) {
      return;
    }

    final detail = product.specificationPdfUrl?.trim().isNotEmpty == true
        ? ' Product PDF support is already saved for future rollout.'
        : '';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Coming soon.$detail')),
    );
  }

  int _compareBuyers(ProductBuyerModel a, ProductBuyerModel b) {
    final connectionSort =
        (b.isConnection ? 1 : 0).compareTo(a.isConnection ? 1 : 0);
    if (connectionSort != 0) {
      return connectionSort;
    }
    return _parseBuyerDate(b.purchaseDate)
        .compareTo(_parseBuyerDate(a.purchaseDate));
  }

  DateTime _parseBuyerDate(String value) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  List<String> get _availableCategories {
    final categories = _allProducts
        .map((product) => product.category.trim())
        .where((category) => category.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return categories;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.productId != null) {
      return _buildProductDetail();
    }
    return _buildProductGrid();
  }

  Widget _buildProductDetail() {
    final showPageAppBar = MediaQuery.of(context).size.width >= 1024;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_productDetail == null) {
      return Scaffold(
        appBar: showPageAppBar
            ? AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _handleBackNavigation,
                ),
              )
            : null,
        body: const Center(child: Text('Product not found')),
      );
    }

    final product = _productDetail!;
    final mediaQueue = _buildMediaQueue(product);
    final isOwnPreviewMode = widget.allowOwnProductPreview;
    final cartItems = context.watch<CartProvider>().cart.items;
    final inCartQuantity = _cartQuantityForProduct(cartItems, product.id);
    final remainingStock = _remainingStockForProduct(product, inCartQuantity);

    return Scaffold(
      appBar: showPageAppBar
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _handleBackNavigation,
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () {
                    context.push(
                      '/messages',
                      extra: MessagesRouteIntent(
                        draft: MessageComposerDraft.product(product),
                      ),
                    );
                  },
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (!showPageAppBar)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: _handleBackNavigation,
                            visualDensity: VisualDensity.compact,
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.share),
                            onPressed: () {
                              context.push(
                                '/messages',
                                extra: MessagesRouteIntent(
                                  draft: MessageComposerDraft.product(product),
                                ),
                              );
                            },
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                  if (mediaQueue.isNotEmpty)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final availableWidth = constraints.maxWidth;
                        final squareSize = availableWidth.clamp(
                          _detailImageMinSize,
                          _detailImageMaxSize,
                        );
                        final activeMediaIndex =
                            _currentImageIndex % mediaQueue.length;

                        return Center(
                          child: SizedBox(
                            width: squareSize,
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: PageView.builder(
                                      controller: _mediaPageController,
                                      onPageChanged: (index) => setState(
                                          () => _currentImageIndex = index),
                                      itemBuilder: (context, index) {
                                        final media = mediaQueue[
                                            index % mediaQueue.length];
                                        final mediaType =
                                            (media['type'] as String?) ??
                                                'image';
                                        final mediaUrl =
                                            (media['url'] as String?) ?? '';
                                        if (mediaType == 'video') {
                                          return Container(
                                            color: Colors.black,
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                Container(
                                                  decoration:
                                                      const BoxDecoration(
                                                    gradient: LinearGradient(
                                                      begin: Alignment.topLeft,
                                                      end:
                                                          Alignment.bottomRight,
                                                      colors: [
                                                        Colors.black87,
                                                        Colors.black54
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                Center(
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      const Icon(
                                                        Icons.play_circle_fill,
                                                        size: 76,
                                                        color: Colors.white,
                                                      ),
                                                      const SizedBox(
                                                          height: 12),
                                                      Text(
                                                        media['name']
                                                                as String? ??
                                                            'Product video',
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      if (mediaUrl
                                                          .isNotEmpty) ...[
                                                        const SizedBox(
                                                            height: 8),
                                                        const Text(
                                                          'Swipe or use arrows to continue',
                                                          style: TextStyle(
                                                            color:
                                                                Colors.white70,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }

                                        return _buildCachedImage(
                                          mediaUrl,
                                          fit: BoxFit.cover,
                                          errorWidget: Container(
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.image,
                                                size: 64),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  if (mediaQueue.length > 1)
                                    Positioned(
                                      bottom: 16,
                                      left: 0,
                                      right: 0,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: List.generate(
                                          mediaQueue.length,
                                          (index) => Container(
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 4),
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: activeMediaIndex == index
                                                  ? Colors.white
                                                  : Colors.white54,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (mediaQueue.length > 1)
                                    Positioned(
                                      left: 8,
                                      top: 0,
                                      bottom: 0,
                                      child: Center(
                                        child: _CarouselArrowButton(
                                          icon: Icons.chevron_left,
                                          onPressed: () =>
                                              _mediaPageController.previousPage(
                                            duration: const Duration(
                                                milliseconds: 250),
                                            curve: Curves.easeOut,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (mediaQueue.length > 1)
                                    Positioned(
                                      right: 8,
                                      top: 0,
                                      bottom: 0,
                                      child: Center(
                                        child: _CarouselArrowButton(
                                          icon: Icons.chevron_right,
                                          onPressed: () =>
                                              _mediaPageController.nextPage(
                                            duration: const Duration(
                                                milliseconds: 250),
                                            curve: Curves.easeOut,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.title,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        if (!_hasDiscount(product))
                          Text(
                            '\$${product.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.electricBlue,
                            ),
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '\$${product.price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.electricBlue,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          AppColors.successGreen.withAlpha(24),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '${_percentOff(product)}% OFF',
                                      style: const TextStyle(
                                        color: AppColors.successGreen,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '\$${product.compareAtPrice!.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 10),
                        if (product.specificationPdfUrl != null) ...[
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => _openDocumentAssistant(product),
                              icon: const Icon(Icons.chat_bubble_outline),
                              label:
                                  const Text('Product Assistant (Coming soon)'),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 14,
                          runSpacing: 10,
                          children: [
                            InkWell(
                              onTap: () => _openReviewsSheet(product),
                              borderRadius: BorderRadius.circular(999),
                              child: Ink(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 18,
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      product.reviewsCount > 0
                                          ? '${product.rating.toStringAsFixed(1)} (${product.reviewsCount} ratings)'
                                          : 'No ratings yet',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => _openReviewsSheet(product),
                              borderRadius: BorderRadius.circular(999),
                              child: Ink(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: _ReviewsPreviewButton(
                                  reviews: _productReviewsPreview,
                                  reviewCount: _productReviewsCount,
                                  isLoading: _reviewsPreviewLoading,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => _openBuyersSheet(product),
                              borderRadius: BorderRadius.circular(999),
                              child: Ink(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: _BuyerPreviewButton(
                                  buyers: _productBuyers,
                                  isLoading: _buyersLoading,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if ((product.brandName ?? '').isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            product.brandName!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (product.category.isNotEmpty)
                              Chip(label: Text(product.category)),
                            if (product.condition.isNotEmpty)
                              Chip(
                                  label: Text(product.condition.toUpperCase())),
                            if (product.stockQuantity <= 0)
                              const Chip(label: Text('Out of stock'))
                            else if (_isLowStock(product))
                              const Chip(label: Text('Low stock')),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          product.description,
                          style: const TextStyle(fontSize: 16, height: 1.5),
                        ),
                        if (product.bulletPoints.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const Text(
                            'Key features',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ...product.bulletPoints.map(
                            (point) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• '),
                                  Expanded(child: Text(point)),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (product.highlightedSpecifications.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const Text(
                            'Specifications',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ...product.highlightedSpecifications.entries.map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 140,
                                    child: Text(
                                      entry.key,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Expanded(child: Text(entry.value)),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (product.specificationPdfUrl != null ||
                            product.mediaVideos.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const Text(
                            'Supporting Media',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          if (product.specificationPdfUrl != null)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.picture_as_pdf,
                                  color: Colors.red),
                              title: const Text('Open specification PDF'),
                              onTap: () => _openExternalUrl(
                                product.specificationPdfUrl!,
                              ),
                            ),
                          ...product.mediaVideos.map(
                            (videoUrl) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.play_circle_outline),
                              title: const Text('Open product video'),
                              onTap: () => _openExternalUrl(videoUrl),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        if (isOwnPreviewMode)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Preview mode: cart actions are disabled for your own listing.',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isOwnPreviewMode)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(26),
                    offset: const Offset(0, -2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: _buildQuantitySelector(product, remainingStock),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 7,
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: remainingStock > 0
                            ? () => _handleAddToCart(product, remainingStock)
                            : null,
                        icon: const Icon(Icons.shopping_cart),
                        label: Text(
                          remainingStock > 0 ? 'Add to Cart' : 'Out of stock',
                        ),
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

  List<Map<String, dynamic>> _buildMediaQueue(ProductModel product) {
    if (product.mediaQueue.isNotEmpty) {
      return product.mediaQueue;
    }

    final fallbackQueue = <Map<String, dynamic>>[
      ...product.images.map(
        (url) => <String, dynamic>{
          'type': 'image',
          'url': url,
          'name': 'Product photo',
        },
      ),
      ...product.mediaVideos.map(
        (url) => <String, dynamic>{
          'type': 'video',
          'url': url,
          'name': 'Product video',
        },
      ),
    ];

    return fallbackQueue;
  }

  Widget _buildProductGrid() {
    final showPageAppBar = MediaQuery.of(context).size.width >= 1024;

    Widget categoryFilter({EdgeInsetsGeometry padding = EdgeInsets.zero}) {
      return Padding(
        padding: padding,
        child: DropdownButtonFormField<String>(
          initialValue: _category,
          decoration: const InputDecoration(
            labelText: 'Filter by Category',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(value: '', child: Text('All Categories')),
            ..._availableCategories.map(
              (category) => DropdownMenuItem(
                value: category,
                child: Text(category),
              ),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _category = value ?? '';
              _applyCategoryFilter();
            });
          },
        ),
      );
    }

    return Scaffold(
      appBar: showPageAppBar
          ? AppBar(
              title: const Text('Shop'),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: categoryFilter(
                  padding: const EdgeInsets.all(8),
                ),
              ),
            )
          : null,
      body: _loading
          ? Column(
              children: [
                if (!showPageAppBar)
                  categoryFilter(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  ),
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            )
          : Column(
              children: [
                if (!showPageAppBar)
                  categoryFilter(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchProducts,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final columns =
                            _calculateGridColumns(constraints.maxWidth - 24);
                        return GridView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            childAspectRatio: 0.64,
                            crossAxisSpacing: _gridSpacing,
                            mainAxisSpacing: _gridSpacing,
                          ),
                          itemCount: _products.length,
                          itemBuilder: (context, index) {
                            final product = _products[index];
                            final cartItems =
                                context.watch<CartProvider>().cart.items;
                            final inCartQuantity =
                                _effectiveCartQuantity(product, cartItems);
                            final remainingStock = _remainingStockForProduct(
                                product, inCartQuantity);

                            return Card(
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () =>
                                    context.push('/shop/${product.id}'),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          _buildCachedImage(
                                            product.images.isNotEmpty
                                                ? product.images.first
                                                : '',
                                            fit: BoxFit.cover,
                                            errorWidget: Container(
                                              color: Colors.grey[300],
                                              child: const Icon(Icons.image),
                                            ),
                                          ),
                                          Positioned(
                                            right: 10,
                                            bottom: 10,
                                            child: _buildGridCartAction(
                                              product,
                                              inCartQuantity,
                                              remainingStock,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w500),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            product.brandName ??
                                                product.sellerName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          if (!_hasDiscount(product))
                                            Text(
                                              '\$${product.price.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.electricBlue,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            )
                                          else
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        '\$${product.price.toStringAsFixed(2)}',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: AppColors
                                                              .electricBlue,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: AppColors
                                                            .successGreen
                                                            .withAlpha(24),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(999),
                                                      ),
                                                      child: Text(
                                                        '${_percentOff(product)}% OFF',
                                                        style: const TextStyle(
                                                          color: AppColors
                                                              .successGreen,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '\$${product.compareAtPrice!.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    decoration: TextDecoration
                                                        .lineThrough,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          const SizedBox(height: 6),
                                          ProductCardSocialPreview(
                                            productId: product.id,
                                            maxAvatars: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CarouselArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _CarouselArrowButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withAlpha(120),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _BuyerPreviewButton extends StatelessWidget {
  const _BuyerPreviewButton({
    required this.buyers,
    required this.isLoading,
  });

  final List<ProductBuyerModel> buyers;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewBuyers = buyers.take(3).toList();
    final overflowCount = buyers.length - previewBuyers.length;
    final buyerLabel =
        buyers.length == 1 ? '1 buyer' : '${buyers.length} buyers';

    if (isLoading && buyers.isEmpty) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (previewBuyers.isEmpty) {
      return const Text(
        'No buyers yet',
        style: TextStyle(
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < previewBuyers.length; index++) ...[
              if (index > 0) const SizedBox(width: 4),
              _BuyerPreviewAvatar(buyer: previewBuyers[index]),
            ],
            if (overflowCount > 0) ...[
              const SizedBox(width: 4),
              Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+$overflowCount',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(width: 8),
        Text(
          buyerLabel,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _BuyerPreviewAvatar extends StatelessWidget {
  const _BuyerPreviewAvatar({
    required this.buyer,
  });

  final ProductBuyerModel buyer;

  @override
  Widget build(BuildContext context) {
    final displayName =
        buyer.buyerName.trim().isEmpty ? 'Unknown' : buyer.buyerName.trim();
    final avatarUrl = (buyer.buyerAvatar ?? '').trim();

    return CircleAvatar(
      radius: 13,
      backgroundImage: avatarUrl.isNotEmpty
          ? CachedNetworkImageProvider(UrlHelper.getPlatformUrl(avatarUrl))
          : null,
      child: avatarUrl.isEmpty
          ? Text(
              displayName.substring(0, 1).toUpperCase(),
              style: const TextStyle(fontSize: 11),
            )
          : null,
    );
  }
}

class _ReviewsPreviewButton extends StatelessWidget {
  const _ReviewsPreviewButton({
    required this.reviews,
    required this.reviewCount,
    required this.isLoading,
  });

  final List<ReviewPreviewModel> reviews;
  final int reviewCount;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewReviews = reviews.take(3).toList();
    final overflowCount = math.max(0, reviewCount - previewReviews.length);
    final reviewLabel = reviewCount == 1 ? '1 review' : '$reviewCount reviews';

    if (isLoading && reviews.isEmpty && reviewCount == 0) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (previewReviews.isEmpty) {
      return Text(
        reviewCount > 0 ? reviewLabel : 'No reviews yet',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < previewReviews.length; index++) ...[
              if (index > 0) const SizedBox(width: 4),
              _ReviewPreviewAvatar(review: previewReviews[index]),
            ],
            if (overflowCount > 0) ...[
              const SizedBox(width: 4),
              Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+$overflowCount',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(width: 8),
        Text(
          reviewLabel,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ReviewPreviewAvatar extends StatelessWidget {
  const _ReviewPreviewAvatar({
    required this.review,
  });

  final ReviewPreviewModel review;

  @override
  Widget build(BuildContext context) {
    final displayName =
        review.username.trim().isEmpty ? 'Unknown' : review.username.trim();
    final avatarUrl = (review.userAvatar ?? '').trim();

    return CircleAvatar(
      radius: 13,
      backgroundImage: avatarUrl.isNotEmpty
          ? CachedNetworkImageProvider(UrlHelper.getPlatformUrl(avatarUrl))
          : null,
      child: avatarUrl.isEmpty
          ? Text(
              displayName.substring(0, 1).toUpperCase(),
              style: const TextStyle(fontSize: 11),
            )
          : null,
    );
  }
}
