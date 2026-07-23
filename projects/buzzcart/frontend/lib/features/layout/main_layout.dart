import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';
import 'dart:ui' show ImageFilter;
import '../../core/theme/app_colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/utils/app_visibility_listener.dart';
import '../../features/messages/providers/messages_provider.dart';
import '../../core/router/shell_obscured_notifier.dart';
import 'app_sidebar.dart';

const double _kGlossyNavHeight = 64 * 0.8;
const double _kGlossyNavMargin = 16;

/// Extra bottom clearance needed by full-bleed pages (e.g. Reels) so their
/// own bottom-anchored overlays don't sit underneath the floating glass nav
/// bar, which — unlike the legacy flush bar — no longer reserves layout
/// space (`Scaffold.extendBody` is true on that path). Zero on platforms
/// still using the legacy opaque bar, since that one already reserves space.
double glossyBottomNavClearance(BuildContext context) {
  final usesGlossyNav = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);
  if (!usesGlossyNav) return 0;
  // Mirrors _buildGlossyBottomNav's own bottom padding exactly (a flat
  // margin, not the device's safe-area inset — the nav bar doesn't reserve
  // extra space for that), so this clearance lines up with its real top edge.
  final bottomInset = MediaQuery.of(context).padding.bottom;
  return _kGlossyNavHeight + (bottomInset > 0 ? _kGlossyNavMargin : 18);
}

