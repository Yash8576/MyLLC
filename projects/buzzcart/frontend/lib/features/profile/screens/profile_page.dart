import 'dart:async';
import 'dart:math' as math;
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/providers/app_refresh_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/models.dart';
import '../../../core/utils/url_helper.dart';

class ProfilePage extends StatefulWidget {
  final String? userId;

  const ProfilePage({super.key, this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  static final Map<String, _CachedProfileScreenState> _profileScreenCache =
      <String, _CachedProfileScreenState>{};
  static final Map<String, ImageProvider> _imageProviderCache =
      <String, ImageProvider>{};

  final ApiService _api = ApiService();
  final ImagePicker _picker = ImagePicker();
  late TabController _tabController;
  List<MediaItem> _photos = [];
  List<MediaItem> _videos = [];
  List<MediaItem> _reels = [];
  List<ProductModel> _products = [];
  bool _loading = true;
  bool _isAvatarUpdating = false;
  bool _isRelationshipUpdating = false;
  final Set<String> _deletingItemIds = <String>{};
  int _avatarVersion = 0;
  String? _localAvatarPreviewPath;
  Uint8List? _localAvatarPreviewBytes;
  Map<String, dynamic>? _profileUser;
  AppRefreshProvider? _appRefreshProvider;
  int _lastContentVersion = 0;
  int _lastProductVersion = 0;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 4, vsync: this); // Changed from 3 to 4
    _fetchUserContent();
  }

  @override
  void dispose() {
    _appRefreshProvider?.removeListener(_handleAppRefresh);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<AppRefreshProvider>();
    if (!identical(_appRefreshProvider, provider)) {
      _appRefreshProvider?.removeListener(_handleAppRefresh);
      _appRefreshProvider = provider;
      _lastContentVersion = provider.contentVersion;
      _lastProductVersion = provider.productVersion;
      provider.addListener(_handleAppRefresh);
    }
  }

  void _handleAppRefresh() {
    final provider = _appRefreshProvider;
    if (provider == null) {
      return;
    }

    final didContentChange = provider.contentVersion != _lastContentVersion;
    final didProductChange = provider.productVersion != _lastProductVersion;
    if (!didContentChange && !didProductChange) {
      return;
    }

    _lastContentVersion = provider.contentVersion;
    _lastProductVersion = provider.productVersion;

    if (!mounted) {
      return;
    }
    _fetchUserContent(forceRefresh: true);
  }

  Future<void> _refreshProfileContent() async {
    await _fetchUserContent(forceRefresh: true);
  }

  Map<String, dynamic> _userToProfileJson(UserModel user) {
    final profileJson = user.toJson();
    profileJson['privacy_profile'] = user.privacyProfile.toLowerCase();
    profileJson['visibility_mode'] = user.visibilityMode.toLowerCase();
    profileJson['visibility_preferences'] = user.visibilityPreferences;
    return profileJson;
  }

  void _hydrateFromCachedState(
    _CachedProfileScreenState cached, {
    required bool isOwnProfile,
    required UserModel currentUser,
  }) {
    _profileUser = isOwnProfile
        ? _userToProfileJson(currentUser)
        : Map<String, dynamic>.from(cached.profileUser);
    _photos = List<MediaItem>.from(cached.photos);
    _videos = List<MediaItem>.from(cached.videos);
    _reels = List<MediaItem>.from(cached.reels);
    _products = List<ProductModel>.from(cached.products);
  }

  void _storeCurrentProfileCache() {
    final currentUser = context.read<AuthProvider>().user;
    final targetUserId = widget.userId ?? currentUser?.id;
    if (targetUserId == null || _profileUser == null) {
      return;
    }

    final isOwnProfile = currentUser != null && targetUserId == currentUser.id;
    final profileUser = isOwnProfile
        ? _userToProfileJson(currentUser)
        : Map<String, dynamic>.from(_profileUser!);

    _profileScreenCache[targetUserId] = _CachedProfileScreenState(
      profileUser: Map<String, dynamic>.from(profileUser),
      photos: List<MediaItem>.from(_photos),
      videos: List<MediaItem>.from(_videos),
      reels: List<MediaItem>.from(_reels),
      products: List<ProductModel>.from(_products),
    );
  }

  ImageProvider _cachedNetworkImageProvider(String imageUrl) {
    final resolvedUrl = UrlHelper.getPlatformUrl(imageUrl);
    return _imageProviderCache.putIfAbsent(
      resolvedUrl,
      () => CachedNetworkImageProvider(resolvedUrl),
    );
  }

  String? _preferredReelThumbnail(MediaItem reel) {
    final thumbnail = reel.thumbnailUrl?.trim();
    if (thumbnail != null &&
        thumbnail.isNotEmpty &&
        thumbnail != reel.mediaUrl.trim()) {
      return thumbnail;
    }
    return null;
  }

  int _responsiveGridCount(
    double maxWidth, {
    required double targetTileWidth,
    required int minCount,
  }) {
    final availableWidth = maxWidth.isFinite ? maxWidth : 0;
    if (availableWidth <= 0) {
      return minCount;
    }
    return math.max(minCount, (availableWidth / targetTileWidth).floor());
  }

  void _warmVisibleProfileImages() {
    if (!mounted) {
      return;
    }

    final urls = <String>{
      for (final photo in _photos.take(18))
        if (photo.mediaUrl.trim().isNotEmpty) photo.mediaUrl.trim(),
      for (final video in _videos.take(12))
        if ((video.thumbnailUrl ?? video.mediaUrl).trim().isNotEmpty)
          (video.thumbnailUrl ?? video.mediaUrl).trim(),
      for (final reel in _reels.take(12))
        if ((_preferredReelThumbnail(reel) ?? '').trim().isNotEmpty)
          _preferredReelThumbnail(reel)!.trim(),
      for (final product in _products.take(12))
        if (product.images.isNotEmpty && product.images.first.trim().isNotEmpty)
          product.images.first.trim(),
    };

    for (final url in urls) {
      final provider = _cachedNetworkImageProvider(url);
      unawaited(precacheImage(provider, context));
    }
  }

