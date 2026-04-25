import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';

import '../../../core/models/models.dart';
import '../../../core/providers/app_refresh_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/url_helper.dart';
import '../../content/presentation/widgets/content_bottom_sheets.dart'
    as content_sheets;
import '../../products/widgets/product_card_social_preview.dart';

final Map<String, int> _videoDurationCache = <String, int>{};

class VideosPage extends StatefulWidget {
  const VideosPage({super.key, this.videoId});

  final String? videoId;

  @override
  State<VideosPage> createState() => _VideosPageState();
}

class _VideosPageState extends State<VideosPage> {
  final ApiService _api = ApiService();
  List<VideoModel> _videos = <VideoModel>[];
  VideoModel? _videoDetail;
  bool _loading = true;
  AppRefreshProvider? _appRefreshProvider;
  int _lastContentVersion = 0;

  @override
  void initState() {
    super.initState();
    if (widget.videoId != null) {
      _fetchVideoDetail();
    } else {
      _fetchVideos();
    }
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
    super.dispose();
  }

  void _handleContentRefresh() {
    final provider = _appRefreshProvider;
    if (provider == null || provider.contentVersion == _lastContentVersion) {
      return;
    }

    _lastContentVersion = provider.contentVersion;
    if (!mounted) {
      return;
    }

    if (widget.videoId != null) {
      _fetchVideoDetail();
    } else {
      _fetchVideos();
    }
  }

  Future<void> _fetchVideos() async {
    try {
      setState(() => _loading = true);
      final data = await _api.getVideos();
      if (!mounted) {
        return;
      }
      setState(() {
        _videos = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchVideoDetail() async {
    try {
      setState(() => _loading = true);
      final data = await _api.getVideo(widget.videoId!);
      if (!mounted) {
        return;
      }
      setState(() {
        _videoDetail = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/videos');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videoId != null) {
      return _buildVideoDetail();
    }
    return _buildVideoList();
  }

  Widget _buildVideoList() {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _videos.isEmpty
              ? RefreshIndicator(
                  onRefresh: _fetchVideos,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 180),
                      Icon(Icons.play_circle_outline,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Center(
                        child: Text(
                          'No videos yet',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchVideos,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    itemCount: _videos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final video = _videos[index];
                      return _VideoListCard(video: video);
                    },
                  ),
                ),
    );
  }

  Widget _buildVideoDetail() {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final video = _videoDetail;
    if (video == null) {
      return const Scaffold(
        body: Center(child: Text('Video not found')),
      );
    }

    return _VideoDetailView(video: video);
  }
}

class _VideoListCard extends StatefulWidget {
  const _VideoListCard({required this.video});

  final VideoModel video;

  @override
  State<_VideoListCard> createState() => _VideoListCardState();
}

class _VideoListCardState extends State<_VideoListCard> {
  int? _resolvedDuration;

  @override
  void initState() {
    super.initState();
    _resolvedDuration = _videoDurationCache[widget.video.id] ?? widget.video.duration;
    _ensureDuration();
  }

  Future<void> _ensureDuration() async {
    if ((_resolvedDuration ?? 0) > 0) {
      return;
    }

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(UrlHelper.getPlayableVideoUrl(widget.video.url)),
    );
    try {
      await controller.initialize();
      final duration = controller.value.duration.inSeconds;
      if (duration > 0) {
        _videoDurationCache[widget.video.id] = duration;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _resolvedDuration = duration > 0 ? duration : widget.video.duration;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _resolvedDuration = widget.video.duration;
      });
    } finally {
      await controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/videos/${widget.video.id}'),
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        UrlHelper.getPlatformUrl(widget.video.thumbnail),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.black,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.play_circle_outline,
                            color: Colors.white70,
                            size: 52,
                          ),
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.06),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.58),
                            ],
                          ),
                        ),
                      ),
                      const Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          color: Colors.white,
                          size: 58,
                        ),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: _DurationBadge(
                          durationLabel:
                              _formatDuration(_resolvedDuration ?? widget.video.duration),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => context.push('/profile/${widget.video.creatorId}'),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundImage:
                          (widget.video.creatorAvatar ?? '').trim().isNotEmpty
                              ? NetworkImage(
                                  UrlHelper.getPlatformUrl(
                                    widget.video.creatorAvatar!,
                                  ),
                                )
                              : null,
                      child: (widget.video.creatorAvatar ?? '').trim().isEmpty
                          ? Text(_initialFor(widget.video.creatorName))
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.video.title.trim().isEmpty
                              ? 'Untitled Video'
                              : widget.video.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.video.creatorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).hintColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoDetailView extends StatefulWidget {
  const _VideoDetailView({required this.video});

  final VideoModel video;

  @override
  State<_VideoDetailView> createState() => _VideoDetailViewState();
}

