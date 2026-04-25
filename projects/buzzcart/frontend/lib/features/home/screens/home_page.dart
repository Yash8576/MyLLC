import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../../core/models/models.dart';
import '../../../core/providers/app_refresh_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/url_helper.dart';
import '../../layout/main_layout.dart';
import '../../products/widgets/product_card_social_preview.dart';

final Map<String, int> _homeVideoDurationCache = <String, int>{};

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const double _pageMaxWidth = 760;
  static const double _mediaCardMaxWidth = 560;
  static const double _productRailCardWidth = 188;
  static const double _productRailHeight = 308;
  static const double _desktopListCacheExtent = 2200;
  static const double _mobileListCacheExtent = 640;

  List<_HomeSection> _sections = [];
  bool _isLoading = true;
  String? _error;
  final Map<int, ScrollController> _productRailControllers = {};
  final ScrollController _feedScrollController = ScrollController();
  final GlobalKey _feedViewportKey = GlobalKey();
  final Map<int, GlobalKey> _inlineReelSectionKeys = {};
  final Set<int> _canScrollRailLeft = {};
  final Set<int> _canScrollRailRight = {};
  final Map<String, int> _pendingCartQuantities = {};
  final Set<String> _updatingCartProductIds = {};
  AppRefreshProvider? _appRefreshProvider;
  int _lastContentVersion = 0;
  int _lastProductVersion = 0;
  int? _activeInlineReelSectionIndex;
  bool _areInlineReelsMuted = true;
  bool _inlineReelVisibilityCheckScheduled = false;
  Map<String, VideoModel> _videoLookupByUrl = <String, VideoModel>{};

  @override
  void initState() {
    super.initState();
    _feedScrollController.addListener(_handleFeedScroll);
    _fetchFeed();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<AppRefreshProvider>();
    if (!identical(_appRefreshProvider, provider)) {
      _appRefreshProvider?.removeListener(_handleAppRefresh);
      _appRefreshProvider = provider;
      _lastContentVersion = provider.contentVersion;
      _lastProductVersion = provider.productVersion;
      provider.addListener(_handleAppRefresh);
    }
  }

  @override
  void dispose() {
    _appRefreshProvider?.removeListener(_handleAppRefresh);
    _feedScrollController
      ..removeListener(_handleFeedScroll)
      ..dispose();
    for (final controller in _productRailControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handleFeedScroll() {
    if (_inlineReelVisibilityCheckScheduled) {
      return;
    }

    _inlineReelVisibilityCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inlineReelVisibilityCheckScheduled = false;
      if (!mounted) {
        return;
      }
      _updateActiveInlineReel();
    });
  }

  void _handleAppRefresh() {
    final provider = _appRefreshProvider;
    if (provider == null) {
      return;
    }

    final didContentChange = provider.contentVersion != _lastContentVersion;
    final didProductChange = provider.productVersion != _lastProductVersion;
    if (!didContentChange && !didProductChange) {
      return;
    }

    _lastContentVersion = provider.contentVersion;
    _lastProductVersion = provider.productVersion;

    if (!mounted) {
      return;
    }
    _fetchFeed();
  }

  ScrollController _getProductRailController(int sectionIndex) {
    return _productRailControllers.putIfAbsent(sectionIndex, () {
      final controller = ScrollController();
      controller.addListener(() => _updateRailScrollState(sectionIndex));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _updateRailScrollState(sectionIndex);
      });
      return controller;
    });
  }

  void _updateRailScrollState(int sectionIndex) {
    final controller = _productRailControllers[sectionIndex];
    if (controller == null || !controller.hasClients || !mounted) {
      return;
    }

    final canLeft = controller.offset > 2;
    final canRight =
        controller.offset < controller.position.maxScrollExtent - 2;
    final wasLeft = _canScrollRailLeft.contains(sectionIndex);
    final wasRight = _canScrollRailRight.contains(sectionIndex);

    if (canLeft == wasLeft && canRight == wasRight) {
      return;
    }

    setState(() {
      if (canLeft) {
        _canScrollRailLeft.add(sectionIndex);
      } else {
        _canScrollRailLeft.remove(sectionIndex);
      }

      if (canRight) {
        _canScrollRailRight.add(sectionIndex);
      } else {
        _canScrollRailRight.remove(sectionIndex);
      }
    });
  }

  Future<void> _scrollProductRail(int sectionIndex, bool forward) async {
    final controller = _productRailControllers[sectionIndex];
    if (controller == null || !controller.hasClients) {
      return;
    }

    const delta = _productRailCardWidth * 1.75;
    final target =
        forward ? controller.offset + delta : controller.offset - delta;
    final clampedTarget = target.clamp(
      controller.position.minScrollExtent,
      controller.position.maxScrollExtent,
    );

    await controller.animateTo(
      clampedTarget.toDouble(),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _pruneProductRailControllers(List<_HomeSection> sections) {
    final activeRailIndexes = <int>{};
    for (var index = 0; index < sections.length; index++) {
      if (sections[index].type == _HomeSectionType.productRail) {
        activeRailIndexes.add(index);
      }
    }

    final staleIndexes = _productRailControllers.keys
        .where((index) => !activeRailIndexes.contains(index))
        .toList();

    for (final index in staleIndexes) {
      _productRailControllers.remove(index)?.dispose();
      _canScrollRailLeft.remove(index);
      _canScrollRailRight.remove(index);
    }
  }

  bool _sectionContainsInlineReel(_HomeSection section) {
    if (section.type == _HomeSectionType.reel) {
      return true;
    }
    if (section.type == _HomeSectionType.post) {
      final post = section.data as PostModel;
      return post.mediaType == 'reel';
    }
    return false;
  }

  void _pruneInlineReelKeys(List<_HomeSection> sections) {
    final activeIndexes = <int>{};
    for (var index = 0; index < sections.length; index++) {
      if (_sectionContainsInlineReel(sections[index])) {
        activeIndexes.add(index);
      }
    }

    final staleIndexes = _inlineReelSectionKeys.keys
        .where((index) => !activeIndexes.contains(index))
        .toList();

    for (final index in staleIndexes) {
      _inlineReelSectionKeys.remove(index);
    }

    if (_activeInlineReelSectionIndex != null &&
        !activeIndexes.contains(_activeInlineReelSectionIndex)) {
      _activeInlineReelSectionIndex = null;
    }
  }

  GlobalKey _getInlineReelSectionKey(int sectionIndex) {
    return _inlineReelSectionKeys.putIfAbsent(sectionIndex, GlobalKey.new);
  }

  void _scheduleInlineReelVisibilityCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _updateActiveInlineReel();
    });
  }

  void _updateActiveInlineReel() {
    final viewportContext = _feedViewportKey.currentContext;
    if (viewportContext == null || !mounted) {
      return;
    }

    final viewportBox = viewportContext.findRenderObject() as RenderBox?;
    if (viewportBox == null || !viewportBox.hasSize) {
      return;
    }

    final viewportOrigin = viewportBox.localToGlobal(Offset.zero);
    final viewportTop = viewportOrigin.dy;
    final viewportBottom = viewportTop + viewportBox.size.height;

    double bestVisibleHeight = 0;
    int? bestIndex;

    for (final entry in _inlineReelSectionKeys.entries) {
      final sectionContext = entry.value.currentContext;
      if (sectionContext == null) {
        continue;
      }

      final sectionBox = sectionContext.findRenderObject() as RenderBox?;
      if (sectionBox == null || !sectionBox.hasSize) {
        continue;
      }

      final sectionOrigin = sectionBox.localToGlobal(Offset.zero);
      final sectionTop = sectionOrigin.dy;
      final sectionBottom = sectionTop + sectionBox.size.height;
      final visibleHeight = math.min(sectionBottom, viewportBottom) -
          math.max(sectionTop, viewportTop);

      if (visibleHeight > bestVisibleHeight) {
        bestVisibleHeight = visibleHeight;
        bestIndex = entry.key;
      }
    }

    if (bestVisibleHeight < 160) {
      bestIndex = null;
    }

    if (_activeInlineReelSectionIndex == bestIndex) {
      return;
    }

    setState(() {
      _activeInlineReelSectionIndex = bestIndex;
    });
  }

  Future<void> _fetchFeed() async {
    ProductCardSocialPreview.clearCache();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = context.read<ApiService>();
      final currentUserId = context.read<AuthProvider>().user?.id;
      final results = await Future.wait([
        api.getProducts().catchError((_) => <ProductModel>[]),
        api
            .getDiscoveryFeed(limit: 30)
            .catchError((_) => FeedResponse(posts: [])),
        api.getVideos().catchError((_) => <VideoModel>[]),
        api.getReels().catchError((_) => <ReelModel>[]),
      ]);

      final products = (results[0] as List<ProductModel>)
          .where((product) => product.sellerId != currentUserId)
          .toList()
        ..sort(
          (a, b) => _parseDate(b.createdAt).compareTo(_parseDate(a.createdAt)),
        );

      final posts = (results[1] as FeedResponse)
          .posts
          .where((post) => post.userId != currentUserId)
          .toList()
        ..sort(
          (a, b) => _parseDate(b.createdAt).compareTo(_parseDate(a.createdAt)),
        );

      final publishedMediaUrls = posts
          .where(
              (post) => post.mediaType == 'video' || post.mediaType == 'reel')
          .map((post) => post.mediaUrl)
          .toSet();

      final allVideos = (results[2] as List<VideoModel>);
      final videos = allVideos
          .where(
            (video) =>
                video.creatorId != currentUserId &&
                !publishedMediaUrls.contains(video.url),
          )
          .toList()
        ..sort(
          (a, b) => _parseDate(b.createdAt).compareTo(_parseDate(a.createdAt)),
        );

      final reels = (results[3] as List<ReelModel>)
          .where(
            (reel) =>
                reel.creatorId != currentUserId &&
                !publishedMediaUrls.contains(reel.url),
          )
          .toList()
        ..sort(
          (a, b) => _parseDate(b.createdAt).compareTo(_parseDate(a.createdAt)),
        );

      final sections = _buildRandomizedSections(
        productRails: _chunkProducts(products, 8),
        posts: posts,
        reels: reels,
        videos: videos,
      );
      _pruneProductRailControllers(sections);
      _pruneInlineReelKeys(sections);

      if (!mounted) return;
      setState(() {
        _sections = sections;
        _videoLookupByUrl = <String, VideoModel>{
          for (final video in allVideos) video.url: video,
        };
        _isLoading = false;
      });
      _scheduleInlineReelVisibilityCheck();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load feed';
        _isLoading = false;
      });
    }
  }

  List<List<ProductModel>> _chunkProducts(
      List<ProductModel> products, int chunkSize) {
    final chunks = <List<ProductModel>>[];
    for (var i = 0; i < products.length; i += chunkSize) {
      final end = math.min(i + chunkSize, products.length);
      chunks.add(products.sublist(i, end));
    }
    return chunks;
  }

  List<_HomeSection> _buildRandomizedSections({
    required List<List<ProductModel>> productRails,
    required List<PostModel> posts,
    required List<ReelModel> reels,
    required List<VideoModel> videos,
  }) {
    final rails = List<List<ProductModel>>.from(productRails);
    final postQueue = List<PostModel>.from(posts);
    final reelQueue = List<ReelModel>.from(reels);
    final videoQueue = List<VideoModel>.from(videos);
    final sections = <_HomeSection>[];
    final random = math.Random();

    while (rails.isNotEmpty ||
        postQueue.isNotEmpty ||
        reelQueue.isNotEmpty ||
        videoQueue.isNotEmpty) {
      final availableTypes = <_HomeSectionType>[
        if (rails.isNotEmpty) _HomeSectionType.productRail,
        if (postQueue.isNotEmpty) _HomeSectionType.post,
        if (reelQueue.isNotEmpty) _HomeSectionType.reel,
        if (videoQueue.isNotEmpty) _HomeSectionType.video,
      ];

      if (availableTypes.length > 1 && sections.isNotEmpty) {
        final trailingCount = _trailingTypeCount(sections, sections.last.type);
        if (trailingCount >= 2) {
          availableTypes.remove(sections.last.type);
        }
      }

      final selectedType =
          availableTypes[random.nextInt(availableTypes.length)];

      switch (selectedType) {
        case _HomeSectionType.productRail:
          sections
              .add(_HomeSection(type: selectedType, data: rails.removeAt(0)));
          break;
        case _HomeSectionType.post:
          sections.add(
              _HomeSection(type: selectedType, data: postQueue.removeAt(0)));
          break;
        case _HomeSectionType.reel:
          sections.add(
              _HomeSection(type: selectedType, data: reelQueue.removeAt(0)));
          break;
        case _HomeSectionType.video:
          sections.add(
              _HomeSection(type: selectedType, data: videoQueue.removeAt(0)));
          break;
      }
    }

    return sections;
  }

  int _trailingTypeCount(List<_HomeSection> sections, _HomeSectionType type) {
    var count = 0;
    for (var i = sections.length - 1; i >= 0; i--) {
      if (sections[i].type != type) {
        break;
      }
      count++;
    }
    return count;
  }

  DateTime _parseDate(String value) {
    try {
      return DateTime.parse(value).toLocal();
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  String _formatFeedTime(String value) {
    final createdAt = _parseDate(value);
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      final seconds = math.max(1, difference.inSeconds);
      return '$seconds ${seconds == 1 ? 'second' : 'seconds'} ago';
    }
    if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    }
    if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    }
    if (difference.inDays < 30) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    }
    if (difference.inDays < 365) {
      final months = difference.inDays ~/ 30;
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    }

    const monthNames = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${monthNames[createdAt.month - 1]} ${createdAt.day}, ${createdAt.year}';
  }

  int _cartQuantityForProduct(String productId, List<CartItemModel> cartItems) {
    for (final item in cartItems) {
      if (item.product.id == productId) {
        return item.quantity;
      }
    }
    return 0;
  }

  void _showCartToast(
    String message, {
    required Color backgroundColor,
  }) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleAddToCart(ProductModel product) async {
    if (_updatingCartProductIds.contains(product.id)) {
      return;
    }

    final cartItems = context.read<CartProvider>().cart.items;
    final inCartQuantity = _effectiveCartQuantity(product, cartItems);
    final remainingStock = product.stockQuantity > 0
        ? math.max(product.stockQuantity - inCartQuantity, 0)
        : 0;
    if (remainingStock <= 0) {
      _showCartToast(
        'Max stock already in cart',
        backgroundColor: AppColors.destructive,
      );
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

    if (added) {
      final cart = context.read<CartProvider>().cart;
      _showCartToast(
        'Added to cart. Total: \$${cart.total.toStringAsFixed(2)}',
        backgroundColor: AppColors.successGreen,
      );
      return;
    }

    _showCartToast(
      'Failed to add to cart',
      backgroundColor: AppColors.destructive,
    );
  }

  int _effectiveCartQuantity(
    ProductModel product,
    List<CartItemModel> cartItems,
  ) {
    return _pendingCartQuantities[product.id] ??
        _cartQuantityForProduct(product.id, cartItems);
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

  Future<void> _handleProductQuantityChange(
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

    if (!updated) {
      _showCartToast(
        'Failed to update cart',
        backgroundColor: AppColors.destructive,
      );
    }
  }

  Widget _buildCartActionButton(
    ProductModel product,
    List<CartItemModel> cartItems,
  ) {
    final inCartQuantity = _effectiveCartQuantity(product, cartItems);
    final remainingStock = product.stockQuantity > 0
        ? math.max(product.stockQuantity - inCartQuantity, 0)
        : 0;
    final canAddToCart = remainingStock > 0;
    final canIncrease = remainingStock > 0;
    final isUpdating = _updatingCartProductIds.contains(product.id);

    if (inCartQuantity < 1) {
      return Material(
        color: canAddToCart ? Colors.white : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(999),
        elevation: 2,
        child: InkWell(
          onTap: canAddToCart && !isUpdating
              ? () => _handleAddToCart(product)
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
            _buildQuantityIconButton(
              icon: Icons.remove_circle_outline,
              onTap: isUpdating
                  ? null
                  : () => _handleProductQuantityChange(
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
            _buildQuantityIconButton(
              icon: Icons.add_circle_outline,
              onTap: !isUpdating && canIncrease
                  ? () => _handleProductQuantityChange(
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

  Widget _buildQuantityIconButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: Icon(
          icon,
          size: 21,
          color: enabled ? Colors.black87 : Colors.grey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = context.watch<CartProvider>().cart.items;

    if (_isLoading) {
      return _buildLoadingFeed();
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchFeed,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_sections.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchFeed,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Icon(Icons.dynamic_feed_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Center(child: Text('No recommended content yet')),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;
        final pagePadding = isCompact ? 12.0 : 20.0;
        final activeScope = ActiveBranchScope.maybeOf(context);
        final isHomeTabActive = (activeScope?.currentIndex ?? 0) == 0 &&
            (activeScope?.currentPath ?? '/') == '/';
        final cacheExtent = defaultTargetPlatform == TargetPlatform.android
            ? _mobileListCacheExtent
            : _desktopListCacheExtent;

        return RefreshIndicator(
          onRefresh: _fetchFeed,
          child: ListView.builder(
            key: _feedViewportKey,
            controller: _feedScrollController,
            padding:
                EdgeInsets.symmetric(vertical: 16, horizontal: pagePadding),
            cacheExtent: cacheExtent,
            itemCount: _sections.length,
            itemBuilder: (context, index) {
              final section = _sections[index];
              final isInlineReelActive =
                  isHomeTabActive && _activeInlineReelSectionIndex == index;
              switch (section.type) {
                case _HomeSectionType.productRail:
                  return _buildProductRail(
                    index,
                    section.data as List<ProductModel>,
                    constraints.maxWidth,
                    cartItems,
                  );
                case _HomeSectionType.post:
                  return KeyedSubtree(
                    key: _sectionContainsInlineReel(section)
                        ? _getInlineReelSectionKey(index)
                        : null,
                    child: _buildPostCard(
                      section.data as PostModel,
                      constraints.maxWidth,
                      isInlineReelActive,
                    ),
                  );
                case _HomeSectionType.reel:
                  return KeyedSubtree(
                    key: _getInlineReelSectionKey(index),
                    child: _buildReelCard(
                      section.data as ReelModel,
                      constraints.maxWidth,
                      isInlineReelActive,
                    ),
                  );
                case _HomeSectionType.video:
                  return _buildVideoCard(
                    section.data as VideoModel,
                    constraints.maxWidth,
                  );
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildLoadingFeed() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: LinearProgressIndicator(minHeight: 3),
        ),
        _buildLoadingCard(aspectRatio: 1),
        _buildLoadingCard(aspectRatio: 4 / 5),
        _buildLoadingCard(aspectRatio: 16 / 9),
      ],
    );
  }

  Widget _buildLoadingCard({required double aspectRatio}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final placeholderColor =
        isDark ? AppColors.darkMuted : AppColors.lightMuted;

    Widget block({
      required double height,
      double? width,
      EdgeInsetsGeometry margin = EdgeInsets.zero,
    }) {
      return Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          color: placeholderColor,
          borderRadius: BorderRadius.circular(12),
        ),
      );
    }

    return _buildSectionShell(
      maxWidth: _pageMaxWidth,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: placeholderColor,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      block(height: 12, width: 120),
                      block(
                        height: 10,
                        width: 84,
                        margin: const EdgeInsets.only(top: 6),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            AspectRatio(
              aspectRatio: aspectRatio,
              child: Container(color: placeholderColor),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  block(height: 12, width: double.infinity),
                  block(
                    height: 12,
                    width: 200,
                    margin: const EdgeInsets.only(top: 8),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionShell({
    required Widget child,
    required double maxWidth,
  }) {
    final constrainedWidth = math.min(maxWidth, _pageMaxWidth);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: constrainedWidth,
          child: child,
        ),
      ),
    );
  }

  Widget _buildProductRail(
    int sectionIndex,
    List<ProductModel> products,
    double viewportWidth,
    List<CartItemModel> cartItems,
  ) {
    final railWidth = math.min(
      _mediaCardMaxWidth,
      math.min(viewportWidth, _pageMaxWidth),
    );
    final controller = _getProductRailController(sectionIndex);
    final canScrollLeft = _canScrollRailLeft.contains(sectionIndex);
    final canScrollRight = _canScrollRailRight.contains(sectionIndex);

    return _buildSectionShell(
      maxWidth: viewportWidth,
      child: Align(
        alignment: Alignment.center,
        child: SizedBox(
          width: railWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 2, bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Products',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ),
                    _buildRailArrowButton(
                      icon: Icons.chevron_left_rounded,
                      isEnabled: canScrollLeft,
                      onPressed: () => _scrollProductRail(sectionIndex, false),
                    ),
                    const SizedBox(width: 6),
                    _buildRailArrowButton(
                      icon: Icons.chevron_right_rounded,
                      isEnabled: canScrollRight,
                      onPressed: () => _scrollProductRail(sectionIndex, true),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: _productRailHeight,
                child: ListView.separated(
                  controller: controller,
                  scrollDirection: Axis.horizontal,
                  cacheExtent: defaultTargetPlatform == TargetPlatform.android
                      ? _mobileListCacheExtent
                      : _desktopListCacheExtent,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    return _buildProductTile(products[index], cartItems);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRailArrowButton({
    required IconData icon,
    required bool isEnabled,
    required VoidCallback onPressed,
  }) {
    final surfaceColor = Theme.of(context).cardColor;

    return Material(
      color: isEnabled ? surfaceColor : surfaceColor.withAlpha(140),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: isEnabled ? onPressed : null,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            icon,
            size: 22,
            color: isEnabled ? null : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildProductTile(
      ProductModel product, List<CartItemModel> cartItems) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: _productRailCardWidth,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/shop/${product.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color:
                          isDark ? AppColors.darkMuted : AppColors.lightMuted,
                      child: product.images.isNotEmpty
                          ? _buildCachedImage(
                              product.images.first,
                              fit: BoxFit.cover,
                              errorWidget: const Icon(Icons.shopping_bag),
                            )
                          : const Icon(Icons.shopping_bag),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: _buildCartActionButton(product, cartItems),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.0,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        product.brandName ?? product.sellerName,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                              height: 1.0,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      _buildProductPrice(product),
                      const SizedBox(height: 6),
                      ProductCardSocialPreview(
                        productId: product.id,
                        maxAvatars: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductPrice(ProductModel product) {
    final compareAtPrice = product.compareAtPrice;
    final hasDiscount =
        compareAtPrice != null && compareAtPrice > product.price;

    final currentPriceText = '\$${product.price.toStringAsFixed(2)}';
    final currentPriceStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.electricBlue,
          height: 1.0,
        );

    if (!hasDiscount) {
      return Row(
        children: [
          Expanded(
            child: Text(
              currentPriceText,
              style: currentPriceStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    final percentOff =
        (((compareAtPrice - product.price) / compareAtPrice) * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                currentPriceText,
                style: currentPriceStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.successGreen.withAlpha(24),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$percentOff% OFF',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.successGreen,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '\$${compareAtPrice.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                decoration: TextDecoration.lineThrough,
              ),
        ),
      ],
    );
  }

  Widget _buildPostCard(
    PostModel post,
    double viewportWidth,
    bool isInlineReelActive,
  ) {
    final linkedVideo = _linkedVideoForPost(post);
    final isVideoPost = post.mediaType == 'video';

    return _buildMediaCard(
      maxWidth: _mediaCardMaxWidth,
      viewportWidth: viewportWidth,
      onTap: isVideoPost && linkedVideo != null
          ? () => context.push('/videos/${linkedVideo.id}')
          : null,
      onHeaderTap: () => context.push('/profile/${post.userId}'),
      media: _buildPostMedia(
        post,
        isInlineReelActive,
        linkedVideo: linkedVideo,
      ),
      creatorName: post.authorName,
      creatorAvatar: post.authorAvatar,
      createdAt: post.createdAt,
      bodyText: isVideoPost
          ? _postVideoTitle(post, linkedVideo)
          : post.caption,
      bodyTextPosition: isVideoPost
          ? _MediaCardBodyTextPosition.aboveMedia
          : _MediaCardBodyTextPosition.belowMedia,
    );
  }

  Widget _buildVideoCard(VideoModel video, double viewportWidth) {
    return _buildMediaCard(
      maxWidth: _mediaCardMaxWidth,
      viewportWidth: viewportWidth,
      onTap: () => context.push('/videos/${video.id}'),
      onHeaderTap: () => context.push('/profile/${video.creatorId}'),
      media: _buildFramedMedia(
        imageUrl: video.thumbnail,
        aspectRatio: 16 / 9,
        playIcon: true,
        durationBadge: _HomeVideoDurationBadge(
          videoUrl: video.url,
          initialDurationSeconds: video.duration,
        ),
      ),
      creatorName: video.creatorName,
      creatorAvatar: video.creatorAvatar,
      createdAt: video.createdAt,
      bodyText: video.title,
      bodyTextPosition: _MediaCardBodyTextPosition.aboveMedia,
    );
  }

  Widget _buildReelCard(
    ReelModel reel,
    double viewportWidth,
    bool isInlineReelActive,
  ) {
    return _buildMediaCard(
      maxWidth: _mediaCardMaxWidth,
      viewportWidth: viewportWidth,
      onTap: () => context.push('/reels?id=${reel.id}'),
      onHeaderTap: () => context.push('/profile/${reel.creatorId}'),
      media: _InlineReelMedia(
        videoUrl: reel.url,
        thumbnailUrl: reel.thumbnail,
        isActive: isInlineReelActive,
        isMuted: _areInlineReelsMuted,
        onMuteChanged: _handleInlineReelMuteChanged,
      ),
      creatorName: reel.creatorName,
      creatorAvatar: reel.creatorAvatar,
      createdAt: reel.createdAt,
      bodyText: reel.caption,
    );
  }

  Widget _buildPostMedia(
    PostModel post,
    bool isInlineReelActive, {
    VideoModel? linkedVideo,
  }) {
    if (post.mediaType == 'reel') {
      return _InlineReelMedia(
        videoUrl: post.mediaUrl,
        thumbnailUrl: post.thumbnailUrl ?? post.mediaUrl,
        isActive: isInlineReelActive,
        isMuted: _areInlineReelsMuted,
        onMuteChanged: _handleInlineReelMuteChanged,
      );
    }

    final aspectRatio = post.mediaType == 'video' ? 16 / 9 : 4 / 5;

    return _buildFramedMedia(
      imageUrl: post.thumbnailUrl ?? post.mediaUrl,
      aspectRatio: aspectRatio,
      playIcon: post.mediaType == 'video',
      durationBadge: post.mediaType == 'video'
          ? _HomeVideoDurationBadge(
              videoUrl: post.mediaUrl,
              initialDurationSeconds: linkedVideo?.duration ?? 0,
            )
          : null,
    );
  }

  Widget _buildFramedMedia({
    required String imageUrl,
    required double aspectRatio,
    bool playIcon = false,
    Widget? durationBadge,
  }) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildCachedImage(
            imageUrl,
            fit: BoxFit.cover,
            errorWidget: Container(
              color: Colors.grey[200],
              child: const Icon(Icons.broken_image_outlined, size: 40),
            ),
          ),
          if (playIcon)
            Center(
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(140),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
          if (durationBadge != null)
            Positioned(
              right: 12,
              bottom: 12,
              child: durationBadge,
            ),
        ],
      ),
    );
  }

  Widget _buildMediaCard({
    required double maxWidth,
    required double viewportWidth,
    required Widget media,
    required String creatorName,
    required String createdAt,
    String? creatorAvatar,
    String? bodyText,
    VoidCallback? onTap,
    VoidCallback? onHeaderTap,
    _MediaCardBodyTextPosition bodyTextPosition =
        _MediaCardBodyTextPosition.belowMedia,
  }) {
    final trimmedBodyText = bodyText?.trim();
    final hasBodyText = trimmedBodyText != null && trimmedBodyText.isNotEmpty;

    return _buildSectionShell(
      maxWidth: viewportWidth,
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: math.min(maxWidth, viewportWidth),
          ),
          child: Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                  child: InkWell(
                    onTap: onHeaderTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 2,
                        horizontal: 2,
                      ),
                      child: Row(
                        children: [
                          _buildAvatar(creatorName, creatorAvatar),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  creatorName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatFeedTime(createdAt),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (onTap != null)
                  InkWell(
                    onTap: onTap,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (bodyTextPosition ==
                                _MediaCardBodyTextPosition.aboveMedia &&
                            hasBodyText)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                            child: Text(
                              trimmedBodyText,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        media,
                        if (bodyTextPosition ==
                                _MediaCardBodyTextPosition.belowMedia &&
                            hasBodyText)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                            child: Text(
                              trimmedBodyText,
                              style: Theme.of(context).textTheme.bodyMedium,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  )
                else ...[
                  if (bodyTextPosition ==
                          _MediaCardBodyTextPosition.aboveMedia &&
                      hasBodyText)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      child: Text(
                        trimmedBodyText,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  media,
                  if (bodyTextPosition ==
                          _MediaCardBodyTextPosition.belowMedia &&
                      hasBodyText)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: Text(
                        trimmedBodyText,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String name, String? avatarUrl) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.electricBlue,
      backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
          ? CachedNetworkImageProvider(UrlHelper.getPlatformUrl(avatarUrl))
          : null,
      child: avatarUrl == null || avatarUrl.isEmpty
          ? Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
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

  void _handleInlineReelMuteChanged(bool isMuted) {
    if (_areInlineReelsMuted == isMuted || !mounted) {
      return;
    }

    setState(() {
      _areInlineReelsMuted = isMuted;
    });
  }

  VideoModel? _linkedVideoForPost(PostModel post) {
    if (post.mediaType != 'video') {
      return null;
    }
    return _videoLookupByUrl[post.mediaUrl];
  }

  String _postVideoTitle(PostModel post, VideoModel? linkedVideo) {
    final linkedTitle = linkedVideo?.title.trim() ?? '';
    if (linkedTitle.isNotEmpty) {
      return linkedTitle;
    }
    final caption = post.caption.trim();
    if (caption.isNotEmpty) {
      return caption;
    }
    return 'Untitled Video';
  }
}

enum _MediaCardBodyTextPosition {
  aboveMedia,
  belowMedia,
}

class _HomeDurationBadge extends StatelessWidget {
  const _HomeDurationBadge({required this.durationLabel});

  final String durationLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        durationLabel,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HomeVideoDurationBadge extends StatefulWidget {
  const _HomeVideoDurationBadge({
    required this.videoUrl,
    required this.initialDurationSeconds,
  });

  final String videoUrl;
  final int initialDurationSeconds;

  @override
  State<_HomeVideoDurationBadge> createState() => _HomeVideoDurationBadgeState();
}

class _HomeVideoDurationBadgeState extends State<_HomeVideoDurationBadge> {
  late int _durationSeconds;

  @override
  void initState() {
    super.initState();
    _durationSeconds =
        _homeVideoDurationCache[widget.videoUrl] ?? widget.initialDurationSeconds;
    _ensureDuration();
  }

  @override
  void didUpdateWidget(covariant _HomeVideoDurationBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl ||
        oldWidget.initialDurationSeconds != widget.initialDurationSeconds) {
      _durationSeconds = _homeVideoDurationCache[widget.videoUrl] ??
          widget.initialDurationSeconds;
      _ensureDuration();
    }
  }

  Future<void> _ensureDuration() async {
    if (_durationSeconds > 0) {
      return;
    }

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(UrlHelper.getPlayableVideoUrl(widget.videoUrl)),
    );

    try {
      await controller.initialize();
      final duration = controller.value.duration.inSeconds;
      if (duration <= 0 || !mounted) {
        return;
      }
      _homeVideoDurationCache[widget.videoUrl] = duration;
      setState(() {
        _durationSeconds = duration;
      });
    } catch (_) {
      // Leave the existing label in place when metadata can't be resolved.
    } finally {
      await controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _HomeDurationBadge(
      durationLabel: _formatVideoDuration(_durationSeconds),
    );
  }
}

class _InlineReelMedia extends StatefulWidget {
  const _InlineReelMedia({
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.isActive,
    required this.isMuted,
    required this.onMuteChanged,
  });

  final String videoUrl;
  final String thumbnailUrl;
  final bool isActive;
  final bool isMuted;
  final ValueChanged<bool> onMuteChanged;

  @override
  State<_InlineReelMedia> createState() => _InlineReelMediaState();
}

class _InlineReelControllerCacheEntry {
  const _InlineReelControllerCacheEntry({
    required this.controller,
    required this.cachedAt,
  });

  final VideoPlayerController controller;
  final DateTime cachedAt;
}

class _InlineReelControllerCache {
  static const int _maxEntries = 3;
  static final Map<String, _InlineReelControllerCacheEntry> _entries = {};

  static VideoPlayerController? take(String videoUrl) {
    final entry = _entries.remove(videoUrl);
    return entry?.controller;
  }

  static void store(String videoUrl, VideoPlayerController controller) {
    _entries.remove(videoUrl)?.controller.dispose();
    _entries[videoUrl] = _InlineReelControllerCacheEntry(
      controller: controller,
      cachedAt: DateTime.now(),
    );
    _evictOverflow();
  }

  static void _evictOverflow() {
    while (_entries.length > _maxEntries) {
      final oldestEntry = _entries.entries.reduce(
        (current, next) =>
            current.value.cachedAt.isBefore(next.value.cachedAt)
                ? current
                : next,
      );
      _entries.remove(oldestEntry.key)?.controller.dispose();
    }
  }
}

class _InlineReelMediaState extends State<_InlineReelMedia>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _initializing = false;
  bool _isAppActive = true;

  bool get _shouldCacheController =>
      !kIsWeb &&
      defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.isActive) {
      _ensureController();
    }
  }

  @override
  void didUpdateWidget(covariant _InlineReelMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeController(cacheForReuse: _shouldCacheController);
    }
    if (widget.isActive && _isAppActive) {
      if (_controller == null) {
        _ensureController();
      } else {
        _controller!.setVolume(widget.isMuted ? 0 : 1);
        _controller!.play();
      }
    } else {
      _controller?.pause();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isAppActive = state == AppLifecycleState.resumed;
    _isAppActive = isAppActive;
    if (!isAppActive) {
      _controller?.pause();
      return;
    }
    if (widget.isActive) {
      if (_controller == null) {
        _ensureController();
      } else {
        _controller!.setVolume(widget.isMuted ? 0 : 1);
        _controller!.play();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeController(cacheForReuse: _shouldCacheController);
    super.dispose();
  }

  void _disposeController({bool cacheForReuse = false}) {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      if (cacheForReuse && controller.value.isInitialized) {
        controller.pause();
        _InlineReelControllerCache.store(widget.videoUrl, controller);
      } else {
        controller.dispose();
      }
    }
  }

  Future<void> _ensureController() async {
    if (_controller != null || _initializing) {
      return;
    }

    _initializing = true;
    final cachedController = _InlineReelControllerCache.take(widget.videoUrl);
    final controller =
        cachedController ??
        VideoPlayerController.networkUrl(
          Uri.parse(UrlHelper.getPlayableVideoUrl(widget.videoUrl)),
        );

    try {
      if (!controller.value.isInitialized) {
        await controller.initialize();
      }
      await controller.setLooping(true);
      await controller.setVolume(widget.isMuted ? 0 : 1);
      if (widget.isActive && _isAppActive) {
        await controller.play();
      } else {
        await controller.pause();
      }
      if (!mounted) {
        _InlineReelControllerCache.store(widget.videoUrl, controller);
        return;
      }
      setState(() {
        _controller = controller;
      });
    } catch (_) {
      await controller.dispose();
    } finally {
      _initializing = false;
    }
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    final nextMuted = !widget.isMuted;
    await controller.setVolume(nextMuted ? 0 : 1);
    if (!mounted) {
      return;
    }
    widget.onMuteChanged(nextMuted);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final isReady = controller != null && controller.value.isInitialized;

    return AspectRatio(
      aspectRatio: 9 / 14,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isReady)
            RepaintBoundary(
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            )
          else
            _InlineReelThumbnail(thumbnailUrl: widget.thumbnailUrl),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.06),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.26),
                  ],
                ),
              ),
            ),
          ),
          if (!isReady)
            const Center(
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: isReady ? _toggleMute : null,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    widget.isMuted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineReelThumbnail extends StatelessWidget {
  const _InlineReelThumbnail({required this.thumbnailUrl});

  final String thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = UrlHelper.getPlatformUrl(thumbnailUrl);

    return CachedNetworkImage(
      imageUrl: resolvedUrl,
      cacheKey: resolvedUrl,
      fit: BoxFit.cover,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      useOldImageOnUrlChange: true,
      errorWidget: (_, __, ___) => Container(
        color: Colors.grey[200],
        child: const Icon(Icons.play_circle_outline, size: 40),
      ),
    );
  }
}

String _formatVideoDuration(int totalSeconds) {
  final duration = Duration(seconds: totalSeconds.clamp(0, 359999));
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

  if (hours > 0) {
    return '$hours:$minutes:$seconds';
  }

  return '${duration.inMinutes}:$seconds';
}

enum _HomeSectionType {
  productRail,
  post,
  reel,
  video,
}

class _HomeSection {
  const _HomeSection({
    required this.type,
    required this.data,
  });

  final _HomeSectionType type;
  final Object data;
}
