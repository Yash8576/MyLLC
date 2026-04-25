import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';

import '../../../core/models/models.dart';
import '../../../core/providers/app_refresh_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/url_helper.dart';
import '../../content/presentation/widgets/content_bottom_sheets.dart'
    as content_sheets;
import '../../layout/main_layout.dart';

class ReelsPage extends StatefulWidget {
  const ReelsPage({
    super.key,
    this.initialReelId,
  });

  final String? initialReelId;

  @override
  State<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> with WidgetsBindingObserver {
  final ApiService _api = ApiService();
  final PageController _pageController = PageController();
  List<ReelModel> _reels = <ReelModel>[];
  bool _loading = true;
  int _currentIndex = 0;
  bool _isAppActive = true;
  bool _areReelsMuted = true;
  AppRefreshProvider? _appRefreshProvider;
  int _lastContentVersion = 0;
  String? _lastRequestedReelId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchReels();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<AppRefreshProvider>();
    if (!identical(_appRefreshProvider, provider)) {
      _appRefreshProvider?.removeListener(_handleContentRefresh);
      _appRefreshProvider = provider;
      _lastContentVersion = provider.contentVersion;
      provider.addListener(_handleContentRefresh);
    }
  }

  @override
  void dispose() {
    _appRefreshProvider?.removeListener(_handleContentRefresh);
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isAppActive = state == AppLifecycleState.resumed;
    if (_isAppActive == isAppActive || !mounted) {
      return;
    }
    setState(() {
      _isAppActive = isAppActive;
    });
  }

  void _handleContentRefresh() {
    final provider = _appRefreshProvider;
    if (provider == null || provider.contentVersion == _lastContentVersion) {
      return;
    }

    _lastContentVersion = provider.contentVersion;
    if (mounted) {
      _fetchReels();
    }
  }