class _VideoDetailViewState extends State<_VideoDetailView> {
  static const Duration _transportAutoHideDelay = Duration(seconds: 2);

  VideoPlayerController? _controller;
  bool _initializing = true;
  bool _isPlaying = false;
  bool _isMuted = false;
  bool _fullscreenOpen = false;
  int _resolvedDuration = 0;
  bool _resumeAfterFullscreen = false;
  bool _showInlineControls = false;
  Timer? _inlineControlsHideTimer;

  bool get _supportsHoverControls =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  @override
  void initState() {
    super.initState();
    _lockPortrait();
    _initializePlayer();
  }

  @override
  void dispose() {
    _inlineControlsHideTimer?.cancel();
    _controller?.removeListener(_syncPlaybackState);
    _controller?.dispose();
    unawaited(_restoreSystemChrome());
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(UrlHelper.getPlayableVideoUrl(widget.video.url)),
    );

    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(_isMuted ? 0 : 1);
      await controller.play();
      controller.addListener(_syncPlaybackState);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
        _isPlaying = controller.value.isPlaying;
        _resolvedDuration = controller.value.duration.inSeconds > 0
            ? controller.value.duration.inSeconds
            : widget.video.duration;
        _showInlineControls = true;
      });
      _updateInlineControlsForPlaybackState(_isPlaying);
    } catch (_) {
      await controller.dispose();
      if (!mounted) {
        return;
      }
      setState(() {
        _initializing = false;
      });
    }
  }

  void _syncPlaybackState() {
    final isPlaying = _controller?.value.isPlaying ?? false;
    if (!mounted || _isPlaying == isPlaying) {
      return;
    }
    setState(() {
      _isPlaying = isPlaying;
      if (!isPlaying) {
        _showInlineControls = true;
      }
    });
    _updateInlineControlsForPlaybackState(isPlaying);
  }

  void _updateInlineControlsForPlaybackState(bool isPlaying) {
    _inlineControlsHideTimer?.cancel();
    if (!mounted) {
      return;
    }
    if (!isPlaying) {
      return;
    }
    if (_supportsHoverControls) {
      return;
    }
    _inlineControlsHideTimer = Timer(_transportAutoHideDelay, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showInlineControls = false;
      });
    });
  }

  void _showInlineTransportControls({bool autoHideIfPlaying = true}) {
    _inlineControlsHideTimer?.cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      _showInlineControls = true;
    });
    if (autoHideIfPlaying && _isPlaying) {
      _updateInlineControlsForPlaybackState(true);
    }
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
  }

  Future<void> _seekRelative(int seconds) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    final current = controller.value.position;
    final target = current + Duration(seconds: seconds);
    final duration = controller.value.duration;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > duration ? duration : target);
    await controller.seekTo(clamped);
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final nextMuted = !_isMuted;
    await controller.setVolume(nextMuted ? 0 : 1);
    if (!mounted) {
      return;
    }
    setState(() => _isMuted = nextMuted);
  }

  Future<void> _lockPortrait() async {
    if (kIsWeb) {
      return;
    }
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<void> _restoreSystemChrome() async {
    if (kIsWeb) {
      return;
    }
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<void> _openFullscreen() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    _resumeAfterFullscreen = controller.value.isPlaying;

    setState(() => _fullscreenOpen = true);
    if (!kIsWeb) {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: <SystemUiOverlay>[],
      );
    }

    try {
      await controller.play();
      if (!mounted) {
        return;
      }
      await showGeneralDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        barrierColor: Colors.black,
        pageBuilder: (context, _, __) {
          return _FullscreenVideoDialog(
            controller: controller,
            title: widget.video.title,
            isMuted: _isMuted,
            onToggleMute: () async {
              await _toggleMute();
              return _isMuted;
            },
            onTogglePlayback: _togglePlayback,
            onSeekBack: () => _seekRelative(-10),
            onSeekForward: () => _seekRelative(10),
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() => _fullscreenOpen = false);
      }
      if (mounted) {
        await _lockPortrait();
      }
      if (mounted && _resumeAfterFullscreen && controller.value.isInitialized) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted || _controller != controller || !controller.value.isInitialized) {
            return;
          }
          await controller.play();
          if (mounted) {
            _syncPlaybackState();
          }
        });
      }
      _resumeAfterFullscreen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            MouseRegion(
              onEnter: _supportsHoverControls
                  ? (_) => setState(() => _showInlineControls = true)
                  : null,
              onExit: _supportsHoverControls
                  ? (_) => setState(() => _showInlineControls = false)
                  : null,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: controller == null
                    ? _buildVideoPlayerStack(
                        value: const VideoPlayerValue.uninitialized(),
                      )
                    : ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: controller,
                        builder: (context, value, _) {
                          return _buildVideoPlayerStack(value: value);
                        },
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => context.push(
                          '/profile/${widget.video.creatorId}',
                        ),
                        child: CircleAvatar(
                          radius: 24,
                          backgroundImage:
                              (widget.video.creatorAvatar ?? '').trim().isNotEmpty
                                  ? NetworkImage(
                                      UrlHelper.getPlatformUrl(
                                        widget.video.creatorAvatar!,
                                      ),
                                    )
                                  : null,
                          child: (widget.video.creatorAvatar ?? '')
                                  .trim()
                                  .isEmpty
                              ? Text(_initialFor(widget.video.creatorName))
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.video.title.trim().isEmpty
                                  ? 'Untitled Video'
                                  : widget.video.title,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.video.creatorName,
                              style: TextStyle(
                                color: Theme.of(context).hintColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.video.views} views · ${timeago.format(DateTime.parse(widget.video.createdAt))}',
                              style: TextStyle(
                                color: Theme.of(context).hintColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (widget.video.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      widget.video.description,
                      style: const TextStyle(height: 1.45),
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (widget.video.products.isNotEmpty) ...[
                    _TaggedProductsSection(products: widget.video.products),
                    const SizedBox(height: 24),
                  ] else
                    const SizedBox(height: 24),
                  _InlineVideoCommentsSection(videoId: widget.video.id),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayerStack({required VideoPlayerValue value}) {
    final controller = _controller;
    final liveReady = controller != null && value.isInitialized;
    final transportControlsVisible =
        _showInlineControls && liveReady && !_fullscreenOpen;
    final position = liveReady ? value.position : Duration.zero;
    final totalDuration = liveReady
        ? value.duration
        : Duration(
            seconds: _resolvedDuration > 0
                ? _resolvedDuration
                : widget.video.duration,
          );
    final clampedPosition =
        position > totalDuration ? totalDuration : position;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (liveReady && !_fullscreenOpen)
          VideoPlayer(controller)
        else
          Image.network(
            UrlHelper.getPlatformUrl(widget.video.thumbnail),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: const Icon(
                Icons.play_circle_outline,
                color: Colors.white70,
                size: 74,
              ),
            ),
          ),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: liveReady
                ? () {
                    if (_supportsHoverControls) {
                      return;
                    }
                    if (_showInlineControls) {
                      _inlineControlsHideTimer?.cancel();
                      setState(() {
                        _showInlineControls = false;
                      });
                    } else {
                      _showInlineTransportControls();
                    }
                  }
                : null,
            child: const SizedBox.expand(),
          ),
        ),
        if (transportControlsVisible)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.12),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.48),
                ],
              ),
            ),
          ),
        if (_initializing)
          const Center(
            child: CircularProgressIndicator(color: Colors.white),
          )
        else if (transportControlsVisible)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.12),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _OverlayCircleButton(
                      icon: Icons.replay_10,
                      onTap: () => _seekRelative(-10),
                    ),
                    const SizedBox(width: 18),
                    _OverlayCircleButton(
                      icon: value.isPlaying ? Icons.pause : Icons.play_arrow,
                      onTap: () async {
                        await _togglePlayback();
                        if (!mounted) {
                          return;
                        }
                        _showInlineTransportControls(autoHideIfPlaying: true);
                      },
                    ),
                    const SizedBox(width: 18),
                    _OverlayCircleButton(
                      icon: Icons.forward_10,
                      onTap: () => _seekRelative(10),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (liveReady && !_fullscreenOpen)
          Positioned(
            top: 12,
            left: 12,
            child: _OverlayCircleButton(
              icon: Icons.arrow_back,
              onTap: () => context.pop(),
            ),
          ),
        if (liveReady && !_fullscreenOpen)
          Positioned(
            top: 12,
            right: 12,
            child: Row(
              children: [
                _OverlayCircleButton(
                  icon: _isMuted
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  onTap: _toggleMute,
                ),
                const SizedBox(width: 10),
                _OverlayCircleButton(
                  icon: Icons.fullscreen,
                  onTap: _openFullscreen,
                ),
              ],
            ),
          ),
        if (liveReady && !_fullscreenOpen)
          Positioned(
            right: 12,
            bottom: 12,
            child: _DurationBadge(
              durationLabel:
                  '${_formatPlaybackDuration(clampedPosition)}/${_formatPlaybackDuration(totalDuration)}',
            ),
          ),
      ],
    );
  }
}

