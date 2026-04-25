import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/models/models.dart';
import '../widgets/review_card.dart';
import '../widgets/write_review_dialog.dart';

class ReviewsPage extends StatefulWidget {
  final String productId;
  final String productTitle;

  const ReviewsPage({
    super.key,
    required this.productId,
    required this.productTitle,
  });

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  late final ApiService _api;
  List<ReviewModel> _reviews = [];
  List<ReviewModel> _filteredReviews = [];
  bool _loading = true;
  String? _error;
  String _sortBy = 'recent'; // recent, helpful, rating_high, rating_low
  bool _filterFollowing = false;
  bool _filterVerified = false;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiService>();
    _primeFromCache();
    _fetchReviews(showLoading: _reviews.isEmpty);
  }

  void _primeFromCache() {
    final cachedReviews = _api.peekCachedProductReviewsRanked(
      widget.productId,
      allowPartial: true,
    );
    if (cachedReviews == null || cachedReviews.isEmpty) {
      return;
    }
    _reviews = cachedReviews;
    _applyFiltersAndSort();
    _loading = false;
  }

  Future<void> _fetchReviews({
    bool showLoading = true,
    bool forceRefresh = false,
  }) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final reviews = await _api.getProductReviewsRanked(
        widget.productId,
        forceRefresh: forceRefresh,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _reviews = reviews;
        _applyFiltersAndSort();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      if (_reviews.isNotEmpty) {
        setState(() {
          _loading = false;
        });
        return;
      }
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _applyFiltersAndSort() {
    // Apply filters
    _filteredReviews = _reviews.where((review) {
      if (_filterFollowing && !review.isFollowing) return false;
      if (_filterVerified && !review.isVerifiedPurchase) return false;
      return true;
    }).toList();

    // Sort
    _sortReviews();
  }

  void _sortReviews() {
    switch (_sortBy) {
      case 'recent':
        _filteredReviews.sort(_compareRecentReviews);
        break;
      case 'helpful':
        _filteredReviews
            .sort((a, b) => b.helpfulCount.compareTo(a.helpfulCount));
        break;
      case 'rating_high':
        _filteredReviews.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'rating_low':
        _filteredReviews.sort((a, b) => a.rating.compareTo(b.rating));
        break;
    }
  }

  int _compareRecentReviews(ReviewModel a, ReviewModel b) {
    final currentUserId = context.read<AuthProvider>().user?.id;
    final ownReviewSort =
        (_isCurrentUserReview(b, currentUserId) ? 1 : 0)
            .compareTo(_isCurrentUserReview(a, currentUserId) ? 1 : 0);
    if (ownReviewSort != 0) {
      return ownReviewSort;
    }

    final connectionSort =
        (b.isFollowing ? 1 : 0).compareTo(a.isFollowing ? 1 : 0);
    if (connectionSort != 0) {
      return connectionSort;
    }

    return _reviewActivityTime(b).compareTo(_reviewActivityTime(a));
  }

  bool _isCurrentUserReview(ReviewModel review, String? currentUserId) {
    if (currentUserId == null || currentUserId.isEmpty) {
      return false;
    }
    return review.userId == currentUserId;
  }

  DateTime _reviewActivityTime(ReviewModel review) {
    final updatedAt = review.updatedAt.trim();
    if (updatedAt.isNotEmpty) {
      return _parseDate(updatedAt);
    }
    return _parseDate(review.createdAt);
  }

  DateTime _parseDate(String value) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  void _changeSortOrder(String newSort) {
    setState(() {
      _sortBy = newSort;
      _applyFiltersAndSort();
    });
  }

  void _toggleFilter(String filterType) {
    setState(() {
      if (filterType == 'following') {
        _filterFollowing = !_filterFollowing;
      } else if (filterType == 'verified') {
        _filterVerified = !_filterVerified;
      }
      _applyFiltersAndSort();
    });
  }

  Future<void> _handleMarkHelpful(ReviewModel review) async {
    try {
      if (review.hasVoted) {
        await _api.unmarkReviewHelpful(review.id);
      } else {
        await _api.markReviewHelpful(review.id);
      }
      _api.invalidateProductReviewCache(widget.productId);
      await _fetchReviews(showLoading: false, forceRefresh: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _showWriteReviewDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => WriteReviewDialog(productId: widget.productId),
    );

    if (result == true) {
      await _fetchReviews(showLoading: false, forceRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Reviews for ${widget.productTitle}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _buildBody(isDark),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showWriteReviewDialog,
        icon: const Icon(Icons.rate_review),
        label: const Text('Write Review'),
        backgroundColor: AppColors.electricBlue,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading reviews',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _fetchReviews(forceRefresh: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: 80,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'No reviews yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to review this product!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showWriteReviewDialog,
              icon: const Icon(Icons.rate_review),
              label: const Text('Write a Review'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.electricBlue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildSummarySection(isDark),
        _buildFilterBar(isDark),
        _buildSortBar(isDark),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _fetchReviews(
              showLoading: false,
              forceRefresh: true,
            ),
            child: _filteredReviews.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No reviews match the current filters',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredReviews.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 32),
                    itemBuilder: (context, index) {
                      final review = _filteredReviews[index];
                      return ReviewCard(
                        review: review,
                        onMarkHelpful: () => _handleMarkHelpful(review),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummarySection(bool isDark) {
    final totalReviews = _reviews.length;
    final averageRating = totalReviews > 0
        ? _reviews.map((r) => r.rating).reduce((a, b) => a + b) / totalReviews
        : 0.0;

    // Calculate rating distribution
    final ratingCounts = <int, int>{};
    for (var i = 1; i <= 5; i++) {
      ratingCounts[i] = _reviews.where((r) => r.rating == i).length;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Average rating
              Expanded(
                child: Column(
                  children: [
                    Text(
                      averageRating.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildStarRating(averageRating),
                    const SizedBox(height: 8),
                    Text(
                      '$totalReviews ${totalReviews == 1 ? 'review' : 'reviews'}',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Rating distribution
              Expanded(
                flex: 2,
                child: Column(
                  children: List.generate(5, (index) {
                    final rating = 5 - index;
                    final count = ratingCounts[rating] ?? 0;
                    final percentage =
                        totalReviews > 0 ? count / totalReviews : 0.0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            '$rating',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.star,
                            size: 14,
                            color: isDark ? Colors.grey[600] : Colors.grey[400],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: percentage,
                                backgroundColor: isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[200],
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.electricBlue,
                                ),
                                minHeight: 8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 30,
                            child: Text(
                              '$count',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStarRating(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        IconData icon;
        if (rating >= starValue) {
          icon = Icons.star;
        } else if (rating >= starValue - 0.5) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }
        return Icon(icon, color: Colors.amber, size: 20);
      }),
    );
  }

  Widget _buildFilterBar(bool isDark) {
    final followingCount = _reviews.where((r) => r.isFollowing).length;
    final verifiedCount = _reviews.where((r) => r.isVerifiedPurchase).length;

    // Only show filter bar if there are reviews with trust badges
    if (followingCount == 0 && verifiedCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.filter_list,
            size: 20,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Text(
            'Filter:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (followingCount > 0)
                    _buildFilterChip(
                      label: 'From people you follow',
                      count: followingCount,
                      isSelected: _filterFollowing,
                      onTap: () => _toggleFilter('following'),
                      icon: Icons.people,
                      color: AppColors.electricBlue,
                      isDark: isDark,
                    ),
                  if (followingCount > 0 && verifiedCount > 0)
                    const SizedBox(width: 8),
                  if (verifiedCount > 0)
                    _buildFilterChip(
                      label: 'Verified Purchases',
                      count: verifiedCount,
                      isSelected: _filterVerified,
                      onTap: () => _toggleFilter('verified'),
                      icon: Icons.verified,
                      color: Colors.green,
                      isDark: isDark,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.15)
                : (isDark ? Colors.grey[800] : Colors.grey[100]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? color
                  : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? color
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              const SizedBox(width: 6),
              Text(
                '$label ($count)',
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected
                      ? color
                      : (isDark ? Colors.grey[300] : Colors.grey[700]),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.grey[100],
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Sort by:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSortChip('Most Recent', 'recent', isDark),
                  const SizedBox(width: 8),
                  _buildSortChip('Most Helpful', 'helpful', isDark),
                  const SizedBox(width: 8),
                  _buildSortChip('Highest Rated', 'rating_high', isDark),
                  const SizedBox(width: 8),
                  _buildSortChip('Lowest Rated', 'rating_low', isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String value, bool isDark) {
    final isSelected = _sortBy == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _changeSortOrder(value),
      backgroundColor: isDark ? Colors.grey[800] : Colors.white,
      selectedColor: AppColors.electricBlue.withValues(alpha: 0.2),
      checkmarkColor: AppColors.electricBlue,
      labelStyle: TextStyle(
        color: isSelected
            ? AppColors.electricBlue
            : (isDark ? Colors.grey[300] : Colors.grey[700]),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected
            ? AppColors.electricBlue
            : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
      ),
    );
  }
}