  Future<void> _fetchReels() async {
    try {
      setState(() => _loading = true);
      final requestedReelId = _requestedReelId();
      final reels = await _api.getReels();
      final hydratedReels = await _hydrateRequestedReel(
        reels,
        requestedReelId,
      );
      final targetIndex = _indexForReelId(hydratedReels, requestedReelId);
      if (!mounted) {
        return;
      }
      setState(() {
        _reels = hydratedReels;
        _currentIndex = targetIndex;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) {
          return;
        }
        _pageController.jumpToPage(targetIndex);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _goToReel(int index) async {
    if (!_pageController.hasClients || index < 0 || index >= _reels.length) {
      return;
    }

    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleMuteChanged(bool isMuted) {
    if (_areReelsMuted == isMuted || !mounted) {
      return;
    }

    setState(() {
      _areReelsMuted = isMuted;
    });
  }

  int _indexForReelId(List<ReelModel> reels, String? reelId) {
    if (reelId == null) {
      return 0;
    }
    final index = reels.indexWhere((reel) => reel.id == reelId);
    return index >= 0 ? index : 0;
  }

  Future<List<ReelModel>> _hydrateRequestedReel(
    List<ReelModel> reels,
    String? requestedReelId,
  ) async {
    if (requestedReelId == null ||
        reels.any((reel) => reel.id == requestedReelId)) {
      return reels;
    }

    try {
      final requestedReel = await _api.getReel(requestedReelId);
      return <ReelModel>[requestedReel, ...reels];
    } catch (_) {
      return reels;
    }
  }

  void _syncRequestedReel() {
    final requestedReelId = _requestedReelId();
    if (_lastRequestedReelId == requestedReelId || _reels.isEmpty) {
      return;
    }

    _lastRequestedReelId = requestedReelId;
    final targetIndex = _indexForReelId(_reels, requestedReelId);
    if (targetIndex == _currentIndex) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) {
        return;
      }
      _pageController.jumpToPage(targetIndex);
      setState(() {
        _currentIndex = targetIndex;
      });
    });
  }

  String? _requestedReelId() {
    final requested = widget.initialReelId;
    if (requested == null || requested.trim().isEmpty) {
      return null;
    }
    return requested.trim();
  }

  @override
  Widget build(BuildContext context) {
    _syncRequestedReel();
    final activeScope = ActiveBranchScope.maybeOf(context);
    final isReelsBranchActive = (activeScope?.currentIndex ?? 0) == 2 &&
        (activeScope?.currentPath ?? '') == '/reels';
    final showDesktopNavArrows =
        kIsWeb || defaultTargetPlatform == TargetPlatform.windows;

    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_reels.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: RefreshIndicator(
          onRefresh: _fetchReels,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 180),
              Icon(Icons.movie_outlined, size: 64, color: Colors.white54),
              SizedBox(height: 16),
              Center(
                child: Text(
                  'No reels yet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(height: 8),
              Center(
                child: Text(
                  'Pull down to refresh when new reels are published.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: RefreshIndicator(
        onRefresh: _fetchReels,
        child: PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          physics: const AlwaysScrollableScrollPhysics(
            parent: PageScrollPhysics(),
          ),
          itemCount: _reels.length,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          itemBuilder: (context, index) {
            final reel = _reels[index];
            return _ReelViewport(
              key: ValueKey(reel.id),
              reel: reel,
              isActive:
                  index == _currentIndex && isReelsBranchActive && _isAppActive,
              isMuted: _areReelsMuted,
              onMuteChanged: _handleMuteChanged,
              showNavigationArrows: showDesktopNavArrows,
              canGoPrevious: index > 0,
              canGoNext: index < _reels.length - 1,
              onPrevious: index > 0 ? () => _goToReel(index - 1) : null,
              onNext:
                  index < _reels.length - 1 ? () => _goToReel(index + 1) : null,
            );
          },
        ),
      ),
    );
  }
}

class _ReelViewport extends StatefulWidget {
  const _ReelViewport({
    super.key,
    required this.reel,
    required this.isActive,
    required this.isMuted,
    required this.onMuteChanged,
    required this.showNavigationArrows,
    this.canGoPrevious = false,
    this.canGoNext = false,
    this.onPrevious,
    this.onNext,
  });

  final ReelModel reel;
  final bool isActive;
  final bool isMuted;
  final ValueChanged<bool> onMuteChanged;
  final bool showNavigationArrows;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  State<_ReelViewport> createState() => _ReelViewportState();
}

class _ReelControllerCacheEntry {
  const _ReelControllerCacheEntry({
    required this.controller,
    required this.cachedAt,
  });

  final VideoPlayerController controller;
  final DateTime cachedAt;
}

class _ReelControllerCache {
  static const int _maxEntries = 2;
  static final Map<String, _ReelControllerCacheEntry> _entries = {};

  static VideoPlayerController? take(String reelId) {
    final entry = _entries.remove(reelId);
    return entry?.controller;
  }

  static void store(String reelId, VideoPlayerController controller) {
    _entries.remove(reelId)?.controller.dispose();
    _entries[reelId] = _ReelControllerCacheEntry(
      controller: controller,
      cachedAt: DateTime.now(),
    );
    _evictOverflow();
  }

  static void _evictOverflow() {
    while (_entries.length > _maxEntries) {
      final oldestEntry = _entries.entries.reduce(
        (current, next) => current.value.cachedAt.isBefore(next.value.cachedAt)
            ? current
            : next,
      );
      _entries.remove(oldestEntry.key)?.controller.dispose();
    }
  }
}

class _ReelViewportState extends State<_ReelViewport> {
  VideoPlayerController? _controller;
  bool _initializing = false;
  bool _liked = false;
  int _commentCount = 0;

  bool get _shouldCacheController =>
      !kIsWeb &&
      defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _commentCount = widget.reel.commentCount;
    if (widget.isActive) {
      _ensureController();
    }
  }

  @override
  void didUpdateWidget(covariant _ReelViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reel.id != widget.reel.id ||
        oldWidget.reel.commentCount != widget.reel.commentCount) {
      _commentCount = widget.reel.commentCount;
    }
    if (oldWidget.reel.id != widget.reel.id) {
      _disposeController(cacheForReuse: _shouldCacheController);
    }
    if (widget.isActive && _controller == null) {
      _ensureController();
    } else if (widget.isActive && _controller != null) {
      _controller!.setVolume(widget.isMuted ? 0 : 1);
      _controller!.play();
    } else if (!widget.isActive && _controller != null) {
      _disposeController(cacheForReuse: _shouldCacheController);
    }
  }

  @override
  void dispose() {
    _disposeController(cacheForReuse: _shouldCacheController);
    super.dispose();
  }

