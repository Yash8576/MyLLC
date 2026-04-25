import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/models/models.dart';
import '../../../core/providers/app_refresh_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/url_helper.dart';

Future<bool?> showProductReviewsSheet({
  required BuildContext context,
  required ProductModel product,
  bool canWriteReview = false,
  Future<void> Function()? onReviewChanged,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProductReviewsSheet(
      product: product,
      initialCanWriteReview: canWriteReview,
      onReviewChanged: onReviewChanged,
    ),
  );
}

class _ProductReviewsSheet extends StatefulWidget {
  const _ProductReviewsSheet({
    required this.product,
    required this.initialCanWriteReview,
    this.onReviewChanged,
  });

  final ProductModel product;
  final bool initialCanWriteReview;
  final Future<void> Function()? onReviewChanged;

  @override
  State<_ProductReviewsSheet> createState() => _ProductReviewsSheetState();
}

class _ProductReviewsSheetState extends State<_ProductReviewsSheet> {
  late final ApiService _api;
  late final TextEditingController _reviewController;

  List<ReviewModel> _reviews = <ReviewModel>[];
  ReviewModel? _currentUserReview;
  bool _loading = true;
  bool _submitting = false;
  bool _canWriteReview = false;
  bool _composerExpanded = false;
  bool _didChangeReviews = false;
  String? _error;
  int _selectedRating = 0;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiService>();
    _reviewController = TextEditingController();
    _canWriteReview = widget.initialCanWriteReview;
    _primeFromCachedReviews();
    _loadData(showLoading: _reviews.isEmpty);
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  void _primeFromCachedReviews() {
    final cachedReviews = _api.peekCachedProductReviewsRanked(
      widget.product.id,
      allowPartial: true,
    );
    if (cachedReviews == null || cachedReviews.isEmpty) {
      return;
    }
    _applyLoadedReviews(cachedReviews);
    _loading = false;
  }

  Future<void> _loadData({
    bool showLoading = true,
    bool forceRefresh = false,
  }) async {
    final currentUserId = context.read<AuthProvider>().user?.id;

    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final reviews = await _api.getProductReviewsRanked(
        widget.product.id,
        forceRefresh: forceRefresh,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _applyLoadedReviews(reviews, currentUserId: currentUserId);
        _loading = false;
        _error = null;
      });