  Future<void> _fetchUserContent({bool forceRefresh = false}) async {
    debugPrint('Fetching user content...');

    final currentUser = context.read<AuthProvider>().user;
    if (currentUser == null) {
      debugPrint('No user found');
      setState(() => _loading = false);
      return;
    }

    // Determine which user profile to fetch
    final targetUserId = widget.userId ?? currentUser.id;
    final isOwnProfile = targetUserId == currentUser.id;

    debugPrint(
        'Fetching content for user: $targetUserId (own profile: $isOwnProfile)');

    if (!forceRefresh) {
      final cached = _profileScreenCache[targetUserId];
      if (cached != null) {
        setState(() {
          _hydrateFromCachedState(
            cached,
            isOwnProfile: isOwnProfile,
            currentUser: currentUser,
          );
          _loading = false;
        });
        debugPrint('Hydrated profile from cache for user: $targetUserId');
        return;
      }
    }

    setState(() => _loading = true);

    // If viewing another user's profile, fetch their user info
    if (!isOwnProfile && widget.userId != null) {
      try {
        final userModel = await _api.getUser(widget.userId!);
        _profileUser = _userToProfileJson(userModel);
        debugPrint('Fetched profile user: ${_profileUser?['name']}');
      } catch (e) {
        debugPrint('Error fetching user profile: $e');
        setState(() => _loading = false);
        return;
      }
    } else {
      _profileUser = _userToProfileJson(currentUser);
    }

    final isSellerProfile = isOwnProfile
        ? currentUser.isSeller
        : (_profileUser?['account_type']?.toString().toLowerCase() ==
                'seller' ||
            _profileUser?['role']?.toString().toLowerCase() == 'seller');

    final canViewPhotos =
        isOwnProfile || _isBucketVisible('photos', isOwnProfile: false);
    final canViewVideos =
        isOwnProfile || _isBucketVisible('videos', isOwnProfile: false);
    final canViewReels =
        isOwnProfile || _isBucketVisible('reels', isOwnProfile: false);
    final canViewPurchases =
        isOwnProfile || _isBucketVisible('purchases', isOwnProfile: false);

    // Fetch each type independently to prevent one failure from blocking others
    final photos = canViewPhotos
        ? await _api.getUserMedia(targetUserId, type: 'photo').catchError((e) {
            debugPrint('Error fetching photos: $e');
            return <MediaItem>[];
          })
        : <MediaItem>[];

    final videos = canViewVideos
        ? await _api.getUserMedia(targetUserId, type: 'video').catchError((e) {
            debugPrint('Error fetching videos: $e');
            return <MediaItem>[];
          })
        : <MediaItem>[];

    final reels = canViewReels
        ? await _api.getUserMedia(targetUserId, type: 'reel').catchError((e) {
            debugPrint('Error fetching reels: $e');
            return <MediaItem>[];
          })
        : <MediaItem>[];

    final products = canViewPurchases
        ? (!isSellerProfile)
            ? await _api.getUserPurchases(targetUserId).catchError((e) {
                debugPrint('Error fetching user purchases: $e');
                return <ProductModel>[];
              })
            : await _api.getSellerProducts(targetUserId).catchError((e) {
                debugPrint('Error fetching products: $e');
                return <ProductModel>[];
              })
        : <ProductModel>[];

    debugPrint(
        'Fetch complete - Photos: ${photos.length}, Videos: ${videos.length}, Reels: ${reels.length}, Products: ${products.length}');

    setState(() {
      _photos = photos;
      _videos = videos;
      _reels = reels;
      _products = products;
      _loading = false;
    });
    _storeCurrentProfileCache();
    _warmVisibleProfileImages();

    debugPrint('State updated - Photos count: ${_photos.length}');
  }