  void _disposeController({bool cacheForReuse = false}) {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      if (cacheForReuse && controller.value.isInitialized) {
        controller.pause();
        _ReelControllerCache.store(widget.reel.id, controller);
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
    final cachedController = _ReelControllerCache.take(widget.reel.id);
    final controller = cachedController ??
        VideoPlayerController.networkUrl(
          Uri.parse(UrlHelper.getPlayableVideoUrl(widget.reel.url)),
        );
    try {
      if (!controller.value.isInitialized) {
        await controller.initialize();
      }
      await controller.setLooping(true);
      await controller.setVolume(widget.isMuted ? 0 : 1);
      if (widget.isActive) {
        await controller.play();
      } else {
        await controller.pause();
      }
      if (!mounted) {
        _ReelControllerCache.store(widget.reel.id, controller);
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
    if (mounted) {
      widget.onMuteChanged(nextMuted);
    }
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _likeReel() async {
    if (_liked) {
      return;
    }
    setState(() => _liked = true);
    try {
      await context.read<ApiService>().likeReel(widget.reel.id);
    } catch (_) {
      if (mounted) {
        setState(() => _liked = false);
      }
    }
  }

  Future<void> _openComments() async {
    final updatedCount = await content_sheets.showContentCommentsSheet(
      context: context,
      title: 'Comments',
      initialCount: _commentCount,
      loadComments: () async {
        final comments = await context.read<ApiService>().getReelComments(
              widget.reel.id,
            );
        return comments
            .map(
              (comment) => ContentCommentModel(
                id: comment.id,
                contentId: comment.reelId,
                userId: comment.userId,
                commentText: comment.commentText,
                createdAt: comment.createdAt,
                updatedAt: comment.updatedAt,
                username: comment.username,
                userAvatar: comment.userAvatar,
                isFollowing: comment.isFollowing,
                isCurrentUser: comment.isCurrentUser,
              ),
            )
            .toList();
      },
      submitComment: (commentText) async {
        final comment = await context.read<ApiService>().createReelComment(
              reelId: widget.reel.id,
              commentText: commentText,
            );
        return ContentCommentModel(
          id: comment.id,
          contentId: comment.reelId,
          userId: comment.userId,
          commentText: comment.commentText,
          createdAt: comment.createdAt,
          updatedAt: comment.updatedAt,
          username: comment.username,
          userAvatar: comment.userAvatar,
          isFollowing: comment.isFollowing,
          isCurrentUser: comment.isCurrentUser,
        );
      },
    );
    if (!mounted || updatedCount == null || updatedCount == _commentCount) {
      return;
    }
    setState(() {
      _commentCount = updatedCount;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final isReady = controller != null && controller.value.isInitialized;
    final products = widget.reel.products;

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: _togglePlayback,
          child: Container(
            color: Colors.black,
            child: isReady
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      final videoSize = controller.value.size;
                      final aspectRatio = videoSize.height > 0
                          ? videoSize.width / videoSize.height
                          : 9 / 16;

                      return Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxHeight * aspectRatio,
                            maxHeight: constraints.maxHeight,
                          ),
                          child: RepaintBoundary(
                            child: AspectRatio(
                              aspectRatio: aspectRatio,
                              child: VideoPlayer(controller),
                            ),
                          ),
                        ),
                      );
                    },
                  )
                : Image.network(
                    UrlHelper.getPlatformUrl(widget.reel.thumbnail),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(
                        Icons.play_circle_outline,
                        color: Colors.white70,
                        size: 80,
                      ),
                    ),
                  ),
          ),
        ),
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.65),
                ],
                stops: const [0, 0.35, 1],
              ),
            ),
          ),
        ),
        if (!isReady)
          const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        Positioned(
          right: 14,
          bottom: 104,
          child: Column(
            children: [
              if (widget.showNavigationArrows) ...[
                _ReelActionButton(
                  icon: Icons.keyboard_arrow_up_rounded,
                  color: widget.canGoPrevious ? Colors.white : Colors.white38,
                  onTap: widget.canGoPrevious ? widget.onPrevious : null,
                ),
                const SizedBox(height: 18),
              ],
              _ReelActionButton(
                icon: _liked ? Icons.favorite : Icons.favorite_border,
                color: _liked ? AppColors.vibrantPink : Colors.white,
                count: widget.reel.likes + (_liked ? 1 : 0),
                onTap: _likeReel,
              ),
              const SizedBox(height: 18),
              _ReelActionButton(
                icon: Icons.chat_bubble_outline,
                color: Colors.white,
                count: _commentCount,
                onTap: _openComments,
              ),
              const SizedBox(height: 18),
              _ReelActionButton(
                icon: Icons.sell_outlined,
                color: products.isEmpty ? Colors.white38 : Colors.white,
                count: products.length,
                onTap: products.isEmpty
                    ? null
                    : () => content_sheets.showTaggedProductsSheet(
                          context: context,
                          products: widget.reel.products,
                        ),
              ),
              const SizedBox(height: 18),
              _ReelActionButton(
                icon: widget.isMuted ? Icons.volume_off : Icons.volume_up,
                color: Colors.white,
                onTap: _toggleMute,
              ),
              if (widget.showNavigationArrows) ...[
                const SizedBox(height: 18),
                _ReelActionButton(
                  icon: Icons.keyboard_arrow_down_rounded,
                  color: widget.canGoNext ? Colors.white : Colors.white38,
                  onTap: widget.canGoNext ? widget.onNext : null,
                ),
              ],
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 84,
          bottom: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => context.push('/profile/${widget.reel.creatorId}'),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 2,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundImage:
                            (widget.reel.creatorAvatar ?? '').isNotEmpty
                                ? NetworkImage(
                                    UrlHelper.getPlatformUrl(
                                        widget.reel.creatorAvatar!),
                                  )
                                : null,
                        child: (widget.reel.creatorAvatar ?? '').isEmpty
                            ? Text(
                                widget.reel.creatorName.trim().isEmpty
                                    ? 'U'
                                    : widget.reel.creatorName
                                        .trim()[0]
                                        .toUpperCase(),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.reel.creatorName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.reel.caption.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  widget.reel.caption,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
              if (products.isNotEmpty) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => content_sheets.showTaggedProductsSheet(
                    context: context,
                    products: widget.reel.products,
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                  label: Text('View tagged products (${products.length})'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ReelActionButton extends StatelessWidget {
  const _ReelActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.count,
  });

  final IconData icon;
  final Color color;
  final int? count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
        ),
        if (count != null) ...[
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(
              color: onTap == null ? Colors.white38 : Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

Future<int?> showReelCommentsSheet({
  required BuildContext context,
  required ReelModel reel,
  required int initialCount,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReelCommentsSheet(
      reel: reel,
      initialCount: initialCount,
    ),
  );
}

class _ReelCommentsSheet extends StatefulWidget {
  const _ReelCommentsSheet({
    required this.reel,
    required this.initialCount,
  });

  final ReelModel reel;
  final int initialCount;

  @override
  State<_ReelCommentsSheet> createState() => _ReelCommentsSheetState();
}

class _ReelCommentsSheetState extends State<_ReelCommentsSheet> {
  late final ApiService _api;
  late final TextEditingController _commentController;
  List<ReelCommentModel> _comments = <ReelCommentModel>[];
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  late int _commentCount;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiService>();
    _commentController = TextEditingController();
    _commentCount = widget.initialCount;
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      final comments = await _api.getReelComments(widget.reel.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _comments = comments;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _submitting) {
      return;
    }

    setState(() => _submitting = true);
    try {
      final comment = await _api.createReelComment(
        reelId: widget.reel.id,
        commentText: text,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _comments = <ReelCommentModel>[comment, ..._comments];
        _commentCount += 1;
        _commentController.clear();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
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
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return FractionallySizedBox(
      heightFactor: 0.9,
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
                      child: Text(
                        'Comments',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(_commentCount),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: theme.dividerColor),
              Expanded(child: _buildBody()),
              AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.only(bottom: viewInsets),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    border: Border(top: BorderSide(color: theme.dividerColor)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              minLines: 1,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: 'Write a comment',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _submitting ? null : _submitComment,
                            icon: _submitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
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
      return Center(child: Text(_error!));
    }
    if (_comments.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadComments,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 140),
            Icon(Icons.mode_comment_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Center(
              child: Text(
                'No comments yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadComments,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: _comments.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) =>
            _ReelCommentTile(comment: _comments[index]),
      ),
    );
  }
}

class _ReelCommentTile extends StatelessWidget {
  const _ReelCommentTile({required this.comment});

  final ReelCommentModel comment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: (comment.userAvatar ?? '').trim().isNotEmpty
                ? NetworkImage(UrlHelper.getPlatformUrl(comment.userAvatar!))
                : null,
            child: (comment.userAvatar ?? '').trim().isEmpty
                ? Text(
                    comment.username.trim().isEmpty
                        ? 'U'
                        : comment.username.trim()[0].toUpperCase(),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.isCurrentUser
                            ? '${comment.username} (You)'
                            : comment.username,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      timeago.format(DateTime.parse(comment.createdAt)),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ],
                ),
                if (comment.isFollowing) ...[
                  const SizedBox(height: 6),
                  const _MiniBadge(label: 'Connection'),
                ],
                const SizedBox(height: 8),
                Text(
                  comment.commentText,
                  style: const TextStyle(height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showTaggedProductsSheet({
  required BuildContext context,
  required ReelModel reel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TaggedProductsSheet(reel: reel),
  );
}

class _TaggedProductsSheet extends StatelessWidget {
  const _TaggedProductsSheet({required this.reel});

  final ReelModel reel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FractionallySizedBox(
      heightFactor: 0.82,
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
                    const Icon(Icons.shopping_bag_outlined, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tagged Products',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: theme.dividerColor),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  itemCount: reel.products.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _TaggedProductCard(
                    product: reel.products[index],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaggedProductCard extends StatelessWidget {
  const _TaggedProductCard({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.images.isNotEmpty
        ? UrlHelper.getPlatformUrl(product.images.first)
        : '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/shop/${product.id}'),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.26),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: imageUrl.isEmpty
                    ? Container(
                        width: 72,
                        height: 72,
                        color: Colors.black12,
                        alignment: Alignment.center,
                        child: const Icon(Icons.shopping_bag_outlined),
                      )
                    : Image.network(
                        imageUrl,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
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
                    const SizedBox(height: 6),
                    Text(
                      '\$${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.electricBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.electricBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.electricBlue,
        ),
      ),
    );
  }
}