class _TaggedProductsSection extends StatelessWidget {
  const _TaggedProductsSection({required this.products});

  final List<ProductModel> products;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.shopping_bag_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tagged Products',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            TextButton(
              onPressed: () => content_sheets.showTaggedProductsSheet(
                context: context,
                products: products,
              ),
              child: Text('View all (${products.length})'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return _TaggedProductCard(product: products[index]);
            },
          ),
        ),
      ],
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

    return SizedBox(
      width: 212,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/shop/${product.id}'),
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: imageUrl.isEmpty
                      ? Container(
                          height: 82,
                          width: double.infinity,
                          color: Colors.black12,
                          alignment: Alignment.center,
                          child: const Icon(Icons.shopping_bag_outlined),
                        )
                      : Image.network(
                          imageUrl,
                          height: 82,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                ),
                const SizedBox(height: 10),
                Text(
                  product.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '\$${product.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                ProductCardSocialPreview(productId: product.id),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineVideoCommentsSection extends StatefulWidget {
  const _InlineVideoCommentsSection({required this.videoId});

  final String videoId;

  @override
  State<_InlineVideoCommentsSection> createState() =>
      _InlineVideoCommentsSectionState();
}

class _InlineVideoCommentsSectionState extends State<_InlineVideoCommentsSection> {
  late final ApiService _api;
  late final TextEditingController _commentController;
  List<ContentCommentModel> _comments = <ContentCommentModel>[];
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiService>();
    _commentController = TextEditingController();
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
      final comments = await _api.getVideoComments(widget.videoId);
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
      final comment = await _api.createVideoComment(
        videoId: widget.videoId,
        commentText: text,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _comments = <ContentCommentModel>[comment, ..._comments];
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.chat_bubble_outline, size: 20),
            const SizedBox(width: 8),
            Text(
              'Comments',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: _loading ? null : _loadComments,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _commentController,
          minLines: 1,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Write a comment',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            suffixIcon: Padding(
              padding: const EdgeInsets.all(6),
              child: IconButton.filled(
                onPressed: _submitting ? null : _submitComment,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null)
          Center(child: Text(_error!))
        else if (_comments.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              'No comments yet',
              textAlign: TextAlign.center,
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _comments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _InlineCommentTile(comment: _comments[index]),
          ),
      ],
    );
  }
}