      final canWriteReview =
          widget.initialCanWriteReview || _currentUserReview != null;
      if (!canWriteReview &&
          currentUserId != null &&
          currentUserId.isNotEmpty) {
        _resolveWriteReviewPermission(currentUserId);
      }
    } catch (error) {
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
        _loading = false;
        _error = _errorMessage(error);
      });
    }
  }

  void _applyLoadedReviews(
    List<ReviewModel> reviews, {
    String? currentUserId,
  }) {
    final userId = currentUserId ?? context.read<AuthProvider>().user?.id;
    final sortedReviews = List<ReviewModel>.from(reviews)
      ..sort(_compareReviews);

    ReviewModel? currentUserReview;
    if (userId != null && userId.isNotEmpty) {
      for (final review in sortedReviews) {
        if (review.userId == userId) {
          currentUserReview = review;
          break;
        }
      }
    }

    _reviews = sortedReviews;
    _currentUserReview = currentUserReview;
    _selectedRating = currentUserReview?.rating ?? 0;
    _canWriteReview = widget.initialCanWriteReview || currentUserReview != null;
    _reviewController.text = currentUserReview?.reviewText ?? '';
  }

  Future<void> _resolveWriteReviewPermission(String currentUserId) async {
    try {
      final purchases = await _api.getUserPurchases(currentUserId);
      final canWriteReview =
          purchases.any((purchase) => purchase.id == widget.product.id);
      if (!mounted || !canWriteReview) {
        return;
      }
      setState(() {
        _canWriteReview = true;
      });
    } catch (_) {
      // Keep the sheet responsive even if purchase lookup fails.
    }
  }

  int _compareReviews(ReviewModel a, ReviewModel b) {
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

  DateTime _parseDate(String value) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  DateTime _reviewActivityTime(ReviewModel review) {
    final updatedAt = review.updatedAt.trim();
    if (updatedAt.isNotEmpty) {
      return _parseDate(updatedAt);
    }
    return _parseDate(review.createdAt);
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['error'];
        if (message is String && message.trim().isNotEmpty) {
          return message;
        }
      }
    }
    return 'Failed to load reviews';
  }

  String? _reviewConflictId(Object error) {
    if (error is! DioException) {
      return null;
    }
    final data = error.response?.data;
    if (data is! Map<String, dynamic>) {
      return null;
    }
    final reviewId = data['review_id'];
    if (reviewId is String && reviewId.trim().isNotEmpty) {
      return reviewId;
    }
    return null;
  }

  Future<void> _submitReview() async {
    if (_selectedRating <= 0 || _submitting) {
      return;
    }

    final hadExistingReview = _currentUserReview != null;
    setState(() => _submitting = true);
    try {
      final reviewText = _reviewController.text.trim();
      late final ReviewModel savedReview;

      if (_currentUserReview == null) {
        try {
          savedReview = await _api.createReview(
            productId: widget.product.id,
            rating: _selectedRating,
            reviewText: reviewText.isNotEmpty ? reviewText : null,
            suppressAlreadyReviewedConflictLog: true,
          );
        } on DioException catch (error) {
          final reviewId = _reviewConflictId(error);
          if (reviewId == null) {
            rethrow;
          }
          final existingReview = await _api.getReview(reviewId);
          savedReview = await _api.updateReview(
            reviewId: existingReview.id,
            productId: widget.product.id,
            rating: _selectedRating,
            reviewTitle: existingReview.reviewTitle,
            reviewText: reviewText.isNotEmpty ? reviewText : null,
            isPrivate: existingReview.isPrivate,
          );
        }
      } else {
        savedReview = await _api.updateReview(
          reviewId: _currentUserReview!.id,
          productId: widget.product.id,
          rating: _selectedRating,
          reviewTitle: _currentUserReview!.reviewTitle,
          reviewText: reviewText.isNotEmpty ? reviewText : null,
          isPrivate: _currentUserReview!.isPrivate,
        );
      }

      _didChangeReviews = true;
      _api.invalidateProductReviewCache(widget.product.id);
      if (mounted) {
        context.read<AppRefreshProvider>().notifyProductPublished();
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _currentUserReview = savedReview;
        _composerExpanded = false;
      });

      await _loadData(showLoading: false, forceRefresh: true);
      if (widget.onReviewChanged != null) {
        await widget.onReviewChanged!();
      }
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hadExistingReview ? 'Review updated' : 'Review posted',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reviewCount = _reviews.length;

    return FractionallySizedBox(
      heightFactor: 0.92,
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
                    const Icon(Icons.chat_bubble_outline, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Reviews',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '$reviewCount ${reviewCount == 1 ? 'review' : 'reviews'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          Navigator.of(context).pop(_didChangeReviews),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: theme.dividerColor),
              Expanded(child: _buildBody()),
              _buildComposer(theme),
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
              const Icon(Icons.error_outline,
                  size: 40, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _loadData(forceRefresh: true),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_reviews.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadData(showLoading: false, forceRefresh: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          children: const [
            SizedBox(height: 140),
            Icon(Icons.rate_review_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 14),
            Center(
              child: Text(
                'No reviews yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(height: 8),
            Center(
              child: Text(
                'Be the first to rate and review this product.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadData(showLoading: false, forceRefresh: true),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: _reviews.length,
        separatorBuilder: (_, __) => const SizedBox(height: 18),
        itemBuilder: (context, index) {
          final currentUserId = context.read<AuthProvider>().user?.id;
          final review = _reviews[index];
          return _ReviewListItem(
            review: review,
            isCurrentUser:
                currentUserId != null && currentUserId == review.userId,
          );
        },
      ),
    );
  }

  Widget _buildComposer(ThemeData theme) {
    if (!_canWriteReview) {
      return const SizedBox.shrink();
    }

    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewInsets),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.cardColor,
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: SafeArea(
          top: false,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: _composerExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _currentUserReview == null
                                    ? 'Write a review'
                                    : 'Edit your review',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _submitting
                                  ? null
                                  : () {
                                      setState(() {
                                        _composerExpanded = false;
                                        _selectedRating =
                                            _currentUserReview?.rating ?? 0;
                                        _reviewController.text =
                                            _currentUserReview?.reviewText ??
                                                '';
                                      });
                                    },
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: List.generate(5, (index) {
                            final starValue = index + 1;
                            return IconButton(
                              onPressed: _submitting
                                  ? null
                                  : () => setState(
                                      () => _selectedRating = starValue),
                              icon: Icon(
                                starValue <= _selectedRating
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: starValue <= _selectedRating
                                    ? Colors.amber[700]
                                    : Colors.grey,
                                size: 30,
                              ),
                              visualDensity: VisualDensity.compact,
                              tooltip:
                                  '$starValue star${starValue == 1 ? '' : 's'}',
                            );
                          }),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _reviewController,
                          enabled: !_submitting,
                          minLines: 3,
                          maxLines: 6,
                          decoration: InputDecoration(
                            hintText: 'Share what you liked or did not like...',
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.45),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _submitting || _selectedRating <= 0
                                ? null
                                : _submitReview,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: _submitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    _currentUserReview == null
                                        ? 'Post Review'
                                        : 'Update Review',
                                  ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _composerExpanded = true;
                          _selectedRating = _currentUserReview?.rating ?? 0;
                          _reviewController.text =
                              _currentUserReview?.reviewText ?? '';
                        });
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Ink(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.edit_outlined,
                              color: AppColors.electricBlue,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _currentUserReview == null
                                    ? 'Write a review'
                                    : 'Edit your review',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              _currentUserReview == null
                                  ? 'Tap to add'
                                  : '${_currentUserReview!.rating}/5',
                              style: TextStyle(
                                color: theme.textTheme.bodySmall?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ReviewListItem extends StatefulWidget {
  const _ReviewListItem({
    required this.review,
    required this.isCurrentUser,
  });

  final ReviewModel review;
  final bool isCurrentUser;

  @override
  State<_ReviewListItem> createState() => _ReviewListItemState();
}

class _ReviewListItemState extends State<_ReviewListItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final review = widget.review;
    final bodyText = _bodyText(review);
    final canExpand = bodyText.length > 120 || bodyText.contains('\n');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: (review.userAvatar ?? '').trim().isNotEmpty
                    ? NetworkImage(
                        UrlHelper.getPlatformUrl(review.userAvatar!),
                      )
                    : null,
                child: (review.userAvatar ?? '').trim().isEmpty
                    ? Text(
                        (review.username ?? 'U').substring(0, 1).toUpperCase(),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isCurrentUser
                          ? '${review.username?.trim().isNotEmpty == true ? review.username! : 'Anonymous'} (You)'
                          : (review.username?.trim().isNotEmpty == true
                              ? review.username!
                              : 'Anonymous'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return Icon(
                            index < review.rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 16,
                            color: index < review.rating
                                ? Colors.amber[700]
                                : Colors.grey,
                          );
                        }),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            timeago.format(_reviewActivityTime(review)),
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (review.isFollowing || review.isVerifiedPurchase) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (review.isFollowing)
                  const _Badge(label: 'Connection', color: AppColors.electricBlue),
                if (review.isVerifiedPurchase)
                  const _Badge(label: 'Verified Purchase', color: Colors.green),
              ],
            ),
          ],
          if (bodyText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              bodyText,
              maxLines: _expanded ? null : 2,
              overflow:
                  _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: const TextStyle(height: 1.35),
            ),
            if (canExpand)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(_expanded ? 'Show less' : 'Read more'),
              ),
          ],
        ],
      ),
    );
  }

  String _bodyText(ReviewModel review) {
    final segments = <String>[
      if (review.reviewTitle?.trim().isNotEmpty == true)
        review.reviewTitle!.trim(),
      if (review.reviewText?.trim().isNotEmpty == true)
        review.reviewText!.trim(),
    ];
    return segments.join('\n\n');
  }

  DateTime _parseDate(String value) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return DateTime.now();
    }
  }

  DateTime _reviewActivityTime(ReviewModel review) {
    final updatedAt = review.updatedAt.trim();
    if (updatedAt.isNotEmpty) {
      return _parseDate(updatedAt);
    }
    return _parseDate(review.createdAt);
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
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
