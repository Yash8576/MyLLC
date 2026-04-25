import 'package:flutter/material.dart';
import '../../../../core/models/models.dart';
import '../../../../core/services/api_service.dart';
import '../widgets/post_card.dart';

/// Instagram-style feed screen with infinite scroll
/// Supports both followers feed and discovery feed
class InstagramFeedScreen extends StatefulWidget {
  final bool isDiscovery; // false = followers feed, true = discovery feed

  const InstagramFeedScreen({
    super.key,
    this.isDiscovery = false,
  });

  @override
  State<InstagramFeedScreen> createState() => _InstagramFeedScreenState();
}

class _InstagramFeedScreenState extends State<InstagramFeedScreen> {
  final ApiService _api = ApiService();
  final ScrollController _scrollController = ScrollController();
  final List<PostModel> _posts = [];
  
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _nextCursor;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFeed();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Scroll listener for infinite scroll
  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  /// Initial feed load
  Future<void> _loadFeed() async {
    if (!mounted) return;
    
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final FeedResponse response;
      if (widget.isDiscovery) {
        response = await _api.getDiscoveryFeed(limit: 20);
      } else {
        response = await _api.getFollowersFeed(limit: 20);
      }

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
        _error = 'Failed to load feed: ${e.toString()}';
        _loading = false;
      });
    }
  }

  /// Load more posts (cursor-based pagination)
  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _nextCursor == null) return;

    setState(() => _loadingMore = true);

    try {
      final FeedResponse response;
      if (widget.isDiscovery) {
        response = await _api.getDiscoveryFeed(
          cursor: _nextCursor,
          limit: 20,
        );
      } else {
        response = await _api.getFollowersFeed(
          cursor: _nextCursor,
          limit: 20,
        );
      }

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load more posts: ${e.toString()}')),
      );
    }
  }

  /// Handle like/unlike post
  Future<void> _handleLike(PostModel post) async {
    // Optimistic update
    final updatedPost = post.copyWith(
      isLiked: !post.isLiked,
      likeCount: post.isLiked ? post.likeCount - 1 : post.likeCount + 1,
    );

    setState(() {
      final index = _posts.indexWhere((p) => p.id == post.id);
      if (index != -1) {
        _posts[index] = updatedPost;
      }
    });

    try {
      if (updatedPost.isLiked) {
        await _api.likePost(post.id);
      } else {
        await _api.unlikePost(post.id);
      }
    } catch (e) {
      // Revert on error
      setState(() {
        final index = _posts.indexWhere((p) => p.id == post.id);
        if (index != -1) {
          _posts[index] = post;
        }
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update like: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFeed,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              widget.isDiscovery
                  ? 'No posts to discover yet'
                  : 'No posts from people you follow',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isDiscovery
                  ? 'Check back later for new content'
                  : 'Follow people to see their posts here',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFeed,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _posts.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _posts.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final post = _posts[index];
          return PostCard(
            post: post,
            onLike: () => _handleLike(post),
          );
        },
      ),
    );
  }
}
