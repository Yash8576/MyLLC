import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/upload_content_provider.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/models/models.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<MediaItem> _mediaItems = [];
  bool _isLoadingMedia = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserMedia();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uploadProvider = context.read<UploadContentProvider>();
      uploadProvider.setOnUploadSuccess(_loadUserMedia);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserMedia() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.user == null) {
      debugPrint('No user found in auth provider');
      return;
    }

    debugPrint('Loading user media for: ${authProvider.user!.id}');

    setState(() {
      _isLoadingMedia = true;
    });

    try {
      final apiService = context.read<ApiService>();
      final media = await apiService.getUserMedia(
        authProvider.user!.id,
        type: 'photo',
        limit: 100,
      );
      
      debugPrint('Received ${media.length} media items');
      
      if (mounted) {
        setState(() {
          _mediaItems = media;
          _isLoadingMedia = false;
        });
        debugPrint('State updated with ${_mediaItems.length} items');
      }
    } catch (e) {
      debugPrint('Error loading user media: $e');
      if (mounted) {
        setState(() {
          _isLoadingMedia = false;
        });
        // Show error to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load photos: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _refreshProfile() async {
    await _loadUserMedia();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.user;
        if (user == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(user.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () {},
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refreshProfile,
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.electricBlue,
                          backgroundImage: user.avatar != null ? NetworkImage(user.avatar!) : null,
                          child: user.avatar == null
                              ? Text(
                                  user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          user.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (user.bio != null && user.bio!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              user.bio!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _StatItem(label: 'Posts', value: _mediaItems.length.toString()),
                            _StatItem(label: 'Followers', value: user.followersCount.toString()),
                            _StatItem(label: 'Following', value: user.followingCount.toString()),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverAppBarDelegate(
                      TabBar(
                        controller: _tabController,
                        tabs: const [
                          Tab(icon: Icon(Icons.grid_on), text: 'Photos'),
                          Tab(icon: Icon(Icons.menu), text: 'Menu'),
                        ],
                      ),
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildPhotosGrid(),
                  _buildMenuList(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhotosGrid() {
    debugPrint('Building photos grid - Loading: $_isLoadingMedia, Items: ${_mediaItems.length}');
    
    if (_isLoadingMedia) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_mediaItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No photos yet',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUserMedia,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    debugPrint('Rendering ${_mediaItems.length} photos');
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _mediaItems.length,
      itemBuilder: (context, index) {
        final item = _mediaItems[index];
        debugPrint('Building image $index: ${item.mediaUrl}');
        return GestureDetector(
          onTap: () {},
          child: Image.network(
            item.mediaUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Error loading image ${item.mediaUrl}: $error');
              return Container(
                color: Colors.grey[300],
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.broken_image, color: Colors.grey),
                    Text(
                      'Error',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                debugPrint('Image loaded: ${item.mediaUrl}');
                return child;
              }
              return Container(
                color: Colors.grey[200],
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMenuList() {
    return ListView(
      children: [
        _MenuItem(
          icon: Icons.shopping_bag_outlined,
          title: 'My Orders',
          onTap: () {},
        ),
        _MenuItem(
          icon: Icons.favorite_outline,
          title: 'Wishlist',
          onTap: () {},
        ),
        _MenuItem(
          icon: Icons.location_on_outlined,
          title: 'Addresses',
          onTap: () {},
        ),
        _MenuItem(
          icon: Icons.payment_outlined,
          title: 'Payment Methods',
          onTap: () {},
        ),
        _MenuItem(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          onTap: () {},
        ),
        _MenuItem(
          icon: Icons.security_outlined,
          title: 'Privacy & Security',
          onTap: () {},
        ),
        _MenuItem(
          icon: Icons.help_outline,
          title: 'Help & Support',
          onTap: () {},
        ),
        _MenuItem(
          icon: Icons.info_outline,
          title: 'About',
          onTap: () {},
        ),
        const Divider(height: 32),
        _MenuItem(
          icon: Icons.logout,
          title: 'Logout',
          textColor: AppColors.destructive,
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Logout'),
                content: const Text('Are you sure you want to logout?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.go('/Login');
                    },
                    child: const Text(
                      'Logout',
                      style: TextStyle(color: AppColors.destructive),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.electricBlue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? textColor;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: textColor),
      title: Text(
        title,
        style: TextStyle(color: textColor),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
