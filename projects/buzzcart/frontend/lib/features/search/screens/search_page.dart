import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/url_helper.dart';
import '../../products/widgets/product_card_social_preview.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
{
  static const double _gridSpacing = 12;
  static const double _minTileWidth = 170;
  static const double _maxTileWidth = 260;
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  Map<String, List<dynamic>> _results = {
    'products': [],
    'videos': [],
    'reels': [],
    'users': [],
  };
  final List<String> _filterOrder = const [
    'all',
    'users',
    'products',
    'videos',
    'reels',
  ];
  static const int _minimumSearchLength = 2;
  final Set<String> _selectedFilters = {'all'};
  bool _loading = false;
  bool _searched = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    // Cancel previous timer
    _debounce?.cancel();
    final trimmedQuery = query.trim();

    // Search starts from the second character.
    if (trimmedQuery.isEmpty) {
      _clearSearch();
      return;
    }

    if (trimmedQuery.length < _minimumSearchLength) {
      setState(() {
        _results = {
          'products': [],
          'videos': [],
          'reels': [],
          'users': [],
        };
        _searched = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 250), () {
      _performSearch();
    });

    setState(() {}); // Update UI for clear button
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.length < _minimumSearchLength) return;

    setState(() {
      _loading = true;
      _searched = true;
    });

    try {
      final data = await _api.search(query);
      setState(() {
        _results = {
          'products': data['products'] ?? [],
          'videos': data['videos'] ?? [],
          'reels': data['reels'] ?? [],
          'users': data['users'] ?? [],
        };
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Search failed')),
        );
      }
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _results = {
        'products': [],
        'videos': [],
        'reels': [],
        'users': [],
      };
      _searched = false;
      _selectedFilters
        ..clear()
        ..add('all');
    });
  }

  int get _totalResults =>
      _results.values.fold(0, (sum, list) => sum + list.length);

  int _countForFilter(String filter) {
    switch (filter) {
      case 'users':
        return _results['users']!.length;
      case 'products':
        return _results['products']!.length;
      case 'videos':
        return _results['videos']!.length;
      case 'reels':
        return _results['reels']!.length;
      case 'all':
      default:
        return _totalResults;
    }
  }

  String _labelForFilter(String filter) {
    switch (filter) {
      case 'users':
        return 'Users';
      case 'products':
        return 'Products';
      case 'videos':
        return 'Videos';
      case 'reels':
        return 'Shorts';
      case 'all':
      default:
        return 'All';
    }
  }

  void _toggleFilter(String filter) {
    setState(() {
      if (filter == 'all') {
        _selectedFilters
          ..clear()
          ..add('all');
        return;
      }

      _selectedFilters.remove('all');
      if (_selectedFilters.contains(filter)) {
        _selectedFilters.remove(filter);
      } else {
        _selectedFilters.add(filter);
      }

      if (_selectedFilters.isEmpty) {
        _selectedFilters.add('all');
      }
    });
  }

  int _calculateProductGridColumns(double availableWidth) {
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

  Widget _buildProductResultsGrid(
    List<dynamic> products, {
    bool shrinkWrap = false,
    int? limit,
  }) {
    final visibleProducts =
        limit == null ? products : products.take(limit).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _calculateProductGridColumns(constraints.maxWidth);
        return GridView.builder(
          shrinkWrap: shrinkWrap,
          physics: shrinkWrap
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics(),
          padding: shrinkWrap ? EdgeInsets.zero : const EdgeInsets.fromLTRB(16, 0, 16, 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: 0.64,
            crossAxisSpacing: _gridSpacing,
            mainAxisSpacing: _gridSpacing,
          ),
          itemCount: visibleProducts.length,
          itemBuilder: (context, index) {
            final product = visibleProducts[index];
            return _ProductCard(product: product);
          },
        );
      },
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: _filterOrder.map((filter) {
          final selected = _selectedFilters.contains(filter);
          final count = _countForFilter(filter);
          final label = _labelForFilter(filter);

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: filter == _filterOrder.last ? 0 : 6,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => _toggleFilter(filter),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.electricBlue
                        : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected
                          ? AppColors.electricBlue
                          : Colors.white.withOpacity(0.10),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$label ($count)',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : Colors.white70,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSelectedResults() {
    if (_selectedFilters.contains('all')) {
      return _buildAllTab();
    }

    final activeFilters =
        _filterOrder.where((filter) => _selectedFilters.contains(filter)).toList();
    if (activeFilters.length == 1) {
      switch (activeFilters.first) {
        case 'users':
          return MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _results['users']!.length,
              itemBuilder: (context, index) {
                final user = _results['users']![index];
                return _UserCard(user: user);
              },
            ),
          );
        case 'products':
          return MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: _buildProductResultsGrid(_results['products']!),
          );
        case 'videos':
          return MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _results['videos']!.length,
              itemBuilder: (context, index) {
                final video = _results['videos']![index];
                return _VideoCard(video: video);
              },
            ),
          );
        case 'reels':
          return MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 9 / 16,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _results['reels']!.length,
              itemBuilder: (context, index) {
                final reel = _results['reels']![index];
                return InkWell(
                  onTap: () => context.push('/reels'),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          UrlHelper.getPlatformUrl(reel['thumbnail']),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.videocam),
                          ),
                        ),
                      ),
                      const Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
      }
    }

    final sections = <Widget>[];

    void addSection({
      required String filter,
      required String title,
      required Widget content,
    }) {
      if (!_selectedFilters.contains(filter) || _countForFilter(filter) == 0) {
        return;
      }

      if (sections.isNotEmpty) {
        sections.add(const SizedBox(height: 24));
      }

      sections.add(
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );
      sections.add(const SizedBox(height: 12));
      sections.add(content);
    }

    addSection(
      filter: 'users',
      title: 'Users',
      content: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _results['users']!.length,
        itemBuilder: (context, index) {
          final user = _results['users']![index];
          return _UserCard(user: user);
        },
      ),
    );
    addSection(
      filter: 'products',
      title: 'Products',
      content: _buildProductResultsGrid(
        _results['products']!,
        shrinkWrap: true,
      ),
    );
    addSection(
      filter: 'videos',
      title: 'Videos',
      content: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _results['videos']!.length,
        itemBuilder: (context, index) {
          final video = _results['videos']![index];
          return _VideoCard(video: video);
        },
      ),
    );
    addSection(
      filter: 'reels',
      title: 'Shorts',
      content: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 9 / 16,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _results['reels']!.length,
        itemBuilder: (context, index) {
          final reel = _results['reels']![index];
          return InkWell(
            onTap: () => context.push('/reels'),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    UrlHelper.getPlatformUrl(reel['thumbnail']),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.videocam),
                    ),
                  ),
                ),
                const Center(
                  child: Icon(
                    Icons.play_circle_fill,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: sections,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showPageAppBar = MediaQuery.of(context).size.width >= 1024;
    const contentTopPadding = 0.0;

    Widget buildSearchField({EdgeInsetsGeometry padding = EdgeInsets.zero}) {
      return Padding(
        padding: padding,
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search product names, videos, people...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearSearch,
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onSubmitted: (_) => _performSearch(),
          onChanged: _onSearchChanged,
        ),
      );
    }

    return Scaffold(
      appBar: showPageAppBar
          ? AppBar(
              title: const Text('Search'),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: buildSearchField(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                ),
              ),
            )
          : null,
      body: _loading
          ? Column(
              children: [
                if (!showPageAppBar)
                  buildSearchField(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      contentTopPadding,
                      16,
                      12,
                    ),
                  ),
                const Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                if (!showPageAppBar)
                  buildSearchField(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      contentTopPadding,
                      16,
                      12,
                    ),
                  ),
                if (!_searched)
                  const Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'Search by product name, video caption, or person name',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else if (_totalResults == 0)
                  const Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off,
                                size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No results found',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Try a different search term',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else ...[
                  _buildFilterChips(),
                  Expanded(
                    child: _buildSelectedResults(),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildAllTab() {
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
        if (_results['users']!.isNotEmpty)
          const Text(
            'Users',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        if (_results['users']!.isNotEmpty) const SizedBox(height: 12),
        if (_results['users']!.isNotEmpty)
          ...(_results['users']!.take(3).map((user) => _UserCard(user: user))),
        if (_results['users']!.isNotEmpty) const SizedBox(height: 24),
        if (_results['products']!.isNotEmpty)
          const Text(
            'Products',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        if (_results['products']!.isNotEmpty) const SizedBox(height: 12),
        if (_results['products']!.isNotEmpty)
          _buildProductResultsGrid(
            _results['products']!,
            shrinkWrap: true,
            limit: 4,
          ),
        if (_results['products']!.isNotEmpty) const SizedBox(height: 24),
        if (_results['videos']!.isNotEmpty)
          const Text(
            'Videos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        if (_results['videos']!.isNotEmpty) const SizedBox(height: 12),
        if (_results['videos']!.isNotEmpty)
          ...(_results['videos']!
              .take(3)
              .map((video) => _VideoCard(video: video))),
        if (_results['videos']!.isNotEmpty &&
            _results['reels']!.isNotEmpty)
          const SizedBox(height: 24),
        if (_results['reels']!.isNotEmpty)
          const Text(
            'Shorts',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        if (_results['reels']!.isNotEmpty) const SizedBox(height: 12),
        if (_results['reels']!.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 9 / 16,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _results['reels']!.length.clamp(0, 6),
            itemBuilder: (context, index) {
              final reel = _results['reels']![index];
              return InkWell(
                onTap: () => context.push('/reels'),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        UrlHelper.getPlatformUrl(reel['thumbnail']),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.videocam),
                        ),
                      ),
                    ),
                    const Center(
                      child: Icon(
                        Icons.play_circle_fill,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;

  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => context.push('/profile/${user['id']}'),
        leading: CircleAvatar(
          backgroundImage:
              user['avatar'] != null && user['avatar'].toString().isNotEmpty
                  ? NetworkImage(UrlHelper.getPlatformUrl(user['avatar']))
                  : null,
          child: user['avatar'] == null || user['avatar'].toString().isEmpty
              ? Text((user['name'] ?? 'U')[0].toUpperCase())
              : null,
        ),
        title: Text(user['name'] ?? ''),
        subtitle: Text(
          user['bio'] ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _ProductCard extends StatefulWidget {
  final Map<String, dynamic> product;

  const _ProductCard({required this.product});

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  int? _pendingQuantity;
  bool _isUpdating = false;

  int _stockQuantity() => widget.product['stock_quantity'] as int? ?? 0;

  int _currentCartQuantity(List<dynamic> cartItems) {
    if (_pendingQuantity != null) {
      return _pendingQuantity!;
    }

    for (final item in cartItems) {
      if (item.product.id == widget.product['id']) {
        return item.quantity;
      }
    }
    return 0;
  }

  int _remainingStock(int inCartQuantity) {
    final stockQuantity = _stockQuantity();
    if (stockQuantity <= 0) {
      return 0;
    }
    final remaining = stockQuantity - inCartQuantity;
    return remaining > 0 ? remaining : 0;
  }

  Future<bool> _confirmRemove() async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove item?'),
          content: Text(
            'Remove ${widget.product['title'] ?? 'this item'} from your cart?',
          ),
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

  Future<void> _addToCart() async {
    if (_isUpdating) {
      return;
    }

    final cartProvider = context.read<CartProvider>();
    final currentQuantity = _currentCartQuantity(cartProvider.cart.items);
    final remainingStock = _remainingStock(currentQuantity);
    if (remainingStock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Max stock already in cart')),
      );
      return;
    }

    setState(() {
      _pendingQuantity = currentQuantity + 1;
      _isUpdating = true;
    });

    final added = await cartProvider.addToCart(
      widget.product['id'] as String,
      maxQuantity: remainingStock,
    );
    if (!mounted) return;

    setState(() {
      _pendingQuantity = added ? null : currentQuantity;
      _isUpdating = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(added ? 'Added to cart!' : 'Failed to add to cart'),
      ),
    );
  }

  Future<void> _changeQuantity(int targetQuantity) async {
    if (_isUpdating) {
      return;
    }

    final cartProvider = context.read<CartProvider>();
    final previousQuantity = _currentCartQuantity(cartProvider.cart.items);
    final maxQuantity = _stockQuantity() > 0 ? _stockQuantity() : null;

    if (targetQuantity <= 0) {
      final shouldRemove = await _confirmRemove();
      if (!shouldRemove) {
        return;
      }
    }

    setState(() {
      _pendingQuantity = targetQuantity > 0 ? targetQuantity : 0;
      _isUpdating = true;
    });

    final updated = targetQuantity <= 0
        ? await cartProvider.removeFromCart(widget.product['id'] as String)
        : await cartProvider.updateQuantity(
            widget.product['id'] as String,
            targetQuantity,
            maxQuantity: maxQuantity,
          );

    if (!mounted) return;

    setState(() {
      _pendingQuantity = updated ? null : previousQuantity;
      _isUpdating = false;
    });

    if (!updated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update cart')),
      );
    }
  }

  Widget _buildQuantityButton({
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

  Widget _buildCartControl(int inCartQuantity, int remainingStock) {
    final canAddToCart = remainingStock > 0;

    if (inCartQuantity < 1) {
      return Material(
        color: canAddToCart ? Colors.white : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(999),
        elevation: 2,
        child: InkWell(
          onTap: canAddToCart && !_isUpdating ? _addToCart : null,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: _isUpdating
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
            _buildQuantityButton(
              icon: Icons.remove_circle_outline,
              onTap: _isUpdating
                  ? null
                  : () => _changeQuantity(inCartQuantity - 1),
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
            _buildQuantityButton(
              icon: Icons.add_circle_outline,
              onTap: !_isUpdating && canAddToCart
                  ? () => _changeQuantity(inCartQuantity + 1)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final compareAtPrice = (product['compare_at_price'] as num?)?.toDouble();
    final images = (product['images'] as List?) ?? const [];
    final firstImage = images.isNotEmpty ? images.first?.toString() : null;
    final hasDiscount = compareAtPrice != null && compareAtPrice > price;
    final percentOff = hasDiscount
        ? (((compareAtPrice - price) / compareAtPrice) * 100).round()
        : 0;
    final brandName = (product['brand_name'] ?? product['seller_name'] ?? '')
        .toString()
        .trim();

    return Consumer<CartProvider>(
      builder: (context, cartProvider, _) {
        final inCartQuantity = _currentCartQuantity(cartProvider.cart.items);
        final remainingStock = _remainingStock(inCartQuantity);

        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/shop/${product['id']}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      firstImage == null || firstImage.isEmpty
                          ? Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.image),
                            )
                          : Image.network(
                              UrlHelper.getPlatformUrl(firstImage),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.image),
                              ),
                            ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: _buildCartControl(inCartQuantity, remainingStock),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['title'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
                      if (brandName.isNotEmpty)
                        Text(
                          brandName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      if (brandName.isNotEmpty) const SizedBox(height: 4),
                      if (!hasDiscount)
                        Text(
                          '\$${price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.electricBlue,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '\$${price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.electricBlue,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.successGreen.withAlpha(24),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '$percentOff% OFF',
                                    style: const TextStyle(
                                      color: AppColors.successGreen,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '\$${compareAtPrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                decoration: TextDecoration.lineThrough,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 6),
                      ProductCardSocialPreview(
                        productId: (product['id'] ?? '').toString(),
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
  }
}

class _VideoCard extends StatelessWidget {
  final Map<String, dynamic> video;

  const _VideoCard({required this.video});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/videos/${video['id']}'),
        child: Row(
          children: [
            Container(
              width: 120,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      UrlHelper.getPlatformUrl(video['thumbnail']),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.play_arrow),
                      ),
                    ),
                  ),
                  const Center(
                    child: Icon(Icons.play_circle_fill,
                        color: Colors.white, size: 32),
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
                      video['title'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${video['views'] ?? 0} views',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