class MainLayout extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  final String currentPath;

  const MainLayout({
    super.key,
    required this.navigationShell,
    required this.currentPath,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout>
    with WidgetsBindingObserver, RouteAware {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  bool _hasInitializedCart = false;
  late final AppVisibilityListener _appVisibilityListener;
  ModalRoute<dynamic>? _subscribedRoute;

  @override
  void initState() {
    super.initState();
    _appVisibilityListener = AppVisibilityListener();
    WidgetsBinding.instance.addObserver(this);
    _appVisibilityListener.start(_handleVisibilitySignal);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_updateActivity());
      _syncAppVisibility(true, forceRefresh: true);
    });
    _initializeCart();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _subscribedRoute) {
      if (_subscribedRoute != null) {
        shellRouteObserver.unsubscribe(this);
      }
      _subscribedRoute = route;
      if (route != null) {
        shellRouteObserver.subscribe(this, route);
      }
    }
  }

  @override
  void didPushNext() {
    shellObscuredNotifier.value = true;
  }

  @override
  void didPopNext() {
    shellObscuredNotifier.value = false;
  }

  void _initializeCart() {
    if (!_hasInitializedCart) {
      _hasInitializedCart = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<CartProvider>().fetchCart();
        }
      });
    }
  }

  @override
  void dispose() {
    shellRouteObserver.unsubscribe(this);
    _appVisibilityListener.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _syncAppVisibility(state == AppLifecycleState.resumed);
  }

  void _handleVisibilitySignal(bool isVisible) {
    if (!mounted) {
      return;
    }
    _syncAppVisibility(isVisible, forceRefresh: isVisible);
  }

  void _syncAppVisibility(bool isVisible, {bool forceRefresh = false}) {
    final messagesProvider = context.read<MessagesProvider>();
    messagesProvider.setAppVisibility(isVisible);
    if (isVisible) {
      unawaited(_updateActivity());
      if (forceRefresh) {
        messagesProvider.refreshAppPresence();
      }
    }
  }

  Future<void> _updateActivity() async {
    await _storage.write(
      key: 'last_activity',
      value: DateTime.now().toIso8601String(),
    );
  }

  bool get _usesGlossyNav =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  bool _isOnPath(String path) {
    final currentPath = widget.currentPath;
    return currentPath == path ||
        (path != '/' && currentPath.startsWith('$path/'));
  }

  // Guards against a pushed route (Messages, Search, Cart, Settings, ...)
  // being pushed twice in a row. `widget.currentPath` only updates once the
  // router rebuilds this widget, so a second tap on a nav icon that lands
  // before that rebuild would slip past `_isOnPath` and push a duplicate
  // page — stacking two slide-in transitions that then both have to be
  // popped, which reads as an extra, unwanted right-to-left animation.
  bool _pushNavigationInFlight = false;

  void _navigateTo(String path) {
    if (!path.startsWith('/messages')) {
      final messagesProvider = context.read<MessagesProvider>();
      messagesProvider.setTyping(false);
      messagesProvider.clearSelection();
    }

    final branchIndex =
        kPrimaryNavItems.indexWhere((item) => item.path == path);
    if (branchIndex != -1) {
      final isCurrentBranch =
          widget.navigationShell.currentIndex == branchIndex;
      widget.navigationShell.goBranch(
        branchIndex,
        initialLocation: isCurrentBranch,
      );
      return;
    }

    if (_isOnPath(path)) {
      return;
    }

    if (path == '/Login' || path == '/Signup' || path == '/splash') {
      context.go(path);
      return;
    }

    if (_pushNavigationInFlight) {
      return;
    }
    _pushNavigationInFlight = true;
    context.push(path).whenComplete(() {
      _pushNavigationInFlight = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1024;
        final isReelsPage = widget.currentPath.startsWith('/reels');

        return ValueListenableBuilder<bool>(
          valueListenable: shellObscuredNotifier,
          builder: (context, obscured, child) {
            return ActiveBranchScope(
              currentIndex: widget.navigationShell.currentIndex,
              currentPath: widget.currentPath,
              obscured: obscured,
              child: child!,
            );
          },
          child: Scaffold(
            extendBody: !isDesktop && _usesGlossyNav,
            body: Row(
              children: [
                // Desktop sidebar
                if (isDesktop)
                  AppSidebar(
                    currentPath: widget.currentPath,
                    onNavigate: _navigateTo,
                  ),

                // Main content
                Expanded(
                  child: Column(
                    children: [
                      // Mobile header
                      if (!isDesktop && !isReelsPage) _buildMobileHeader(),

                      // Page content
                      Expanded(child: widget.navigationShell),
                    ],
                  ),
                ),
              ],
            ),
            // Mobile bottom navigation
            bottomNavigationBar: isDesktop ? null : _buildBottomNav(),
          ),
        );
      },
    );
  }

  Widget _buildMobileHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentPath = widget.currentPath;
    final isHomePage = currentPath == '/';
    final isProfilePage = currentPath.startsWith('/profile');

    // On notch/Dynamic-Island devices the OS-reported top inset carries a
    // generous built-in margin beyond what's needed to clear the island, so
    // hugging it exactly leaves a visibly oversized gap. Trim a bit of that
    // slack on those devices while leaving plain status bars untouched.
    final rawTopInset = MediaQuery.of(context).padding.top;
    final topInset = rawTopInset > 40 ? rawTopInset - 14 : rawTopInset;

    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
          ),
          child: Row(
            children: [
              isHomePage
                  ? PopupMenuButton<String>(
                      offset: const Offset(0, 40),
                      onSelected: (value) {
                        if (value == 'content') {
                          _navigateTo('/upload-content');
                        } else if (value == 'product') {
                          _navigateTo('/add-product');
                        }
                      },
                      itemBuilder: (context) {
                        final user = context.read<AuthProvider>().user;
                        final isSeller = user?.isSeller ?? false;
                        if (isSeller) {
                          return [
                            const PopupMenuItem(
                              value: 'content',
                              child: Row(
                                children: [
                                  Icon(Icons.add_photo_alternate, size: 18),
                                  SizedBox(width: 8),
                                  Text('Add Content'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'product',
                              child: Row(
                                children: [
                                  Icon(Icons.inventory_2, size: 18),
                                  SizedBox(width: 8),
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
                                  Icon(Icons.add_photo_alternate, size: 18),
                                  SizedBox(width: 8),
                                  Text('Add Content'),
                                ],
                              ),
                            ),
                          ];
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            Text(
                              'Buzz',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              'Cart',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.electricBlue,
                                  ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.keyboard_arrow_down, size: 18),
                          ],
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            'Buzz',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            'Cart',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.electricBlue,
                                ),
                          ),
                        ],
                      ),
                    ),
              const Spacer(),
              if (isProfilePage)
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => _navigateTo('/settings'),
                ),
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => _navigateTo('/search'),
              ),
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart),
                    onPressed: () => _navigateTo('/cart'),
                  ),
                  // Scoped so cart updates only rebuild this badge, not the
                  // whole shell (header + nav + body).
                  Selector<CartProvider, int>(
                    selector: (_, provider) => provider.cart.itemCount,
                    builder: (context, itemCount, _) {
                      if (itemCount <= 0) {
                        return const SizedBox.shrink();
                      }
                      return Positioned(
                        right: 8,
                        top: 8,
                        child: IgnorePointer(
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.electricBlue,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '$itemCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.message_outlined),
                    onPressed: () => _navigateTo('/messages'),
                  ),
                  // Scoped so unread-count changes (sockets, presence) only
                  // rebuild this badge, not the whole shell.
                  Selector<MessagesProvider, int>(
                    selector: (_, provider) => provider.totalUnreadCount,
                    builder: (context, unreadMessages, _) {
                      if (unreadMessages <= 0) {
                        return const SizedBox.shrink();
                      }
                      return Positioned(
                        right: 8,
                        top: 8,
                        child: IgnorePointer(
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
                              unreadMessages > 99 ? '99+' : '$unreadMessages',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return _usesGlossyNav ? _buildGlossyBottomNav() : _buildLegacyBottomNav();
  }

  Widget _buildLegacyBottomNav() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentIndex = widget.navigationShell.currentIndex;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) {
            _navigateTo(kPrimaryNavItems[index].path);
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.electricBlue,
          unselectedItemColor: isDark
              ? AppColors.darkMutedForeground
              : AppColors.lightMutedForeground,
          items: kPrimaryNavItems
              .map((item) => BottomNavigationBarItem(
                    icon: Icon(item.icon),
                    label: item.label,
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildGlossyBottomNav() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentIndex = widget.navigationShell.currentIndex;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    // Liquid Glass: a floating, refractive capsule detached from the
    // screen edges, matching Apple's OS-level glass material (blurred,
    // faintly tinted, with a specular highlight along the top rim).
    final tint = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.35);
    final rimHighlight = Colors.white.withValues(alpha: isDark ? 0.35 : 0.85);
    final rimShadow = Colors.black.withValues(alpha: isDark ? 0.5 : 0.12);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        bottomInset > 0 ? _kGlossyNavMargin : 18,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
          child: Container(
            height: _kGlossyNavHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              color: (isDark ? AppColors.darkCard : AppColors.lightCard)
                  .withValues(alpha: isDark ? 0.45 : 0.55),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [tint, Colors.transparent],
                stops: const [0.0, 0.7],
              ),
              border: Border.all(color: rimHighlight, width: 1),
              boxShadow: [
                BoxShadow(
                  color: rimShadow,
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: kPrimaryNavItems.asMap().entries.map((entry) {
                final item = entry.value;
                final isActive = entry.key == currentIndex;
                return Expanded(
                  child: _BottomNavButton(
                    item: item,
                    isActive: isActive,
                    isDark: isDark,
                    onTap: () => _navigateTo(item.path),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavButton extends StatelessWidget {
  final NavDestination item;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _BottomNavButton({
    required this.item,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isDark ? Colors.white : Colors.black;
    final inactiveColor =
        isDark ? AppColors.darkMutedForeground : AppColors.lightMutedForeground;
    final pillColor = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.white.withValues(alpha: 0.55);
    final pillBorder = isDark
        ? Colors.white.withValues(alpha: 0.22)
        : Colors.white.withValues(alpha: 0.9);

    return Semantics(
      label: item.label,
      button: true,
      selected: isActive,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: SizedBox.expand(
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? pillColor : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border:
                    isActive ? Border.all(color: pillBorder, width: 0.8) : null,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                scale: isActive ? 1.08 : 1.0,
                child: Icon(
                  item.iconFor(isActive),
                  size: 26,
                  color: isActive ? activeColor : inactiveColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ActiveBranchScope extends InheritedWidget {
  const ActiveBranchScope({
    super.key,
    required this.currentIndex,
    required this.currentPath,
    required this.obscured,
    required super.child,
  });

  final int currentIndex;
  final String currentPath;

  /// True while a route (Cart, Messages, Search, Settings, ...) is pushed on
  /// top of the shell on the root navigator, covering it. Widgets that only
  /// key playback off `currentIndex`/`currentPath` (the active branch) also
  /// need to check this, since the shell keeps reporting the same branch as
  /// active even though it's no longer visible on screen.
  final bool obscured;

  static ActiveBranchScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ActiveBranchScope>();
  }

  static int of(BuildContext context) {
    final scope = maybeOf(context);
    return scope?.currentIndex ?? 0;
  }

  static String currentPathOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ActiveBranchScope>();
    return scope?.currentPath ?? '/';
  }

  @override
  bool updateShouldNotify(ActiveBranchScope oldWidget) {
    return oldWidget.currentIndex != currentIndex ||
        oldWidget.currentPath != currentPath ||
        oldWidget.obscured != obscured;
  }
}
