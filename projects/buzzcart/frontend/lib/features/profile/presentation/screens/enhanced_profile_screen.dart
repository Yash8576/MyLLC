import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/models.dart';
import '../../../../core/services/api_service.dart';
import '../widgets/profile_gallery_widget.dart';

/// Enhanced Instagram-style profile screen with photo gallery
class EnhancedProfileScreen extends StatefulWidget {
  final String? userId; // If null, shows current user's profile

  const EnhancedProfileScreen({
    super.key,
    this.userId,
  });

  @override
  State<EnhancedProfileScreen> createState() => _EnhancedProfileScreenState();
}

class _EnhancedProfileScreenState extends State<EnhancedProfileScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;
  
  UserModel? _user;
  bool _loading = true;
  bool _isOwnProfile = false;
  final bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);

    try {
      // If userId is null, fetch current user's profile
      final user = widget.userId == null
          ? await _api.getMe()
          : await _api.getUser(widget.userId!);

      // Check if this is the current user's profile
      final currentUser = await _api.getMe();
      final isOwn = user.id == currentUser.id;

      setState(() {
        _user = user;
        _isOwnProfile = isOwn;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _user == null
              ? const Center(child: Text('Failed to load profile'))
              : CustomScrollView(
                  slivers: [
                    // App bar with user info
                    SliverAppBar(
                      floating: true,
                      title: Text(_user!.name),
                      actions: [
                        if (_isOwnProfile)
                          IconButton(
                            icon: const Icon(Icons.settings_outlined),
                            onPressed: () {
                              // Navigate to settings
                            },
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.more_vert),
                            onPressed: () {
                              // Show options
                            },
                          ),
                      ],
                    ),

                    // Profile header
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          _buildProfileHeader(),
                          const SizedBox(height: 16),
                          _buildStats(),
                          const SizedBox(height: 16),
                          _buildBio(),
                          const SizedBox(height: 16),
                          _buildActionButtons(),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),

                    // Tab bar
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SliverAppBarDelegate(
                        TabBar(
                          controller: _tabController,
                          labelColor: Colors.black,
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: Colors.black,
                          tabs: const [
                            Tab(icon: Icon(Icons.grid_on)),
                            Tab(icon: Icon(Icons.video_library_outlined)),
                            Tab(icon: Icon(Icons.bookmark_border)),
                          ],
                        ),
                      ),
                    ),

                    // Tab content
                    SliverFillRemaining(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // Photos tab
                          CustomScrollView(
                            slivers: [
                              ProfileGalleryWidget(
                                userId: _user!.id,
                                isOwnProfile: _isOwnProfile,
                              ),
                            ],
                          ),
                          
                          // Videos tab
                          const Center(child: Text('Videos coming soon')),
                          
                          // Saved tab
                          const Center(child: Text('Saved posts coming soon')),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildProfileHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Profile picture
          CircleAvatar(
            radius: 40,
            backgroundImage: _user!.avatar != null
                ? CachedNetworkImageProvider(_user!.avatar!)
                : null,
            backgroundColor: AppColors.electricBlue,
            child: _user!.avatar == null
                ? Text(
                    _user!.name.isNotEmpty ? _user!.name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 20),
          
          // Username and verification badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _user!.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_user!.isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified,
                        color: AppColors.electricBlue,
                        size: 20,
                      ),
                    ],
                  ],
                ),
                if (_user!.isSeller)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.electricBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'SELLER',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.electricBlue,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const _StatItem(label: 'Posts', value: '0'), // TODO: Get actual post count
          _StatItem(
            label: 'Followers',
            value: _formatCount(_user!.followersCount),
          ),
          _StatItem(
            label: 'Following',
            value: _formatCount(_user!.followingCount),
          ),
        ],
      ),
    );
  }

  Widget _buildBio() {
    if (_user!.bio == null || _user!.bio!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        _user!.bio!,
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _isOwnProfile
                ? OutlinedButton(
                    onPressed: () {
                      // Navigate to edit profile
                    },
                    child: const Text('Edit Profile'),
                  )
                : _isFollowing
                    ? OutlinedButton(
                        onPressed: () {
                          // Unfollow
                        },
                        child: const Text('Following'),
                      )
                    : ElevatedButton(
                        onPressed: () {
                          // Follow
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.electricBlue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Follow'),
                      ),
          ),
          if (!_isOwnProfile) ...[
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () {
                // Send message
              },
              child: const Text('Message'),
            ),
          ],
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

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
