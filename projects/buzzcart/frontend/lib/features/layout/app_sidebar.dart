import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/widgets/network_media.dart';
import '../../features/messages/providers/messages_provider.dart';

/// A single destination rendered in the desktop navigation sidebar.
class NavDestination {
  final String path;
  final IconData icon;
  final IconData? activeIcon;
  final String label;

  const NavDestination({
    required this.path,
    required this.icon,
    this.activeIcon,
    required this.label,
  });

  IconData iconFor(bool isActive) => isActive ? (activeIcon ?? icon) : icon;
}

/// Primary destinations that also appear in the mobile bottom navigation.
/// These map 1:1 to the branches of the [StatefulShellRoute].
const List<NavDestination> kPrimaryNavItems = [
  NavDestination(
    path: '/',
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    label: 'Home',
  ),
  NavDestination(
    path: '/videos',
    icon: Icons.play_circle_outline,
    activeIcon: Icons.play_circle,
    label: 'Videos',
  ),
  NavDestination(
    path: '/reels',
    icon: Icons.movie_outlined,
    activeIcon: Icons.movie,
    label: 'Reels',
  ),
  NavDestination(
    path: '/shop',
    icon: Icons.shopping_bag_outlined,
    activeIcon: Icons.shopping_bag,
    label: 'Shop',
  ),
  NavDestination(
    path: '/profile',
    icon: Icons.person_outline,
    activeIcon: Icons.person,
    label: 'Profile',
  ),
];

/// Secondary destinations that only appear in the desktop sidebar.
const List<NavDestination> kSidebarOnlyItems = [
  NavDestination(path: '/search', icon: Icons.search, label: 'Search'),
  NavDestination(path: '/messages', icon: Icons.message, label: 'Messages'),
  NavDestination(path: '/cart', icon: Icons.shopping_cart, label: 'Cart'),
  NavDestination(path: '/settings', icon: Icons.settings, label: 'Settings'),
];

/// The persistent left navigation sidebar shown on desktop widths.
///
/// It is layout-agnostic: navigation is delegated to [onNavigate] so the same
/// widget can drive branch switching inside the shell as well as plain
/// `context.go`/`context.push` navigation from standalone pages.
class AppSidebar extends StatelessWidget {
  final String currentPath;
  final void Function(String path) onNavigate;

  const AppSidebar({
    super.key,
    required this.currentPath,
    required this.onNavigate,
  });

  bool _isOnPath(String path) {
    return currentPath == path ||
        (path != '/' && currentPath.startsWith('$path/'));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = context.watch<AuthProvider>().user;
    final isHomePage = currentPath == '/';

    return Container(
      width: 256,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        border: Border(
          right: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      child: Column(
        children: [
          // Logo
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
            ),
            child: isHomePage
                ? PopupMenuButton<String>(
                    offset: const Offset(0, 50),
                    onSelected: (value) {
                      if (value == 'content') {
                        onNavigate('/upload-content');
                      } else if (value == 'product') {
                        onNavigate('/add-product');
                      }
                    },
                    itemBuilder: (context) {
                      final isSeller = user?.isSeller ?? false;
                      if (isSeller) {
                        return [
                          const PopupMenuItem(
                            value: 'content',
                            child: Row(
                              children: [
                                Icon(Icons.add_photo_alternate),
                                SizedBox(width: 12),
                                Text('Add Content'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'product',
                            child: Row(
                              children: [
                                Icon(Icons.inventory_2),
                                SizedBox(width: 12),
                                Text('Add Product'),
                              ],
                            ),
                          ),
                        ];
                      } else {
                        return [
                          const PopupMenuItem(
                            value: 'content',
                            child: Row(
                              children: [
                                Icon(Icons.add_photo_alternate),
                                SizedBox(width: 12),
                                Text('Add Content'),
                              ],
                            ),
                          ),
                        ];
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Buzz',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            'Cart',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.electricBlue,
                                ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.keyboard_arrow_down, size: 20),
                        ],
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Buzz',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          'Cart',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.electricBlue,
                              ),
                        ),
                      ],
                    ),
                  ),
          ),

          // Navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ...kPrimaryNavItems.map(_buildNavButton),
                const SizedBox(height: 16),
                Divider(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                const SizedBox(height: 16),
                ...kSidebarOnlyItems.map(_buildNavButton),
              ],
            ),
          ),

          // User profile
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkAccent.withAlpha(128)
                    : AppColors.lightAccent.withAlpha(128),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  AppAvatar(
                    name: user?.name ?? 'User',
                    avatarUrl: user?.avatar?.trim(),
                    radius: 20,
                    backgroundColor: AppColors.electricBlue,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user?.name ?? 'User',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          user?.email ?? '',
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, size: 20),
                    onPressed: () async {
                      await context.read<AuthProvider>().logout();
                      if (context.mounted) {
                        onNavigate('/Login');
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(NavDestination item) {
    return Builder(
      builder: (context) {
        final isActive = _isOnPath(item.path);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cartCount = context.watch<CartProvider>().cart.itemCount;
        final unreadMessages =
            context.watch<MessagesProvider>().totalUnreadCount;
        final showCartBadge = item.path == '/cart' && cartCount > 0;
        final showMessageBadge = item.path == '/messages' && unreadMessages > 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Material(
            color: isActive
                ? (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => onNavigate(item.path),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          item.iconFor(isActive),
                          size: 20,
                          color: isActive
                              ? (isDark
                                  ? AppColors.darkPrimaryForeground
                                  : AppColors.lightPrimaryForeground)
                              : (isDark
                                  ? AppColors.darkMutedForeground
                                  : AppColors.lightMutedForeground),
                        ),
                        if (showCartBadge || showMessageBadge)
                          Positioned(
                            right: -9,
                            top: -8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: const BoxDecoration(
                                color: AppColors.electricBlue,
                                borderRadius:
                                    BorderRadius.all(Radius.circular(10)),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                showCartBadge
                                    ? (cartCount > 99 ? '99+' : '$cartCount')
                                    : (unreadMessages > 99
                                        ? '99+'
                                        : '$unreadMessages'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Text(
                      item.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: isActive
                                ? (isDark
                                    ? AppColors.darkPrimaryForeground
                                    : AppColors.lightPrimaryForeground)
                                : (isDark
                                    ? AppColors.darkMutedForeground
                                    : AppColors.lightMutedForeground),
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