class _InlineCommentTile extends StatelessWidget {
  const _InlineCommentTile({required this.comment});

  final ContentCommentModel comment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.24),
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
                ? Text(_initialFor(comment.username))
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
                  const _ConnectionBadge(),
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

class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Connection',
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FullscreenVideoDialog extends StatefulWidget {
  const _FullscreenVideoDialog({
    required this.controller,
    required this.title,
    required this.isMuted,
    required this.onToggleMute,
    required this.onTogglePlayback,
    required this.onSeekBack,
    required this.onSeekForward,
  });

  final VideoPlayerController controller;
  final String title;
  final bool isMuted;
  final Future<bool> Function() onToggleMute;
  final Future<void> Function() onTogglePlayback;
  final Future<void> Function() onSeekBack;
  final Future<void> Function() onSeekForward;

  @override
  State<_FullscreenVideoDialog> createState() => _FullscreenVideoDialogState();
}

class _FullscreenVideoDialogState extends State<_FullscreenVideoDialog> {
  static const Duration _transportAutoHideDelay = Duration(seconds: 2);

  late bool _isMuted;
  bool _showTransportControls = true;
  Timer? _transportHideTimer;
  bool _lastIsPlaying = false;

  @override
  void initState() {
    super.initState();
    _isMuted = widget.isMuted;
    _lastIsPlaying = widget.controller.value.isPlaying;
    widget.controller.addListener(_handleControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !widget.controller.value.isInitialized) {
        return;
      }
      await widget.controller.play();
      if (mounted) {
        setState(() {});
        _updateTransportVisibility(widget.controller.value.isPlaying);
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _transportHideTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleToggleMute() async {
    final nextMuted = await widget.onToggleMute();
    if (!mounted) {
      return;
    }
    setState(() {
      _isMuted = nextMuted;
    });
  }

  void _updateTransportVisibility(bool isPlaying) {
    _transportHideTimer?.cancel();
    if (!mounted) {
      return;
    }
    if (!isPlaying) {
      setState(() {
        _showTransportControls = true;
      });
      return;
    }
    _transportHideTimer = Timer(_transportAutoHideDelay, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showTransportControls = false;
      });
    });
  }

  void _showFullscreenTransportControls({bool autoHideIfPlaying = true}) {
    _transportHideTimer?.cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      _showTransportControls = true;
    });
    if (autoHideIfPlaying && widget.controller.value.isPlaying) {
      _updateTransportVisibility(true);
    }
  }

  void _handleControllerChanged() {
    final isPlaying = widget.controller.value.isPlaying;
    if (!mounted || _lastIsPlaying == isPlaying) {
      return;
    }
    _lastIsPlaying = isPlaying;
    _updateTransportVisibility(isPlaying);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final size = controller.value.size;
    final aspectRatio = size.height > 0 ? size.width / size.height : 16 / 9;

    return Material(
      color: Colors.black,
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final duration = value.duration;
          final position = value.position > duration ? duration : value.position;
          final totalSeconds = duration.inSeconds;
          final currentSeconds = position.inSeconds.clamp(
            0,
            totalSeconds > 0 ? totalSeconds : 0,
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_showTransportControls) {
                    _transportHideTimer?.cancel();
                    setState(() {
                      _showTransportControls = false;
                    });
                  } else {
                    _showFullscreenTransportControls();
                  }
                },
                child: Center(
                  child: AspectRatio(
                    aspectRatio: aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title.trim().isEmpty ? 'Video' : widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _OverlayCircleButton(
                      icon: _isMuted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      onTap: () => unawaited(_handleToggleMute()),
                    ),
                    const SizedBox(width: 10),
                    _OverlayCircleButton(
                      icon: Icons.fullscreen_exit,
                      onTap: () =>
                          Navigator.of(context, rootNavigator: true).pop(),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 28,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_showTransportControls) ...[
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                        ),
                        child: Slider(
                          value: totalSeconds <= 0 ? 0 : currentSeconds.toDouble(),
                          min: 0,
                          max: totalSeconds <= 0 ? 1 : totalSeconds.toDouble(),
                          onChanged: totalSeconds <= 0
                              ? null
                              : (nextValue) => controller.seekTo(
                                    Duration(seconds: nextValue.round()),
                                  ),
                      ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: [
                            Text(
                              _formatPlaybackDuration(position),
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const Spacer(),
                            Text(
                              _formatPlaybackDuration(duration),
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_showTransportControls)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _OverlayCircleButton(
                            icon: Icons.replay_10,
                            onTap: () => unawaited(widget.onSeekBack()),
                          ),
                          const SizedBox(width: 18),
                          _OverlayCircleButton(
                            icon: value.isPlaying ? Icons.pause : Icons.play_arrow,
                            onTap: () async {
                              await widget.onTogglePlayback();
                              if (!mounted) {
                                return;
                              }
                              _showFullscreenTransportControls(
                                autoHideIfPlaying: true,
                              );
                            },
                          ),
                          const SizedBox(width: 18),
                          _OverlayCircleButton(
                            icon: Icons.forward_10,
                            onTap: () => unawaited(widget.onSeekForward()),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (!_showTransportControls)
                Positioned(
                  right: 24,
                  bottom: 28,
                  child: _DurationBadge(
                    durationLabel:
                        '${_formatPlaybackDuration(position)}/${_formatPlaybackDuration(duration)}',
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _OverlayCircleButton extends StatelessWidget {
  const _OverlayCircleButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _DurationBadge extends StatelessWidget {
  const _DurationBadge({required this.durationLabel});

  final String durationLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        durationLabel,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _formatDuration(int totalSeconds) {
  final duration = Duration(seconds: totalSeconds.clamp(0, 359999));
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:$minutes:$seconds';
  }
  return '${duration.inMinutes}:$seconds';
}

String _formatPlaybackDuration(Duration duration) {
  final totalSeconds = duration.inSeconds.clamp(0, 359999);
  return _formatDuration(totalSeconds);
}

String _initialFor(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return 'U';
  }
  return trimmed[0].toUpperCase();
}
