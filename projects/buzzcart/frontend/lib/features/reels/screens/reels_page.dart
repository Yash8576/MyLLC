import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:buzz_social_cart/core/utils/app_snack_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';

import '../../../core/models/models.dart';
import '../../../core/providers/app_refresh_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/url_helper.dart';
import '../../../core/widgets/network_media.dart';
import '../../content/presentation/widgets/content_bottom_sheets.dart'
    as content_sheets;
import '../../layout/main_layout.dart';

bool get _allowDesktopWebBackgroundPlayback =>
    kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux);

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
  final Map<String, GlobalKey<_ReelViewportState>> _reelKeys =
      <String, GlobalKey<_ReelViewportState>>{};
  List<ReelModel> _reels = <ReelModel>[];
  bool _loading = true;
  int _currentIndex = 0;
  bool _isAppActive = true;
  bool _areReelsMuted = true;
  AppRefreshProvider? _appRefreshProvider;
  int _lastContentVersion = 0;
  String? _lastRequestedReelId;
  bool? _lastReelsBranchActive;
  int _playbackSyncGeneration = 0;
  Timer? _playbackSyncRetryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController.addListener(_handlePagePositionChanged);
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
    _playbackSyncRetryTimer?.cancel();
    _pageController.removeListener(_handlePagePositionChanged);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_allowDesktopWebBackgroundPlayback) {
      return;
    }
    final isAppActive = state == AppLifecycleState.resumed;
    if (_isAppActive == isAppActive || !mounted) {
      return;
    }
    setState(() {
      _isAppActive = isAppActive;
    });
    _syncCurrentReelPlayback();
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
      if (_reels.isEmpty) {
        setState(() => _loading = true);
      }
      final requestedReelId = _requestedReelId();
      final reels = await _api.getReels();
      final hydratedReels = await _hydrateRequestedReel(
        reels,
        requestedReelId,
      );
      final currentReelId = _reels.isNotEmpty && _currentIndex < _reels.length
          ? _reels[_currentIndex].id
          : null;
      final targetIndex = _indexForReelId(
        hydratedReels,
        requestedReelId ?? currentReelId,
      );
      if (!mounted) {
        return;
      }
      final reelIds = hydratedReels.map((reel) => reel.id).toSet();
      _reelKeys.removeWhere((reelId, _) => !reelIds.contains(reelId));
      setState(() {
        _reels = hydratedReels;
        _currentIndex = targetIndex;
        _loading = false;
      });
      _syncCurrentReelPlayback();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) {
          return;
        }
        if ((_pageController.page?.round() ?? _currentIndex) != targetIndex) {
          _pageController.jumpToPage(targetIndex);
        }
        _syncCurrentReelPlayback();
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

  void _handlePagePositionChanged() {
    if (!_pageController.hasClients || _reels.isEmpty || !mounted) {
      return;
    }
    final page = _pageController.page;
    if (page == null) {
      return;
    }
    final visibleIndex = page.round().clamp(0, _reels.length - 1).toInt();
    if (visibleIndex == _currentIndex) {
      return;
    }
    _setCurrentIndex(visibleIndex);
  }

  void _syncVisiblePage() {
    if (!_pageController.hasClients || _reels.isEmpty || !mounted) {
      return;
    }
    final visiblePage = _pageController.page?.round() ?? _currentIndex;
    final clampedIndex = visiblePage.clamp(0, _reels.length - 1).toInt();
    _setCurrentIndex(clampedIndex);
  }

  void _setCurrentIndex(int index) {
    final clampedIndex = index.clamp(0, _reels.length - 1).toInt();
    if (_currentIndex != clampedIndex) {
      setState(() {
        _currentIndex = clampedIndex;
      });
    }
    _syncCurrentReelPlayback();
  }

  void _syncCurrentReelPlayback() {
    final generation = ++_playbackSyncGeneration;
    _playbackSyncRetryTimer?.cancel();
    _applyCurrentReelPlayback();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _playbackSyncGeneration) {
        return;
      }
      _applyCurrentReelPlayback();
      _playbackSyncRetryTimer = Timer(const Duration(milliseconds: 120), () {
        if (!mounted || generation != _playbackSyncGeneration) {
          return;
        }
        _applyCurrentReelPlayback();
      });
    });
  }

  void _applyCurrentReelPlayback() {
    if (!mounted || _reels.isEmpty || _currentIndex >= _reels.length) {
      return;
    }
    final canPlayActiveReel = _isAppActive && (_lastReelsBranchActive ?? false);
    final activeReelId = canPlayActiveReel ? _reels[_currentIndex].id : null;
    final preparedReelIds = <String>{};
    if (_lastReelsBranchActive ?? false) {
      for (final index in <int>[
        _currentIndex - 1,
        _currentIndex,
        _currentIndex + 1,
      ]) {
        if (index >= 0 && index < _reels.length) {
          preparedReelIds.add(_reels[index].id);
        }
      }
    }
    for (final entry in _reelKeys.entries) {
      entry.value.currentState?.syncActivePlayback(
        shouldPlay: entry.key == activeReelId,
        shouldPrepare: preparedReelIds.contains(entry.key),
      );
    }
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
      _setCurrentIndex(targetIndex);
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
    final currentPath = activeScope?.currentPath ?? '';
    // When opened as a standalone drill-in route there is no shell scope, so
    // the page is always the active surface and should play.
    final isStandalone = activeScope == null;
    final canPop = Navigator.of(context).canPop();
    final isReelsBranchActive = isStandalone ||
        (activeScope.currentIndex == 2 &&
            (currentPath == '/reels' || currentPath.startsWith('/reels/')) &&
            !activeScope.obscured);
    final showDesktopNavArrows =
        kIsWeb || defaultTargetPlatform == TargetPlatform.windows;
    if (_lastReelsBranchActive != isReelsBranchActive) {
      _lastReelsBranchActive = isReelsBranchActive;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _syncCurrentReelPlayback();
        }
      });
    }

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
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _fetchReels,
            child: NotificationListener<ScrollEndNotification>(
              onNotification: (_) {
                _syncVisiblePage();
                return false;
              },
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: PageScrollPhysics(),
                ),
                itemCount: _reels.length,
                onPageChanged: _setCurrentIndex,
                itemBuilder: (context, index) {
                  final reel = _reels[index];
                  final key = _reelKeys.putIfAbsent(
                    reel.id,
                    () => GlobalKey<_ReelViewportState>(),
                  );
                  return _ReelViewport(
                    key: key,
                    reel: reel,
                    isActive: index == _currentIndex &&
                        isReelsBranchActive &&
                        _isAppActive,
                    isMuted: _areReelsMuted,
                    onMuteChanged: _handleMuteChanged,
                    showNavigationArrows: showDesktopNavArrows,
                    canGoPrevious: index > 0,
                    canGoNext: index < _reels.length - 1,
                    onPrevious: index > 0 ? () => _goToReel(index - 1) : null,
                    onNext: index < _reels.length - 1
                        ? () => _goToReel(index + 1)
                        : null,
                    onLikeChanged: (isLiked, likes) {
                      if (!mounted || index >= _reels.length) return;
                      setState(() {
                        _reels[index] = _reels[index].copyWith(
                          isLiked: isLiked,
                          likes: likes,
                        );
                      });
                    },
                  );
                },
              ),
            ),
          ),
          // Back button when opened as a standalone drill-in route.
          if (canPop)
            Positioned(
              top: 12,
              left: 12,
              child: SafeArea(
                child: Material(
                  color: Colors.black38,
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
            ),
        ],
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
    this.onLikeChanged,
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
  final void Function(bool isLiked, int likes)? onLikeChanged;

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
  static const int _maxEntries = 5;
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
  bool _shouldPlay = false;
  bool _shouldPrepare = false;
  int _playbackGeneration = 0;
  Timer? _playbackRetryTimer;
  bool _liked = false;
  bool _liking = false;
  int _likeCount = 0;
  int _commentCount = 0;
  bool _showFullCaption = false;
  TapGestureRecognizer? _seeMoreRecognizer;

  @override
  void initState() {
    super.initState();
    _liked = widget.reel.isLiked;
    _likeCount = widget.reel.likes;
    _commentCount = widget.reel.commentCount;
    _syncDesiredPlayback(
      shouldPlay: widget.isActive,
      shouldPrepare: widget.isActive,
    );
  }

  @override
  void didUpdateWidget(covariant _ReelViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reel.id != widget.reel.id ||
        oldWidget.reel.commentCount != widget.reel.commentCount) {
      _commentCount = widget.reel.commentCount;
    }
    if (oldWidget.reel.id != widget.reel.id) {
      _liked = widget.reel.isLiked;
      _likeCount = widget.reel.likes;
    }
    if (oldWidget.reel.id != widget.reel.id) {
      _releaseController(cacheForReuse: true, cacheKey: oldWidget.reel.id);
    }
    _syncDesiredPlayback(
      shouldPlay: widget.isActive,
      shouldPrepare: widget.isActive,
    );
  }

  @override
  void dispose() {
    _playbackRetryTimer?.cancel();
    _releaseController(cacheForReuse: true);
    _seeMoreRecognizer?.dispose();
    super.dispose();
  }

  void _releaseController({
    bool cacheForReuse = false,
    String? cacheKey,
  }) {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      if (cacheForReuse && controller.value.isInitialized) {
        controller.pause();
        _ReelControllerCache.store(cacheKey ?? widget.reel.id, controller);
      } else {
        controller.dispose();
      }
    }
  }

  void syncActivePlayback({
    required bool shouldPlay,
    required bool shouldPrepare,
  }) {
    _syncDesiredPlayback(
      shouldPlay: shouldPlay,
      shouldPrepare: shouldPrepare,
    );
  }

  void _syncDesiredPlayback({
    required bool shouldPlay,
    required bool shouldPrepare,
  }) {
    _shouldPlay = shouldPlay;
    _shouldPrepare = shouldPrepare || shouldPlay;
    final generation = ++_playbackGeneration;
    _playbackRetryTimer?.cancel();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _playbackGeneration) {
        return;
      }
      _applyDesiredPlayback(generation);
    });
  }

  Future<void> _applyDesiredPlayback(int generation) async {
    if (!mounted || generation != _playbackGeneration) {
      return;
    }

    if (!_shouldPlay && !_shouldPrepare) {
      final controller = _controller;
      if (controller != null && controller.value.isInitialized) {
        await controller.pause();
      }
      return;
    }

    if (_controller == null) {
      await _ensureController();
      if (!mounted || generation != _playbackGeneration) {
        return;
      }
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    await controller.setVolume(widget.isMuted ? 0 : 1);
    if (!_shouldPlay) {
      await controller.pause();
      return;
    }
    await controller.play();
    _schedulePlaybackRetry(generation);
  }

  void _schedulePlaybackRetry(int generation) {
    _playbackRetryTimer?.cancel();
    _playbackRetryTimer = Timer(const Duration(milliseconds: 180), () {
      if (!mounted || generation != _playbackGeneration || !_shouldPlay) {
        return;
      }
      final controller = _controller;
      if (controller == null || !controller.value.isInitialized) {
        return;
      }
      if (!controller.value.isPlaying) {
        unawaited(controller.play());
      }
    });
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
      if (_shouldPlay) {
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
    // No widget in build() reads controller.value.isPlaying — the
    // VideoPlayer widget already reflects play/pause via its own listener
    // on the controller, so no setState/rebuild is needed here.
    if (controller.value.isPlaying) {
      _shouldPlay = false;
      _playbackGeneration++;
      _playbackRetryTimer?.cancel();
      await controller.pause();
    } else {
      _shouldPlay = true;
      _shouldPrepare = true;
      final generation = ++_playbackGeneration;
      await controller.play();
      _schedulePlaybackRetry(generation);
    }
  }

  Future<void> _likeReel() async {
    if (_liking) return;
    final wasLiked = _liked;
    setState(() {
      _liked = !wasLiked;
      _liking = true;
      _likeCount = math.max(0, _likeCount + (wasLiked ? -1 : 1));
    });
    try {
      final result = await context.read<ApiService>().likeReel(widget.reel.id);
      if (mounted) {
        final needsUpdate =
            result.isLiked != _liked || result.likes != _likeCount;
        if (needsUpdate) {
          setState(() {
            _liked = result.isLiked;
            _likeCount = result.likes;
          });
        }
        widget.onLikeChanged?.call(result.isLiked, result.likes);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _liked = wasLiked;
          _likeCount = math.max(0, _likeCount + (wasLiked ? 1 : -1));
        });
      }
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  Future<void> _openLikes() {
    return content_sheets.showContentLikesSheet(
      context: context,
      loadLikes: () => context.read<ApiService>().getReelLikes(widget.reel.id),
    );
  }

  Future<void> _openComments() async {
    final updatedCount = await content_sheets.showContentCommentsSheet(
      context: context,
      title: 'Comments',
      initialCount: _commentCount,
      loadComments: ({required bool connectionsOnly}) async {
        final comments = await context.read<ApiService>().getReelComments(
              widget.reel.id,
              connectionsOnly: connectionsOnly,
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
            child: _buildMedia(controller, isReady),
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
          bottom: 16 + glossyBottomNavClearance(context),
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
                count: _likeCount,
                onTap: _likeReel,
                onCountTap: _openLikes,
              ),
              const SizedBox(height: 18),
              _ReelActionButton(
                icon: Icons.chat_bubble_outline,
                color: Colors.white,
                count: _commentCount,
                onTap: _openComments,
              ),
              const SizedBox(height: 18),
              if (products.isNotEmpty) ...[
                _ReelActionButton(
                  icon: Icons.sell_outlined,
                  color: Colors.white,
                  count: products.length,
                  onTap: () => content_sheets.showTaggedProductsSheet(
                    context: context,
                    products: widget.reel.products,
                  ),
                ),
                const SizedBox(height: 18),
              ],
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
        if (!_showFullCaption)
          Positioned(
            left: 16,
            width: MediaQuery.of(context).size.width * 0.75,
            bottom: 16 + glossyBottomNavClearance(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAvatarRow(),
                if (widget.reel.caption.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildCaptionText(
                    MediaQuery.of(context).size.width * 0.75,
                  ),
                ],
              ],
            ),
          ),
        if (_showFullCaption) ...[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _showFullCaption = false),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: Container(color: Colors.black.withValues(alpha: 0.55)),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.4,
            left: 16,
            right: 16,
            bottom: 24 + glossyBottomNavClearance(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatarRow(),
                const SizedBox(height: 14),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: SingleChildScrollView(
                      child: Text(
                        widget.reel.caption,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // Phone form factor (native iOS/Android on a phone-sized screen):
  // edge-to-edge cover-fill like Instagram/TikTok, cropping the overflow so
  // the video plays under the status bar / Dynamic Island too.
  // Everything else — web, native desktop, and iPad — always gets a fixed
  // 9:16 player fit with `contain` (never cropped/zoomed), regardless of
  // window width or whether that layout happens to show the bottom nav.
  bool get _isPhoneFormFactor {
    if (kIsWeb) return false;
    final platform = defaultTargetPlatform;
    final isMobilePlatform =
        platform == TargetPlatform.iOS || platform == TargetPlatform.android;
    if (!isMobilePlatform) return false;
    return MediaQuery.of(context).size.shortestSide < 600;
  }

  Widget _buildMedia(VideoPlayerController? controller, bool isReady) {
    final isPhone = _isPhoneFormFactor;
    final fit = isPhone ? BoxFit.cover : BoxFit.contain;

    final media = isReady
        ? FittedBox(
            fit: fit,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: controller!.value.size.width,
              height: controller.value.size.height,
              child: RepaintBoundary(child: VideoPlayer(controller)),
            ),
          )
        : AppCachedImage(
            imageUrl: widget.reel.thumbnail,
            fit: fit,
            errorWidget: const Center(
              child: Icon(
                Icons.play_circle_outline,
                color: Colors.white70,
                size: 80,
              ),
            ),
          );

    if (!isPhone) {
      return Center(
        child: AspectRatio(aspectRatio: 9 / 16, child: media),
      );
    }
    return SizedBox.expand(child: media);
  }

  Widget _buildAvatarRow() {
    return InkWell(
      onTap: () => context.push('/profile/${widget.reel.creatorId}'),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppAvatar(
              name: widget.reel.creatorName,
              avatarUrl: widget.reel.creatorAvatar,
              radius: 22,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                widget.reel.creatorName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Clamps the caption to 2 lines within [maxWidth], appending a
  // differently-colored "See more" affordance when it doesn't fit — tapping
  // it (or anywhere in the truncated text) expands the full caption.
  Widget _buildCaptionText(double maxWidth) {
    final caption = widget.reel.caption.trim();
    const style = TextStyle(color: Colors.white, fontSize: 14, height: 1.35);
    const seeMoreStyle = TextStyle(
      color: AppColors.electricBlue,
      fontSize: 14,
      height: 1.35,
      fontWeight: FontWeight.w700,
    );
    const seeMoreLabel = 'See more';

    final fullPainter = TextPainter(
      text: TextSpan(text: caption, style: style),
      maxLines: 2,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    if (!fullPainter.didExceedMaxLines) {
      return Text(caption, style: style);
    }

    const ellipsis = '… ';
    var low = 0;
    var high = caption.length;
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      final probe = TextPainter(
        text: TextSpan(
          style: style,
          children: [
            TextSpan(text: '${caption.substring(0, mid).trimRight()}$ellipsis'),
            const TextSpan(text: seeMoreLabel),
          ],
        ),
        maxLines: 2,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);
      if (!probe.didExceedMaxLines) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    final truncated = caption.substring(0, low).trimRight();

    _seeMoreRecognizer?.dispose();
    _seeMoreRecognizer = TapGestureRecognizer()
      ..onTap = () => setState(() => _showFullCaption = true);

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.clip,
      text: TextSpan(
        style: style,
        children: [
          TextSpan(text: '$truncated$ellipsis'),
          TextSpan(
            text: seeMoreLabel,
            style: seeMoreStyle,
            recognizer: _seeMoreRecognizer,
          ),
        ],
      ),
    );
  }
}

class _ReelActionButton extends StatelessWidget {
  const _ReelActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.count,
    this.onCountTap,
  });

  final IconData icon;
  final Color color;
  final int? count;
  final VoidCallback? onTap;
  final VoidCallback? onCountTap;

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
          InkWell(
            onTap: onCountTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text(
                '$count',
                style: TextStyle(
                  color: onTap == null ? Colors.white38 : Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
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
  bool _connectionsOnly = false;

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
      final comments = await _api.getReelComments(
        widget.reel.id,
        connectionsOnly: _connectionsOnly,
      );
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
        if (!_connectionsOnly || comment.isFollowing) {
          _comments = <ReelCommentModel>[comment, ..._comments];
        }
        _commentCount += 1;
        _commentController.clear();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSingleSnackBar(
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: false,
                      icon: Icon(Icons.schedule),
                      label: Text('Recent'),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      icon: Icon(Icons.people_outline),
                      label: Text('Connections'),
                    ),
                  ],
                  selected: {_connectionsOnly},
                  onSelectionChanged: (selection) {
                    final nextValue = selection.first;
                    if (nextValue == _connectionsOnly) {
                      return;
                    }
                    setState(() => _connectionsOnly = nextValue);
                    _loadComments();
                  },
                ),
              ),
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
          children: [
            const SizedBox(height: 140),
            const Icon(Icons.mode_comment_outlined,
                size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Center(
              child: Text(
                _connectionsOnly
                    ? 'No connection comments yet'
                    : 'No comments yet',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
          AppAvatar(
            name: comment.username,
            avatarUrl: comment.userAvatar,
            radius: 18,
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
                    : AppCachedImage(
                        imageUrl: imageUrl,
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
