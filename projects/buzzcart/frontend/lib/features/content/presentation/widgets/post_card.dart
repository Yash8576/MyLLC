import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/models/models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/url_helper.dart';

/// Instagram-style post card widget
class PostCard extends StatelessWidget {
  final PostModel post;
  final VoidCallback onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onAuthorTap;

  const PostCard({
    super.key,
    required this.post,
    required this.onLike,
    this.onComment,
    this.onShare,
    this.onAuthorTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: Author info
        _buildHeader(context),
        
        // Image/Video content
        _buildMedia(context),
        
        // Action buttons (like, comment, share)
        _buildActions(context),
        
        // Like count
        _buildLikeCount(context),
        
        // Caption
        _buildCaption(context),
        
        // Timestamp
        _buildTimestamp(context),
        
        const Divider(height: 1, thickness: 0.5),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return InkWell(
      onTap: onAuthorTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Author avatar
            CircleAvatar(
              radius: 18,
              backgroundImage: post.authorAvatar != null
                  ? CachedNetworkImageProvider(
                      UrlHelper.getPlatformUrl(post.authorAvatar!),
                    )
                  : null,
              backgroundColor: AppColors.electricBlue,
              child: post.authorAvatar == null
                  ? Text(
                      post.authorName.isNotEmpty ? post.authorName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            
            // Author name
            Expanded(
              child: Row(
                children: [
                  Text(
                    post.authorName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (post.authorVerified) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.verified,
                      color: AppColors.electricBlue,
                      size: 16,
                    ),
                  ],
                ],
              ),
            ),
            
            // More options button
            IconButton(
              icon: const Icon(Icons.more_vert, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _showMoreOptions(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedia(BuildContext context) {
    if (post.isPhoto) {
      return AspectRatio(
        aspectRatio: 1.0, // Square aspect ratio like Instagram
        child: CachedNetworkImage(
          imageUrl: UrlHelper.getPlatformUrl(post.mediaUrl),
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey[200],
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey[200],
            child: const Center(child: Icon(Icons.broken_image, size: 64)),
          ),
        ),
      );
    } else if (post.isVideo) {
      // For videos, show thumbnail with play icon
      return AspectRatio(
        aspectRatio: 1.0,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (post.thumbnailUrl != null)
              CachedNetworkImage(
                imageUrl: UrlHelper.getPlatformUrl(post.thumbnailUrl!),
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[200],
                  child: const Center(child: Icon(Icons.broken_image, size: 64)),
                ),
              ),
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // Like button
          IconButton(
            icon: Icon(
              post.isLiked ? Icons.favorite : Icons.favorite_border,
              color: post.isLiked ? Colors.red : Colors.black87,
            ),
            onPressed: onLike,
            padding: const EdgeInsets.all(8),
          ),
          
          // Comment button
          IconButton(
            icon: const Icon(Icons.mode_comment_outlined),
            color: Colors.black87,
            onPressed: onComment ?? () {},
            padding: const EdgeInsets.all(8),
          ),
          
          // Share button
          IconButton(
            icon: const Icon(Icons.send_outlined),
            color: Colors.black87,
            onPressed: onShare ?? () {},
            padding: const EdgeInsets.all(8),
          ),
          
          const Spacer(),
          
          // View count (if > 0)
          if (post.viewCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  const Icon(Icons.visibility_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    _formatCount(post.viewCount),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLikeCount(BuildContext context) {
    if (post.likeCount == 0) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Text(
        '${_formatCount(post.likeCount)} ${post.likeCount == 1 ? 'like' : 'likes'}',
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildCaption(BuildContext context) {
    if (post.caption.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: post.authorName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const TextSpan(text: ' '),
            TextSpan(text: post.caption),
          ],
        ),
      ),
    );
  }

  Widget _buildTimestamp(BuildContext context) {
    try {
      final createdAt = DateTime.parse(post.createdAt);
      final timeAgo = timeago.format(createdAt, locale: 'en_short');
      
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Text(
          timeAgo.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!post.isFollowing)
              ListTile(
                leading: const Icon(Icons.person_add_outlined),
                title: const Text('Follow'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement follow
                },
              ),
            ListTile(
              leading: const Icon(Icons.bookmark_border),
              title: const Text('Save'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement save
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Copy link'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement copy link
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_outlined, color: Colors.red),
              title: const Text('Report', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement report
              },
            ),
          ],
        ),
      ),
    );
  }
}