  Future<void> _handleFollowAction() async {
    final authProvider = context.read<AuthProvider>();
    final currentUser = context.read<AuthProvider>().user;
    final targetUserId = widget.userId;
    if (currentUser == null ||
        targetUserId == null ||
        _isRelationshipUpdating) {
      return;
    }

    final isFollowing = _profileUser?['is_following'] == true;
    if (isFollowing) {
      final shouldUnfollow = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unfollow user?'),
          content: const Text('Do you want to unfollow this user?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Unfollow'),
            ),
          ],
        ),
      );
      if (shouldUnfollow != true) {
        return;
      }
    }

    setState(() => _isRelationshipUpdating = true);
    try {
      if (isFollowing) {
        await _api.unfollowUser(targetUserId);
      } else {
        await _api.followUser(targetUserId);
      }
      await authProvider.refreshUser();
      if (!mounted) {
        return;
      }
      final updatedProfile = Map<String, dynamic>.from(_profileUser ?? {});
      final currentFollowers = (updatedProfile['followers_count'] as int? ?? 0);
      final nextIsFollowing = !isFollowing;
      updatedProfile['is_following'] = nextIsFollowing;
      updatedProfile['followers_count'] = nextIsFollowing
          ? currentFollowers + 1
          : (currentFollowers > 0 ? currentFollowers - 1 : 0);
      updatedProfile['is_connection'] =
          nextIsFollowing && updatedProfile['is_followed_by'] == true;
      setState(() {
        _profileUser = updatedProfile;
      });
      _storeCurrentProfileCache();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFollowing ? 'Failed to unfollow user' : 'Failed to follow user',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isRelationshipUpdating = false);
      }
    }
  }

  Future<void> _showSocialUsers({
    required String title,
    required bool followers,
  }) async {
    final currentUser = context.read<AuthProvider>().user;
    if (currentUser == null) {
      return;
    }

    final targetUserId = widget.userId ?? currentUser.id;

    try {
      final users = followers
          ? await _api.getFollowers(targetUserId)
          : await _api.getFollowing(targetUserId);

      if (!mounted) {
        return;
      }

      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) {
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.72,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: users.isEmpty
                        ? const Center(
                            child: Text('No users in this list yet'),
                          )
                        : ListView.separated(
                            itemCount: users.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final user = users[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage:
                                      (user.avatar ?? '').isNotEmpty
                                          ? _cachedImageProvider(user.avatar)
                                          : null,
                                  child: (user.avatar ?? '').isEmpty
                                      ? Text(
                                          user.name.isEmpty
                                              ? '?'
                                              : user.name[0].toUpperCase(),
                                        )
                                      : null,
                                ),
                                title: Text(user.name),
                                subtitle: user.bio.isNotEmpty
                                    ? Text(
                                        user.bio,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : null,
                                trailing: user.isConnection
                                    ? const Icon(
                                        Icons.people_alt_outlined,
                                        size: 18,
                                      )
                                    : null,
                                onTap: () {
                                  Navigator.of(context).pop();
                                  context.push('/profile/${user.id}');
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } on DioException catch (e) {
      if (!mounted) {
        return;
      }
      final message = e.response?.statusCode == 403
          ? 'This list is private'
          : 'Failed to load $title';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load $title')),
      );
    }
  }

  bool _isDeleting(String key) => _deletingItemIds.contains(key);

  Future<bool> _confirmDelete(String itemLabel) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $itemLabel?'),
        content: Text(
            'This will permanently remove this $itemLabel from your published content.'),
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

    return shouldDelete == true;
  }

  Future<void> _deleteMediaItem(MediaItem item) async {
    final itemLabel = switch (item.mediaType.toLowerCase()) {
      'photo' => 'photo post',
      'video' => 'video',
      'reel' => 'reel',
      _ => 'item',
    };

    if (!await _confirmDelete(itemLabel) || !mounted) {
      return;
    }

    final deletingKey = 'media:${item.id}';
    setState(() => _deletingItemIds.add(deletingKey));

    try {
      await _api.deleteUserMedia(item.id);
      if (!mounted) {
        return;
      }

      setState(() {
        switch (item.mediaType.toLowerCase()) {
          case 'photo':
            _photos.removeWhere((media) => media.id == item.id);
            break;
          case 'video':
            _videos.removeWhere((media) => media.id == item.id);
            break;
          case 'reel':
            _reels.removeWhere((media) => media.id == item.id);
            break;
        }
        _deletingItemIds.remove(deletingKey);
      });
      _storeCurrentProfileCache();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_capitalizeLabel(itemLabel)} deleted')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _deletingItemIds.remove(deletingKey));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete $itemLabel')),
      );
    }
  }

  Future<void> _deleteProduct(ProductModel product) async {
    if (!await _confirmDelete('product') || !mounted) {
      return;
    }

    final deletingKey = 'product:${product.id}';
    setState(() => _deletingItemIds.add(deletingKey));

    try {
      await _api.deleteProduct(product.id);
      if (!mounted) {
        return;
      }

      setState(() {
        _products.removeWhere((item) => item.id == product.id);
        _deletingItemIds.remove(deletingKey);
      });
      _storeCurrentProfileCache();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _deletingItemIds.remove(deletingKey));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete product')),
      );
    }
  }

  Future<void> _manageProduct(ProductModel product) async {
    final result = await context.push('/add-product', extra: product);
    if (!mounted) {
      return;
    }
    if (result == true) {
      await _fetchUserContent(forceRefresh: true);
    }
  }

  void _previewOwnProduct(ProductModel product) {
    context.push('/shop/${product.id}?own_preview=1');
  }

  String _capitalizeLabel(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value[0].toUpperCase() + value.substring(1);
  }

  double _effectiveProductRating(ProductModel product) {
    return product.rating;
  }

  String _formatProductRating(ProductModel product) {
    final effectiveRating = _effectiveProductRating(product);
    if (effectiveRating <= 0 || product.reviewsCount <= 0) {
      return 'No ratings';
    }
    return '${effectiveRating.toStringAsFixed(1)} (${product.reviewsCount})';
  }

  int? _yourProductRating(ProductModel product) {
    final raw = product.metadata['your_rating'];
    if (raw is num && raw > 0) {
      return raw.toInt();
    }
    final parsed = int.tryParse('${raw ?? ''}');
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  String _formatPurchaseRelativeTime(String value) {
    DateTime purchasedAt;
    try {
      purchasedAt = DateTime.parse(value).toLocal();
    } catch (_) {
      return 'just now';
    }

    final now = DateTime.now();
    final difference = now.difference(purchasedAt);

    if (difference.inSeconds < 60) {
      final seconds = difference.inSeconds <= 0 ? 1 : difference.inSeconds;
      return '$seconds ${seconds == 1 ? 'second' : 'seconds'} ago';
    }
    if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    }
    if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    }
    if (difference.inDays < 30) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    }
    if (difference.inDays < 365) {
      final months = difference.inDays ~/ 30;
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    }

    final years = difference.inDays ~/ 365;
    return '$years ${years == 1 ? 'year' : 'years'} ago';
  }

  String _formatPurchaseTimeline(ProductModel product) {
    final count = product.buys < 0 ? 0 : product.buys;
    return 'Bought $count ${count == 1 ? 'time' : 'times'} ${_formatPurchaseRelativeTime(product.createdAt)}';
  }

  Widget _buildProductMetricChip({
    required IconData icon,
    required String label,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? Theme.of(context).colorScheme.surfaceContainerHighest)
            .withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildProductOwnerSummary() {
    final totalBuys =
        _products.fold<int>(0, (sum, product) => sum + product.buys);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: _buildOwnerMetricCard(
              label: 'Total Purchases',
              value: '$totalBuys',
              icon: Icons.shopping_bag_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerMetricCard({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteOverlay({
    required VoidCallback onDelete,
    required bool isDeleting,
  }) {
    return Positioned(
      top: 8,
      right: 8,
      child: Material(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: isDeleting ? null : onDelete,
          borderRadius: BorderRadius.circular(999),
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
    );
  }

  void _openMessages() {
    final displayUser = _profileUser;
    if (displayUser == null) {
      return;
    }
    context.push(
      '/messages',
      extra: MessagesRouteIntent(
        participant: MessageParticipantModel(
          id: displayUser['id'] as String,
          name: (displayUser['name'] ?? 'Unknown').toString(),
          avatar: displayUser['avatar'] as String?,
        ),
      ),
    );
  }

  Future<void> _showEditProfileDialog() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    if (user == null) return;

    final nameController = TextEditingController(text: user.name);
    final didSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final updatedName = nameController.text.trim();
              if (updatedName.isEmpty) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Name cannot be empty')),
                );
                return;
              }

              try {
                await authProvider.updateProfile({'name': updatedName});
                if (!mounted) {
                  return;
                }
                setState(() {
                  _profileUser = _userToProfileJson(authProvider.user!);
                });
                _storeCurrentProfileCache();
                navigator.pop(true);
              } catch (e) {
                if (!mounted) {
                  return;
                }
                messenger.showSnackBar(
                  SnackBar(content: Text('Failed to update profile: $e')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    nameController.dispose();

    if (didSave == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated!')),
      );
    }
  }

  Future<void> _showAvatarEditOptions() async {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.user;
    final isOwnProfile =
        widget.userId == null || widget.userId == currentUser?.id;
    if (!isOwnProfile || currentUser == null || _isAvatarUpdating) {
      return;
    }

    final hasAvatar = (_localAvatarPreviewPath != null &&
            _previewPathExists(_localAvatarPreviewPath)) ||
        _hasLocalPreviewBytes() ||
        (authProvider.pendingAvatarPreviewPath != null &&
            _previewPathExists(authProvider.pendingAvatarPreviewPath)) ||
        (currentUser.avatar ?? '').trim().isNotEmpty;

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.14),
                  child: Icon(
                    Icons.edit,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Edit Profile Photo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Choose from library'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadAvatar();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: const Text('Browse files (cloud apps)'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickFromCloudAndUploadAvatar();
                  },
                ),
                ListTile(
                  enabled: hasAvatar,
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Delete current photo'),
                  onTap: hasAvatar
                      ? () {
                          Navigator.pop(context);
                          _deleteCurrentAvatar();
                        }
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final pickedImage = await _picker.pickImage(
        source: ImageSource.gallery,
      );

      if (pickedImage == null || !mounted) {
        return;
      }
      await _cropAndUploadAvatar(pickedImage);
    } catch (e) {
      _showAvatarSnackBar('Failed to update profile photo: $e');
    }
  }

  Future<void> _pickFromCloudAndUploadAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'gif'],
        withData: true,
      );

      if (result == null || result.files.isEmpty || !mounted) {
        return;
      }

      final selected = result.files.first;
      XFile sourceFile;

      if (selected.path != null && selected.path!.isNotEmpty) {
        sourceFile = XFile(selected.path!);
      } else if (selected.bytes != null) {
        if (kIsWeb) {
          sourceFile = XFile.fromData(
            selected.bytes!,
            name: selected.name,
            mimeType: 'image/${_safeImageExtension(selected.name)}',
          );
        } else {
          final tempDir = Directory.systemTemp;
          final extension = _safeImageExtension(selected.name);
          final tempPath =
              '${tempDir.path}${Platform.pathSeparator}cloud_avatar_${DateTime.now().microsecondsSinceEpoch}.$extension';
          final tempFile = File(tempPath);
          await tempFile.writeAsBytes(selected.bytes!, flush: true);
          sourceFile = XFile(tempFile.path);
        }
      } else {
        _showAvatarSnackBar('Unable to open selected cloud photo');
        return;
      }

      if (!mounted) return;
      await _cropAndUploadAvatar(sourceFile);
    } catch (e) {
      _showAvatarSnackBar('Cloud picker failed: $e');
    }
  }

  void _showAvatarSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _cropAndUploadAvatar(XFile sourceImage) async {
    final authProvider = context.read<AuthProvider>();
    final primaryColor = Theme.of(context).primaryColor;
    final viewportSize = MediaQuery.sizeOf(context);
    final webCropWidth =
        (viewportSize.width * 0.82).clamp(320.0, 560.0).round();
    final webCropHeight =
        (viewportSize.height * 0.62).clamp(320.0, 520.0).round();

    try {
      final localImagePath = await _ensureLocalImagePath(sourceImage);
      if (!mounted) {
        return;
      }

      if (kIsWeb) {
        final uploadBytes = await sourceImage.readAsBytes();
        if (!mounted) {
          return;
        }

        setState(() {
          _isAvatarUpdating = true;
          _localAvatarPreviewBytes = uploadBytes;
          _localAvatarPreviewPath = null;
        });

        await authProvider.setPendingAvatarPreviewPath(null);
        final uploadResult = await _api.uploadAvatar(
          XFile.fromData(
            uploadBytes,
            name: sourceImage.name.isNotEmpty
                ? sourceImage.name
                : 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
            mimeType: 'image/${_safeImageExtension(sourceImage.name)}',
          ),
        );
        if (!mounted) {
          return;
        }

        debugPrint('[ProfileAvatar] uploadAvatar response: $uploadResult');

        final avatarUrl = uploadResult['avatar_url']?.toString();
        if (avatarUrl == null || avatarUrl.trim().isEmpty) {
          throw Exception('Avatar upload succeeded but no URL was returned');
        }

        authProvider.updateAvatarUrl(avatarUrl);
        if (!mounted) {
          return;
        }
        await authProvider.setPendingAvatarPreviewPath(null);
        if (!mounted) {
          return;
        }
        setState(() {
          _avatarVersion = DateTime.now().millisecondsSinceEpoch;
          _localAvatarPreviewBytes = null;
          _localAvatarPreviewPath = null;
          _profileUser = _userToProfileJson(authProvider.user!);
        });
        _storeCurrentProfileCache();

        _showAvatarSnackBar('Profile photo updated successfully');
        return;
      }

      if (!kIsWeb && Platform.isWindows) {
        setState(() {
          _isAvatarUpdating = true;
          _localAvatarPreviewPath = localImagePath;
          _localAvatarPreviewBytes = null;
        });

        final uploadResult = await _api.uploadAvatar(
          XFile(
            localImagePath,
            name: sourceImage.name.isNotEmpty
                ? sourceImage.name
                : 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
            mimeType: 'image/jpeg',
          ),
        );
        if (!mounted) {
          return;
        }

        debugPrint('[ProfileAvatar] uploadAvatar response: $uploadResult');

        final avatarUrl = uploadResult['avatar_url']?.toString();
        if (avatarUrl == null || avatarUrl.trim().isEmpty) {
          throw Exception('Avatar upload succeeded but no URL was returned');
        }

        authProvider.updateAvatarUrl(avatarUrl);
        if (!mounted) {
          return;
        }
        await authProvider.setPendingAvatarPreviewPath(null);
        if (!mounted) {
          return;
        }
        setState(() {
          _avatarVersion = DateTime.now().millisecondsSinceEpoch;
          _localAvatarPreviewBytes = null;
          _localAvatarPreviewPath = null;
          _profileUser = _userToProfileJson(authProvider.user!);
        });
        _storeCurrentProfileCache();

        _showAvatarSnackBar('Profile photo updated successfully');
        return;
      }

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: localImagePath,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Avatar',
            toolbarColor: primaryColor,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
            hideBottomControls: true,
            showCropGrid: false,
            cropStyle: CropStyle.circle,
          ),
          IOSUiSettings(
            title: 'Crop Avatar',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            cropStyle: CropStyle.circle,
          ),
          WebUiSettings(
            context: context,
            presentStyle: WebPresentStyle.dialog,
            size: CropperSize(width: webCropWidth, height: webCropHeight),
          ),
        ],
      );

      if (croppedFile == null || !mounted) {
        return;
      }

      setState(() {
        _isAvatarUpdating = true;
        _localAvatarPreviewPath = croppedFile.path;
        _localAvatarPreviewBytes = null;
      });
      final uploadBytes = await croppedFile.readAsBytes();
      if (!mounted) {
        return;
      }
      if (kIsWeb) {
        setState(() {
          _localAvatarPreviewBytes = uploadBytes;
          _localAvatarPreviewPath = null;
        });
        await authProvider.setPendingAvatarPreviewPath(null);
      } else {
        await authProvider.setPendingAvatarPreviewPath(croppedFile.path);
      }
      final uploadResult = await _api.uploadAvatar(
        XFile(
          croppedFile.path,
          name: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
          mimeType: 'image/jpeg',
        ),
      );
      if (!mounted) {
        return;
      }
      debugPrint('[ProfileAvatar] uploadAvatar response: $uploadResult');

      final avatarUrl = uploadResult['avatar_url']?.toString();
      if (avatarUrl == null || avatarUrl.trim().isEmpty) {
        throw Exception('Avatar upload succeeded but no URL was returned');
      }

      authProvider.updateAvatarUrl(avatarUrl);
      if (!mounted) {
        return;
      }
      await authProvider.setPendingAvatarPreviewPath(null);
      if (!mounted) {
        return;
      }
      setState(() {
        _avatarVersion = DateTime.now().millisecondsSinceEpoch;
        _localAvatarPreviewBytes = null;
        _localAvatarPreviewPath = null;
        _profileUser = _userToProfileJson(authProvider.user!);
      });
      _storeCurrentProfileCache();

      _showAvatarSnackBar('Profile photo updated successfully');
    } catch (e) {
      debugPrint('[ProfileAvatar] Upload failed: $e');
      _showAvatarSnackBar('Failed to update profile photo: $e');
    } finally {
      if (mounted) {
        setState(() => _isAvatarUpdating = false);
      }
    }
  }

  Future<void> _deleteCurrentAvatar() async {
    final authProvider = context.read<AuthProvider>();

    try {
      setState(() => _isAvatarUpdating = true);
      await _api.deleteAvatar();
      authProvider.updateAvatarUrl(null);
      setState(() {
        _avatarVersion = DateTime.now().millisecondsSinceEpoch;
        _localAvatarPreviewPath = null;
        _localAvatarPreviewBytes = null;
        if (authProvider.user != null) {
          _profileUser = _userToProfileJson(authProvider.user!);
        }
      });
      _storeCurrentProfileCache();

      _showAvatarSnackBar('Profile photo removed');
    } catch (e) {
      _showAvatarSnackBar('Failed to delete profile photo: $e');
    } finally {
      if (mounted) {
        setState(() => _isAvatarUpdating = false);
      }
    }
  }

  Future<String> _ensureLocalImagePath(XFile file) async {
    final originalPath = file.path;
    if (originalPath.isNotEmpty &&
        (kIsWeb || File(originalPath).existsSync())) {
      return originalPath;
    }

    if (kIsWeb) {
      throw Exception('Web image source is missing a usable path');
    }

    final bytes = await file.readAsBytes();
    final tempDir = Directory.systemTemp;
    final extension = _safeImageExtension(file.name);
    final tempPath =
        '${tempDir.path}${Platform.pathSeparator}avatar_${DateTime.now().microsecondsSinceEpoch}.$extension';
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(bytes, flush: true);
    return tempFile.path;
  }

  String _safeImageExtension(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    if (lower.endsWith('.gif')) return 'gif';
    return 'jpg';
  }

  Map<String, bool> _profileVisibilityPreferences() {
    final rawPreferences = _profileUser?['visibility_preferences'];
    final preferences = <String, bool>{
      'photos': true,
      'videos': true,
      'reels': true,
      'purchases': true,
    };

    if (rawPreferences is Map) {
      for (final entry in rawPreferences.entries) {
        preferences[entry.key.toString().toLowerCase()] = entry.value == true;
      }
    }

    return preferences;
  }

  String _profileVisibilityMode() {
    return (_profileUser?['visibility_mode']?.toString() ?? 'public')
        .toLowerCase();
  }

  bool _isBucketVisible(String bucket, {required bool isOwnProfile}) {
    if (isOwnProfile) return true;

    final visibilityMode = _profileVisibilityMode();
    if (visibilityMode == 'private') return false;
    if (visibilityMode != 'custom') return true;

    final preferences = _profileVisibilityPreferences();
    return preferences[bucket.toLowerCase()] ?? true;
  }

  Widget _buildHiddenSectionMessage(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildCachedImage(
    String imageUrl, {
    BoxFit fit = BoxFit.cover,
    Widget? errorWidget,
    double? width,
    double? height,
  }) {
    final provider = _cachedNetworkImageProvider(imageUrl);
    return Image(
      image: provider,
      fit: fit,
      width: width,
      height: height,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => errorWidget ?? const SizedBox.shrink(),
    );
  }

  ImageProvider? _cachedImageProvider(String? imageUrl) {
    final trimmed = imageUrl?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    return _cachedNetworkImageProvider(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.user;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(
          child: Text('Please log in to view your profile'),
        ),
      );
    }

    // Use profile user if viewing someone else's profile, otherwise use logged-in user
    final displayUser = _profileUser;
    final isOwnProfile =
        widget.userId == null || widget.userId == currentUser.id;
    final isSellerProfile = isOwnProfile
        ? currentUser.isSeller
        : (displayUser?['account_type']?.toString().toLowerCase() == 'seller' ||
            displayUser?['role']?.toString().toLowerCase() == 'seller');
    final productsTabLabel = isSellerProfile ? 'Products' : 'Purchases';
    final avatarRaw =
        (isOwnProfile ? currentUser.avatar : displayUser?['avatar'])
            ?.toString();
    final avatarUrl =
        avatarRaw != null && avatarRaw.trim().isNotEmpty ? avatarRaw : null;
    final avatarBaseUrl =
        avatarUrl == null ? null : UrlHelper.getPlatformUrl(avatarUrl);
    final avatarDisplayUrl = avatarBaseUrl == null
        ? null
        : '$avatarBaseUrl${avatarBaseUrl.contains('?') ? '&' : '?'}v=$_avatarVersion';
    final providerPreviewPath = authProvider.pendingAvatarPreviewPath;
    final hasLocalPreview = _localAvatarPreviewPath != null &&
        _previewPathExists(_localAvatarPreviewPath);
    final hasProviderPreview =
        providerPreviewPath != null && _previewPathExists(providerPreviewPath);
    ImageProvider? avatarImageProvider;
    if (_hasLocalPreviewBytes()) {
      avatarImageProvider = MemoryImage(_localAvatarPreviewBytes!);
    } else if (hasLocalPreview) {
      avatarImageProvider = FileImage(File(_localAvatarPreviewPath!));
    } else if (hasProviderPreview) {
      avatarImageProvider = FileImage(File(providerPreviewPath));
    } else if (avatarDisplayUrl != null) {
      avatarImageProvider = CachedNetworkImageProvider(avatarDisplayUrl);
    }
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    final postsCount = _photos.length + _videos.length + _reels.length;
    final isFollowing = displayUser?['is_following'] == true;
    final isConnection = displayUser?['is_connection'] == true;

    // If loading and no profile user data yet
    if (_loading && displayUser == null && !isOwnProfile) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshProfileContent,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (isDesktop)
              SliverAppBar(
                pinned: true,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                title: Text(
                  isOwnProfile
                      ? 'Profile'
                      : (displayUser?['name'] ?? 'Profile'),
                ),
                actions: [
                  if (isOwnProfile)
                    IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: () => context.push('/settings'),
                    ),
                ],
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, isDesktop ? 12 : 2, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onLongPress:
                              isOwnProfile ? _showAvatarEditOptions : null,
                          child: SizedBox(
                            width: 84,
                            height: 84,
                            child: Stack(
                              children: [
                                Container(
                                  width: 84,
                                  height: 84,
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .scaffoldBackgroundColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: ClipOval(
                                    child: _buildAvatarImage(
                                      imageProvider: avatarImageProvider,
                                      fallbackText: (isOwnProfile
                                                  ? currentUser.name
                                                  : displayUser?['name'] ?? '')
                                              .toString()
                                              .isNotEmpty
                                          ? (isOwnProfile
                                                  ? currentUser.name
                                                  : displayUser?['name'])
                                              .toString()[0]
                                              .toUpperCase()
                                          : 'U',
                                    ),
                                  ),
                                ),
                                if (isOwnProfile)
                                  Positioned(
                                    right: 2,
                                    bottom: 2,
                                    child: Material(
                                      color: Colors.grey.shade200,
                                      shape: const CircleBorder(),
                                      child: InkWell(
                                        onTap: _showAvatarEditOptions,
                                        customBorder: const CircleBorder(),
                                        child: const Padding(
                                          padding: EdgeInsets.all(5),
                                          child: Icon(
                                            Icons.edit,
                                            size: 13,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (_isAvatarUpdating)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black
                                            .withValues(alpha: 0.35),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SizedBox(
                            height: 84,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(6, 8, 0, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    isOwnProfile
                                        ? currentUser.name
                                        : (displayUser?['name'] ?? ''),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: _StatItem(
                                          label: 'Posts',
                                          count: postsCount,
                                        ),
                                      ),
                                      Expanded(
                                        child: _StatItem(
                                          label: 'Followers',
                                          count: isOwnProfile
                                              ? currentUser.followersCount
                                              : (displayUser?[
                                                      'followers_count'] ??
                                                  0),
                                          onTap: () => _showSocialUsers(
                                            title: 'Followers',
                                            followers: true,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: _StatItem(
                                          label: 'Following',
                                          count: isOwnProfile
                                              ? currentUser.followingCount
                                              : (displayUser?[
                                                      'following_count'] ??
                                                  0),
                                          onTap: () => _showSocialUsers(
                                            title: 'Following',
                                            followers: false,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (isOwnProfile) ...[
                          Expanded(
                            child: _buildProfileActionButton(
                              onPressed: _showEditProfileDialog,
                              label: 'Edit Profile',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildProfileActionButton(
                              onPressed: () {},
                              label: 'Share',
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isRelationshipUpdating
                                  ? null
                                  : _handleFollowAction,
                              icon: _isRelationshipUpdating
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(
                                      isFollowing
                                          ? Icons.check_circle_outline
                                          : Icons.person_add,
                                    ),
                              label: Text(isFollowing ? 'Following' : 'Follow'),
                            ),
                          ),
                          if (isConnection) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _openMessages,
                                icon: const Icon(Icons.message),
                                label: const Text('Message'),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                TabBar(
                  controller: _tabController,
                  tabs: [
                    const Tab(text: 'Photos'),
                    const Tab(text: 'Videos'),
                    const Tab(text: 'Reels'),
                    Tab(text: productsTabLabel),
                  ],
                ),
              ),
            ),
            SliverFillRemaining(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPhotosGrid(),
                  _buildVideosGrid(),
                  _buildReelsGrid(),
                  _buildProductsGrid(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarImage({
    required ImageProvider? imageProvider,
    required String fallbackText,
  }) {
    if (imageProvider == null) {
      return Container(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
        alignment: Alignment.center,
        child: Text(
          fallbackText,
          style: const TextStyle(fontSize: 28),
        ),
      );
    }

    return Image(
      image: imageProvider,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
          alignment: Alignment.center,
          child: Text(
            fallbackText,
            style: const TextStyle(fontSize: 28),
          ),
        );
      },
    );
  }

  bool _previewPathExists(String? path) {
    if (path == null || path.isEmpty || kIsWeb) {
      return false;
    }
    return File(path).existsSync();
  }

  bool _hasLocalPreviewBytes() {
    return _localAvatarPreviewBytes != null &&
        _localAvatarPreviewBytes!.isNotEmpty;
  }

  Widget _buildPhotosGrid() {
    debugPrint(
        'Building photos grid - Loading: $_loading, Photos: ${_photos.length}');

    final currentUser = context.read<AuthProvider>().user;
    final isOwnProfile =
        widget.userId == null || widget.userId == currentUser?.id;
    final isPrivate = _profileUser?['privacy_profile'] == 'private';
    final bucketVisible =
        _isBucketVisible('photos', isOwnProfile: isOwnProfile);

    if (_loading) return const Center(child: CircularProgressIndicator());

    // Show private account message if not own profile and account is private and no content
    if (!isOwnProfile && isPrivate && _photos.isEmpty) {
      return _buildHiddenSectionMessage(
        'This Account is Private',
        'Follow this account to see their photos',
      );
    }

    if (!isOwnProfile && !bucketVisible) {
      return _buildHiddenSectionMessage(
        'Photos are Private',
        'This user chose to hide their photos',
      );
    }

    if (_photos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.photo_library_outlined,
                size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No photos yet'),
            if (isOwnProfile) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchUserContent,
                child: const Text('Refresh'),
              ),
            ],
          ],
        ),
      );
    }
    debugPrint('Rendering ${_photos.length} photos');
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _responsiveGridCount(
          constraints.maxWidth,
          targetTileWidth: 130,
          minCount: 3,
        );
        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: _photos.length,
          itemBuilder: (context, index) {
            final photo = _photos[index];
            final deletingKey = 'media:${photo.id}';
            debugPrint('Building photo $index: ${photo.mediaUrl}');
            return InkWell(
              onTap: _isDeleting(deletingKey)
                  ? null
                  : () {
                      showDialog(
                        context: context,
                        builder: (context) => Dialog(
                          backgroundColor: Colors.transparent,
                          child: Stack(
                            children: [
                              Center(
                                child: _buildCachedImage(
                                  photo.mediaUrl,
                                  fit: BoxFit.contain,
                                  errorWidget: const Center(
                                    child: Icon(Icons.broken_image,
                                        size: 64, color: Colors.white),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 40,
                                right: 20,
                                child: IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.white, size: 30),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: _isDeleting(deletingKey) ? 0.45 : 1,
                    child: _buildCachedImage(
                      photo.mediaUrl,
                      fit: BoxFit.cover,
                      errorWidget: Container(
                        color: Colors.grey[300],
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, color: Colors.grey, size: 32),
                            SizedBox(height: 4),
                            Text('Error',
                                style: TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (isOwnProfile)
                    _buildDeleteOverlay(
                      onDelete: () => _deleteMediaItem(photo),
                      isDeleting: _isDeleting(deletingKey),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildVideosGrid() {
    final currentUser = context.read<AuthProvider>().user;
    final isOwnProfile =
        widget.userId == null || widget.userId == currentUser?.id;
    final isPrivate = _profileUser?['privacy_profile'] == 'private';
    final bucketVisible =
        _isBucketVisible('videos', isOwnProfile: isOwnProfile);

    if (_loading) return const Center(child: CircularProgressIndicator());

    // Show private account message if not own profile and account is private and no content
    if (!isOwnProfile && isPrivate && _videos.isEmpty) {
      return _buildHiddenSectionMessage(
        'This Account is Private',
        'Follow this account to see their videos',
      );
    }

    if (!isOwnProfile && !bucketVisible) {
      return _buildHiddenSectionMessage(
        'Videos are Private',
        'This user chose to hide their videos',
      );
    }

    if (_videos.isEmpty) {
      return const Center(child: Text('No videos yet'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 16 / 12,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        final video = _videos[index];
        final deletingKey = 'media:${video.id}';
        final targetVideoId = (video.contentId?.trim().isNotEmpty ?? false)
            ? video.contentId!
            : video.id;
        return InkWell(
          onTap: _isDeleting(deletingKey)
              ? null
              : () => context.push('/videos/$targetVideoId'),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: _isDeleting(deletingKey) ? 0.45 : 1,
                child: _buildCachedImage(
                  video.thumbnailUrl ?? video.mediaUrl,
                  fit: BoxFit.cover,
                  errorWidget: Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.video_library, size: 48),
                  ),
                ),
              ),
              const Center(
                child:
                    Icon(Icons.play_circle_fill, color: Colors.white, size: 48),
              ),
              if (isOwnProfile)
                _buildDeleteOverlay(
                  onDelete: () => _deleteMediaItem(video),
                  isDeleting: _isDeleting(deletingKey),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReelsGrid() {
    final currentUser = context.read<AuthProvider>().user;
    final isOwnProfile =
        widget.userId == null || widget.userId == currentUser?.id;
    final isPrivate = _profileUser?['privacy_profile'] == 'private';
    final bucketVisible = _isBucketVisible('reels', isOwnProfile: isOwnProfile);

    if (_loading) return const Center(child: CircularProgressIndicator());

    // Show private account message if not own profile and account is private and no content
    if (!isOwnProfile && isPrivate && _reels.isEmpty) {
      return _buildHiddenSectionMessage(
        'This Account is Private',
        'Follow this account to see their reels',
      );
    }

    if (!isOwnProfile && !bucketVisible) {
      return _buildHiddenSectionMessage(
        'Reels are Private',
        'This user chose to hide their reels',
      );
    }

    if (_reels.isEmpty) {
      return const Center(child: Text('No reels yet'));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _responsiveGridCount(
          constraints.maxWidth,
          targetTileWidth: 120,
          minCount: 3,
        );
        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 9 / 16,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _reels.length,
          itemBuilder: (context, index) {
            final reel = _reels[index];
            final deletingKey = 'media:${reel.id}';
            return InkWell(
              onTap: _isDeleting(deletingKey)
                  ? null
                  : () => context.go('/reels?id=${reel.contentId ?? reel.id}'),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: _isDeleting(deletingKey) ? 0.45 : 1,
                    child: (_preferredReelThumbnail(reel) != null)
                        ? _buildCachedImage(
                            _preferredReelThumbnail(reel)!,
                            fit: BoxFit.cover,
                            errorWidget: Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.video_camera_back, size: 36),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.grey.shade800,
                                  Colors.grey.shade900,
                                ],
                              ),
                            ),
                            child: const Center(
                              child: Icon(Icons.video_camera_back,
                                  size: 36, color: Colors.white70),
                            ),
                          ),
                  ),
                  const Center(
                    child: Icon(Icons.play_circle_fill,
                        color: Colors.white, size: 36),
                  ),
                  if (isOwnProfile)
                    _buildDeleteOverlay(
                      onDelete: () => _deleteMediaItem(reel),
                      isDeleting: _isDeleting(deletingKey),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProductsGrid() {
    final currentUser = context.read<AuthProvider>().user;
    final isOwnProfile =
        widget.userId == null || widget.userId == currentUser?.id;
    final displayUser = _profileUser;
    final isSellerProfile = isOwnProfile
        ? (currentUser?.isSeller ?? false)
        : (displayUser?['account_type']?.toString().toLowerCase() == 'seller' ||
            displayUser?['role']?.toString().toLowerCase() == 'seller');
    final isPrivate = _profileUser?['privacy_profile'] == 'private';
    final bucketVisible =
        _isBucketVisible('purchases', isOwnProfile: isOwnProfile);

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (!isOwnProfile && isPrivate && _products.isEmpty) {
      return _buildHiddenSectionMessage(
        'This Account is Private',
        'Follow this account to see their purchases',
      );
    }
    if (!isOwnProfile && !bucketVisible) {
      return _buildHiddenSectionMessage(
        'Purchases are Private',
        'This user chose to hide their purchases',
      );
    }
    if (_products.isEmpty) {
      if (isOwnProfile && currentUser?.isSeller == true) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.inventory_2_outlined,
                  size: 56, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Your warehouse is empty'),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => context.go('/add-product'),
                icon: const Icon(Icons.add),
                label: const Text('Add Product'),
              ),
            ],
          ),
        );
      }
      return const Center(child: Text('No purchases yet'));
    }
    final list = ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final product = _products[index];
        final compareAtPrice = product.compareAtPrice;
        final hasDiscount =
            compareAtPrice != null && compareAtPrice > product.price;
        final percentOff = hasDiscount
            ? (((compareAtPrice - product.price) / compareAtPrice) * 100)
                .round()
            : 0;
        final deletingKey = 'product:${product.id}';
        final canManageOwnListing =
            isOwnProfile && currentUser?.isSeller == true;
        final canManagePurchasedOrder = isOwnProfile && !isSellerProfile;
        final yourRating = _yourProductRating(product);
        return InkWell(
          onTap: _isDeleting(deletingKey)
              ? null
              : () {
                  if (canManageOwnListing) {
                    _previewOwnProduct(product);
                  } else if (canManagePurchasedOrder) {
                    context.push('/shop/${product.id}');
                  } else {
                    context.push('/shop/${product.id}');
                  }
                },
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(12),
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
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Opacity(
                        opacity: _isDeleting(deletingKey) ? 0.45 : 1,
                        child: SizedBox(
                          width: 92,
                          height: 92,
                          child: _buildCachedImage(
                            product.images.isNotEmpty ? product.images[0] : '',
                            fit: BoxFit.cover,
                            errorWidget: Container(
                              width: 92,
                              height: 92,
                              color: Colors.grey[300],
                              child: const Icon(Icons.shopping_bag, size: 36),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (isOwnProfile)
                      _buildDeleteOverlay(
                        onDelete: () => _deleteProduct(product),
                        isDeleting: _isDeleting(deletingKey),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.blue,
                        ),
                      ),
                      if (hasDiscount) ...[
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '\$${compareAtPrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey[600],
                              ),
                            ),
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
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            _effectiveProductRating(product) > 0
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 16,
                            color: _effectiveProductRating(product) > 0
                                ? Colors.amber[700]
                                : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _formatProductRating(product),
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (isSellerProfile)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildProductMetricChip(
                              icon: Icons.shopping_bag_outlined,
                              label:
                                  '${product.buys} ${product.buys == 1 ? 'purchase' : 'purchases'}',
                            ),
                          ],
                        )
                      else
                        Text(
                          _formatPurchaseTimeline(product),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                    ],
                  ),
                ),
                if (canManageOwnListing)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _isDeleting(deletingKey)
                              ? null
                              : () => _manageProduct(product),
                          icon: const Icon(Icons.edit_note_outlined, size: 16),
                          label: const Text('Manage'),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        OutlinedButton.icon(
                          onPressed: _isDeleting(deletingKey)
                              ? null
                              : () => _previewOwnProduct(product),
                          icon: const Icon(Icons.remove_red_eye_outlined,
                              size: 16),
                          label: const Text('Preview'),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Stock ${product.stockQuantity}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (canManagePurchasedOrder)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _isDeleting(deletingKey)
                              ? null
                              : () async {
                                  final updated = await context.push<bool>(
                                    '/orders/manage',
                                    extra: product,
                                  );
                                  if (updated == true && mounted) {
                                    await _fetchUserContent(forceRefresh: true);
                                  }
                                },
                          icon:
                              const Icon(Icons.receipt_long_outlined, size: 16),
                          label: const Text('Manage Order'),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          yourRating == null
                              ? 'Your rating: Not rated'
                              : 'Your rating: ${yourRating.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (isOwnProfile && currentUser?.isSeller == true) {
      return Column(
        children: [
          _buildProductOwnerSummary(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => context.go('/add-product'),
                icon: const Icon(Icons.add),
                label: const Text('Add Product'),
              ),
            ),
          ),
          Expanded(child: list),
        ],
      );
    }
    return list;
  }

  Widget _buildProfileActionButton({
    required VoidCallback onPressed,
    required String label,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 30,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(label),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _StatItem extends StatelessWidget {
  final String label;
  final int count;
  final VoidCallback? onTap;

  const _StatItem({
    required this.label,
    required this.count,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodySmall?.color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    if (onTap == null) {
      return child;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: child,
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}

class _CachedProfileScreenState {
  const _CachedProfileScreenState({
    required this.profileUser,
    required this.photos,
    required this.videos,
    required this.reels,
    required this.products,
  });

  final Map<String, dynamic> profileUser;
  final List<MediaItem> photos;
  final List<MediaItem> videos;
  final List<MediaItem> reels;
  final List<ProductModel> products;
}
