import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_colors.dart';
import '../../../core/models/models.dart';

class ReviewCard extends StatelessWidget {
  final ReviewModel review;
  final VoidCallback onMarkHelpful;

  const ReviewCard({
    super.key,
    required this.review,
    required this.onMarkHelpful,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // User info and rating
        Row(
          children: [
            CircleAvatar(
              backgroundImage: review.userAvatar != null
                  ? NetworkImage(review.userAvatar!)
                  : null,
              backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
              child: review.userAvatar == null
                  ? Text(
                      (review.username ?? 'U')[0].toUpperCase(),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    review.username ?? 'Anonymous',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildStarRating(review.rating),
                      const SizedBox(width: 8),
                      Text(
                        timeago.format(_reviewActivityTime(review)),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        
        // Trust badges
        if (review.isVerifiedPurchase || review.isFollowing) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (review.isFollowing)
                _buildTrustBadge(
                  icon: Icons.people,
                  label: 'From people you follow',
                  color: AppColors.electricBlue,
                  isDark: isDark,
                ),
              if (review.isVerifiedPurchase)
                _buildTrustBadge(
                  icon: Icons.verified,
                  label: 'Verified Purchase',
                  color: Colors.green,
                  isDark: isDark,
                ),
            ],
          ),
        ],
        
        // Review title
        if (review.reviewTitle != null && review.reviewTitle!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            review.reviewTitle!,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
        
        // Review text
        if (review.reviewText != null && review.reviewText!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            review.reviewText!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                ),
          ),
        ],
        
        // Review images
        if (review.images.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildImageGallery(context),
        ],
        
        // Helpful button
        const SizedBox(height: 16),
        Row(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onMarkHelpful,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: review.hasVoted
                          ? AppColors.electricBlue
                          : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                    ),
                    borderRadius: BorderRadius.circular(20),
                    color: review.hasVoted
                        ? AppColors.electricBlue.withValues(alpha: 0.1)
                        : Colors.transparent,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        review.hasVoted ? Icons.thumb_up : Icons.thumb_up_outlined,
                        size: 16,
                        color: review.hasVoted
                            ? AppColors.electricBlue
                            : (isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Helpful${review.helpfulCount > 0 ? ' (${review.helpfulCount})' : ''}',
                        style: TextStyle(
                          fontSize: 13,
                          color: review.hasVoted
                              ? AppColors.electricBlue
                              : (isDark ? Colors.grey[400] : Colors.grey[600]),
                          fontWeight: review.hasVoted ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImageGallery(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: review.images.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(right: index < review.images.length - 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () => _showImageViewer(context, index),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  review.images[index],
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 100,
                      height: 100,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[300],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showImageViewer(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _ImageViewerPage(
          images: review.images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Widget _buildStarRating(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 16,
        );
      }),
    );
  }

  Widget _buildTrustBadge({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  DateTime _parseDate(String dateStr) {
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
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

class _ImageViewerPage extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _ImageViewerPage({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<_ImageViewerPage> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          '${_currentIndex + 1} of ${widget.images.length}',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          return Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                widget.images[index],
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, color: Colors.white, size: 64),
                        SizedBox(height: 16),
                        Text(
                          'Failed to load image',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
