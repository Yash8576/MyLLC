import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';

import '../../../core/models/models.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/url_helper.dart';
import '../../products/widgets/product_reviews_sheet.dart';

class ManageOrderPage extends StatefulWidget {
  const ManageOrderPage({super.key, required this.product});

  final ProductModel product;

  @override
  State<ManageOrderPage> createState() => _ManageOrderPageState();
}

class _ManageOrderPageState extends State<ManageOrderPage> {
  late final ApiService _api;

  int _selectedRating = 0;
  int? _savedRating;
  ReviewModel? _savedReview;
  double _globalAverage = 0;
  int _globalCount = 0;
  bool _isLoadingReview = true;
  bool _isSubmitting = false;
  bool _didChangeRating = false;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiService>();
    _globalAverage = widget.product.rating;
    _globalCount = widget.product.reviewsCount;
    _savedRating = _purchaseRatingHint;
    _selectedRating = _purchaseRatingHint ?? 0;
    _loadReviewState();
  }

  int? get _purchaseRatingHint {
    final raw = widget.product.metadata['your_rating'];
    if (raw is int && raw > 0) {
      return raw;
    }
    if (raw is num && raw > 0) {
      return raw.toInt();
    }
    final parsed = int.tryParse('${raw ?? ''}');
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  Future<void> _loadReviewState() async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null || userId.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingReview = false);
      return;
    }

    try {
      final reviews = await _api.getProductReviews(widget.product.id);
      ProductModel latestProduct = widget.product;
      try {
        latestProduct = await _api.getProduct(widget.product.id);
      } catch (_) {
        latestProduct = widget.product;
      }

      ReviewModel? savedReview;
      for (final review in reviews) {
        if (review.userId == userId) {
          savedReview = review;
          break;
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _savedReview = savedReview;
        _savedRating = savedReview?.rating ?? _purchaseRatingHint;
        _selectedRating = savedReview?.rating ?? _purchaseRatingHint ?? 0;
        _globalAverage = latestProduct.rating;
        _globalCount = latestProduct.reviewsCount;
        _isLoadingReview = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingReview = false);
    }
  }

  Future<void> _refreshGlobalRating() async {
    try {
      final latestProduct = await _api.getProduct(widget.product.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _globalAverage = latestProduct.rating;
        _globalCount = latestProduct.reviewsCount;
      });
    } catch (_) {
      // Keep the existing values if the refresh fails.
    }
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

  String _saveErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['error'];
        if (message is String && message.trim().isNotEmpty) {
          return message;
        }
      }
    }
    return 'Failed to save rating';
  }

  String _normalizedReviewText(String? value) {
    return value?.trim() ?? '';
  }

  Future<void> _submitReview({
    required int rating,
    String? reviewText,
  }) async {
    if (_isSubmitting) {
      return;
    }

    final normalizedReviewText = _normalizedReviewText(reviewText);
    final reviewTextToSave =
        normalizedReviewText.isEmpty ? null : normalizedReviewText;

    final hadExistingReview = _savedReview != null;
    setState(() => _isSubmitting = true);
    try {
      late final ReviewModel savedReview;
      if (_savedReview == null) {
        try {
          savedReview = await _api.createReview(
            productId: widget.product.id,
            rating: rating,
            reviewText: reviewTextToSave,
            suppressAlreadyReviewedConflictLog: true,
          );
        } on DioException catch (error) {
          final reviewId = _reviewConflictId(error);
          if (reviewId == null) {
            rethrow;
          }
          final existingReview = await _api.getReview(reviewId);
          final shouldUpdate = existingReview.rating != rating ||
              _normalizedReviewText(existingReview.reviewText) !=
                  normalizedReviewText;
          savedReview = shouldUpdate
              ? await _api.updateReview(
                  reviewId: existingReview.id,
                  productId: widget.product.id,
                  rating: rating,
                  reviewTitle: existingReview.reviewTitle,
                  reviewText: reviewTextToSave,
                  isPrivate: existingReview.isPrivate,
                )
              : existingReview;
        }
      } else {
        savedReview = await _api.updateReview(
          reviewId: _savedReview!.id,
          productId: widget.product.id,
          rating: rating,
          reviewTitle: _savedReview!.reviewTitle,
          reviewText: reviewTextToSave,
          isPrivate: _savedReview!.isPrivate,
        );
      }

      await _refreshGlobalRating();

      if (!mounted) {
        return;
      }

      setState(() {
        _savedReview = savedReview;
        _savedRating = savedReview.rating;
        _selectedRating = savedReview.rating;
        _didChangeRating = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hadExistingReview
                ? 'Review updated to ${savedReview.rating}/5 for ${widget.product.title}'
                : 'Review ${savedReview.rating}/5 saved for ${widget.product.title}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_saveErrorMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<_ReviewUpdateDraft?> _askForReviewUpdate() async {
    var tempRating = _savedRating ?? _selectedRating;
    var tempReviewText = _savedReview?.reviewText ?? '';

    return showDialog<_ReviewUpdateDraft>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Update Rating & Review'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (index) {
                        final value = index + 1;
                        return IconButton(
                          onPressed: () =>
                              setDialogState(() => tempRating = value),
                          icon: Icon(
                            value <= tempRating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: value <= tempRating
                                ? Colors.amber[700]
                                : Colors.grey,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: tempReviewText,
                      onChanged: (value) => tempReviewText = value,
                      minLines: 3,
                      maxLines: 5,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Your review',
                        hintText: 'Share your experience (optional)',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: tempRating == 0
                      ? null
                      : () => Navigator.of(context).pop(
                            _ReviewUpdateDraft(
                              rating: tempRating,
                              reviewText: tempReviewText,
                            ),
                          ),
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openReviewsSheet() async {
    final didChange = await showProductReviewsSheet(
      context: context,
      product: widget.product,
      canWriteReview: true,
      onReviewChanged: () async {
        await _loadReviewState();
        await _refreshGlobalRating();
        if (mounted) {
          setState(() => _didChangeRating = true);
        }
      },
    );
    if (didChange == true && mounted) {
      await _loadReviewState();
      await _refreshGlobalRating();
      if (!mounted) {
        return;
      }
      setState(() => _didChangeRating = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final compareAtPrice = product.compareAtPrice;
    final hasDiscount =
        compareAtPrice != null && compareAtPrice > product.price;
    final percentOff = hasDiscount
        ? (((compareAtPrice - product.price) / compareAtPrice) * 100).round()
        : 0;
    final imageUrl = product.images.isNotEmpty ? product.images.first : '';
    final isInitialRatingFlow = _savedRating == null;
    final isReadOnlyMode = _savedRating != null;
    final ratingToDisplay = _savedRating ?? _selectedRating;
    final savedReviewText = _normalizedReviewText(_savedReview?.reviewText);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(_didChangeRating),
        ),
        title: const Text('Manage Order'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    UrlHelper.getPlatformUrl(imageUrl),
                    width: 68,
                    height: 68,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 68,
                      height: 68,
                      color: Colors.grey[300],
                      child: const Icon(Icons.shopping_bag_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.blue,
                        ),
                      ),
                      if (hasDiscount) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '\$${compareAtPrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withAlpha(24),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$percentOff% OFF',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Rate this order',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isLoadingReview
                ? 'Loading your saved rating...'
                : isReadOnlyMode
                    ? 'Your rating and review are saved. Tap Update to change them.'
                    : 'Give a rating out of 5. Open Reviews to add written feedback.',
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(5, (index) {
              final starValue = index + 1;
              return IconButton(
                onPressed: isReadOnlyMode || _isLoadingReview || _isSubmitting
                    ? null
                    : () {
                        setState(() => _selectedRating = starValue);
                      },
                icon: Icon(
                  starValue <= ratingToDisplay
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: starValue <= ratingToDisplay
                      ? Colors.amber[700]
                      : Colors.grey,
                  size: 34,
                ),
                tooltip: '$starValue star${starValue == 1 ? '' : 's'}',
              );
            }),
          ),
          const SizedBox(height: 6),
          Text(
            ratingToDisplay == 0
                ? 'No rating selected'
                : 'Selected rating: $ratingToDisplay / 5',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _savedRating == null
                ? 'Your rating: not rated yet'
                : 'Your rating: $_savedRating / 5',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            savedReviewText.isEmpty
                ? 'Your review: not added yet'
                : 'Your review:',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (savedReviewText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(savedReviewText),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            _globalCount <= 0
                ? 'Global rating: No ratings'
                : 'Global rating: ${_globalAverage.toStringAsFixed(1)} ($_globalCount)',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _openReviewsSheet,
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: Text(
              _globalCount == 1 ? '1 Review' : '$_globalCount Reviews',
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isLoadingReview || _isSubmitting
                ? null
                : isInitialRatingFlow
                    ? (_selectedRating == 0
                        ? null
                        : () => _submitReview(
                              rating: _selectedRating,
                              reviewText: _savedReview?.reviewText,
                            ))
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final reviewUpdate = await _askForReviewUpdate();
                        if (!mounted || reviewUpdate == null) {
                          return;
                        }
                        final previousRating = _savedRating ?? 0;
                        final previousReviewText =
                            _normalizedReviewText(_savedReview?.reviewText);
                        final nextReviewText =
                            _normalizedReviewText(reviewUpdate.reviewText);

                        if (reviewUpdate.rating == previousRating &&
                            nextReviewText == previousReviewText) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please change rating or review before updating',
                              ),
                            ),
                          );
                          return;
                        }
                        await _submitReview(
                          rating: reviewUpdate.rating,
                          reviewText: reviewUpdate.reviewText,
                        );
                      },
            child: Text(
              _isSubmitting
                  ? 'Saving...'
                  : isInitialRatingFlow
                      ? 'Save Rating'
                      : 'Update',
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewUpdateDraft {
  const _ReviewUpdateDraft({
    required this.rating,
    required this.reviewText,
  });

  final int rating;
  final String reviewText;
}
