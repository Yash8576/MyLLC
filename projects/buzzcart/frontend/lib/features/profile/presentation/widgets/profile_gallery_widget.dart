import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/models/models.dart';
import '../../../../core/services/api_service.dart';

/// Instagram-style profile gallery with 3-column grid layout
/// Supports infinite scroll with cursor-based pagination
class ProfileGalleryWidget extends StatefulWidget {
  final String userId;
  final bool isOwnProfile;

  const ProfileGalleryWidget({
    super.key,
    required this.userId,
    this.isOwnProfile = false,
  });

  @override
  State<ProfileGalleryWidget> createState() => _ProfileGalleryWidgetState();
}

class _ProfileGalleryWidgetState extends State<ProfileGalleryWidget> {
  final ApiService _api = ApiService();
  final ScrollController _scrollController = ScrollController();
  final List<PostModel> _posts = [];
  final Set<String> _deletingPostIds = <String>{};
  
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _nextCursor;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadPosts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadPosts() async {
    if (!mounted) return;
    
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _api.getUserPosts(
        userId: widget.userId,
        limit: 30,
      );

      if (!mounted) return;
      
      setState(() {
        _posts.clear();
        _posts.addAll(response.posts);
        _nextCursor = response.nextCursor;
        _hasMore = response.hasMore;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _nextCursor == null) return;

    setState(() => _loadingMore = true);

    try {
      final response = await _api.getUserPosts(
        userId: widget.userId,
        cursor: _nextCursor,
        limit: 30,
      );

      if (!mounted) return;
      
      setState(() {
        _posts.addAll(response.posts);
        _nextCursor = response.nextCursor;
        _hasMore = response.hasMore;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<bool> _confirmDeletePost() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This will permanently remove this published post.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _deletePost(PostModel post) async {
    if (!widget.isOwnProfile || !await _confirmDeletePost() || !mounted) {
      return;
    }

    setState(() => _deletingPostIds.add(post.id));
    try {
      await _api.deletePost(post.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _posts.removeWhere((item) => item.id == post.id);
        _deletingPostIds.remove(post.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post deleted')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _deletingPostIds.remove(post.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete post')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Failed to load posts', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadPosts,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_posts.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.isOwnProfile ? Icons.add_photo_alternate : Icons.photo_library_outlined,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                widget.isOwnProfile ? 'No posts yet' : 'No posts',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                widget.isOwnProfile
                    ? 'Share your first photo or video'
                    : 'When this user posts, you\'ll see them here',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(1),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 1,
          crossAxisSpacing: 1,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == _posts.length) {
              return _loadingMore
                  ? const Center(child: CircularProgressIndicator())
                  : const SizedBox.shrink();
            }

            final post = _posts[index];
            return _GridItem(
              post: post,
              onTap: () => _openPost(post, index),
              isOwnProfile: widget.isOwnProfile,
              isDeleting: _deletingPostIds.contains(post.id),
              onDelete: () => _deletePost(post),
            );
          },
          childCount: _posts.length + (_loadingMore ? 1 : 0),
        ),
      ),
    );
  }

  void _openPost(PostModel post, int index) {
    // TODO: Navigate to post detail screen
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 1.0,
              child: CachedNetworkImage(
                imageUrl: post.mediaUrl,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          post.authorName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text('${post.likeCount} likes'),
                    ],
                  ),
                  if (post.caption.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(post.caption),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridItem extends StatelessWidget {
  final PostModel post;
  final VoidCallback onTap;
  final bool isOwnProfile;
  final bool isDeleting;
  final VoidCallback onDelete;

  const _GridItem({
    required this.post,
    required this.onTap,
    required this.isOwnProfile,
    required this.isDeleting,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isDeleting ? null : onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Media thumbnail
          Opacity(
            opacity: isDeleting ? 0.45 : 1,
            child: CachedNetworkImage(
              imageUrl: post.thumbnailUrl ?? post.mediaUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[200],
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          ),
          
          // Video indicator
          if (post.isVideo)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),

          if (isOwnProfile)
            Positioned(
              top: 8,
              left: 8,
              child: Material(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: isDeleting ? null : onDelete,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: isDeleting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                            size: 18,
                          ),
                  ),
                ),
              ),
            ),
          
          // Engagement overlay (shown on hover/press)
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isDeleting ? null : onTap,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.favorite, color: Colors.white, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          _formatCount(post.likeCount),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.mode_comment, color: Colors.white, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          _formatCount(post.commentCount),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }
}
