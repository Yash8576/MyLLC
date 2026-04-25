import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import '../providers/upload_content_provider.dart';
import '../providers/add_product_provider.dart';
import '../models/models.dart';
import '../../features/auth/screens/splash_page.dart';
import '../../features/auth/screens/login_page.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/layout/main_layout.dart';
import '../../features/home/screens/home_page.dart';
import '../../features/shop/screens/shop_page.dart';
import '../../features/videos/screens/videos_page.dart';
import '../../features/reels/screens/reels_page.dart';
import '../../features/cart/screens/cart_page.dart';
import '../../features/cart/screens/checkout_page.dart';
import '../../features/profile/screens/profile_page.dart';
import '../../features/messages/screens/messages_page.dart';
import '../../features/search/screens/search_page.dart';
import '../../features/settings/screens/settings_page.dart';
import '../../features/upload/presentation/screens/add_product_screen.dart';
import '../../features/upload/presentation/screens/upload_content_screen.dart';
import '../../features/orders/screens/manage_order_page.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'rootNavigator');
final GlobalKey<NavigatorState> _homeBranchNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'homeBranchNavigator');
final GlobalKey<NavigatorState> _videosBranchNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'videosBranchNavigator');
final GlobalKey<NavigatorState> _reelsBranchNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'reelsBranchNavigator');
final GlobalKey<NavigatorState> _shopBranchNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'shopBranchNavigator');
final GlobalKey<NavigatorState> _profileBranchNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'profileBranchNavigator');

// Create a router that refreshes when AuthProvider changes
GoRouter createAppRouter(AuthProvider authProvider) {
  final initialRouteOverride = AppConfig.initialRouteOverride;
  final useInitialRouteOverride = initialRouteOverride.isNotEmpty;

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation:
        useInitialRouteOverride ? initialRouteOverride : '/splash',
    overridePlatformDefaultLocation: useInitialRouteOverride,
    refreshListenable: authProvider,
    redirect: (context, state) {
      final isSplash = state.matchedLocation == '/splash';
      final isLogin = state.matchedLocation == '/Login';
      final isSignup = state.matchedLocation == '/Signup';
      final isAuth = isLogin || isSignup;

      debugPrint(
          'Router redirect - isLoading: ${authProvider.isLoading}, isAuthenticated: ${authProvider.isAuthenticated}, location: ${state.matchedLocation}');

      // Show splash while loading
      if (authProvider.isLoading) {
        return isSplash ? null : '/splash';
      }

      // After loading completes, redirect from splash
      if (isSplash && !authProvider.isLoading) {
        return authProvider.isAuthenticated ? '/' : '/Login';
      }

      // Redirect authenticated users away from auth pages
      if (authProvider.isAuthenticated && isAuth) {
        return '/';
      }

      // Redirect unauthenticated users to login
      if (!authProvider.isAuthenticated && !isAuth && !isSplash) {
        return '/Login';
      }

      return null;
    },
    routes: [
      // Splash screen
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),

      // Public routes
      GoRoute(
        path: '/Login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/Signup',
        builder: (context, state) => const SignupScreen(),
      ),

      // Protected routes with persistent tab caching
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainLayout(
              navigationShell: navigationShell,
              currentPath: state.uri.path,
            ),
        branches: [
          StatefulShellBranch(
            navigatorKey: _homeBranchNavigatorKey,
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomePage(),
                routes: [
                  GoRoute(
                    path: 'cart',
                    builder: (context, state) => const CartPage(),
                  ),
                  GoRoute(
                    path: 'checkout',
                    builder: (context, state) => const CheckoutPage(),
                  ),
                  GoRoute(
                    path: 'messages',
                    builder: (context, state) => MessagesPage(
                      intent: state.extra is MessagesRouteIntent
                          ? state.extra as MessagesRouteIntent
                          : null,
                    ),
                  ),
                  GoRoute(
                    path: 'search',
                    builder: (context, state) => const SearchPage(),
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => const SettingsPage(),
                  ),
                  GoRoute(
                    path: 'orders/manage',
                    builder: (context, state) {
                      final product = state.extra is ProductModel
                          ? state.extra as ProductModel
                          : null;
                      if (product == null) {
                        return const Scaffold(
                          body: Center(
                            child: Text('No order selected'),
                          ),
                        );
                      }
                      return ManageOrderPage(product: product);
                    },
                  ),
                  GoRoute(
                    path: 'add-product',
                    builder: (context, state) {
                      final editingProduct = state.extra is ProductModel
                          ? state.extra as ProductModel
                          : null;
                      return AddProductScreen(
                        editingProduct: editingProduct,
                      );
                    },
                    onExit: (context) async {
                      final provider = context.read<AddProductProvider>();
                      if (!provider.hasUnsavedWork) {
                        return true;
                      }

                      final shouldLeave = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Discard Product?'),
                          content: const Text(
                            'You have unsaved changes. Are you sure you want to discard this product?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Continue Editing'),
                            ),
                            TextButton(
                              onPressed: () {
                                provider.clearAll();
                                Navigator.pop(context, true);
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('Discard'),
                            ),
                          ],
                        ),
                      );

                      return shouldLeave ?? false;
                    },
                  ),
                  GoRoute(
                    path: 'upload-content',
                    builder: (context, state) => const UploadContentScreen(),
                    onExit: (context) async {
                      final provider = context.read<UploadContentProvider>();
                      if (!provider.hasUnsavedWork) {
                        return true;
                      }

                      final shouldLeave = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Discard Content?'),
                          content: const Text(
                            'You have unsaved changes. Are you sure you want to discard this content?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Continue Editing'),
                            ),
                            TextButton(
                              onPressed: () {
                                provider.clearAll();
                                Navigator.pop(context, true);
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('Discard'),
                            ),
                          ],
                        ),
                      );

                      return shouldLeave ?? false;
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _videosBranchNavigatorKey,
            routes: [
              GoRoute(
                path: '/videos',
                builder: (context, state) => const VideosPage(),
                routes: [
                  GoRoute(
                    path: ':videoId',
                    builder: (context, state) {
                      final videoId = state.pathParameters['videoId']!;
                      return VideosPage(videoId: videoId);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _reelsBranchNavigatorKey,
            routes: [
              GoRoute(
                path: '/reels',
                builder: (context, state) => ReelsPage(
                  initialReelId: state.uri.queryParameters['id'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shopBranchNavigatorKey,
            routes: [
              GoRoute(
                path: '/shop',
                builder: (context, state) => const ShopPage(),
                routes: [
                  GoRoute(
                    path: ':productId',
                    builder: (context, state) {
                      final productId = state.pathParameters['productId']!;
                      final ownPreview =
                          state.uri.queryParameters['own_preview'] == '1';
                      return ShopPage(
                        productId: productId,
                        allowOwnProductPreview: ownPreview,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _profileBranchNavigatorKey,
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfilePage(),
                routes: [
                  GoRoute(
                    path: ':userId',
                    builder: (context, state) {
                      final userId = state.pathParameters['userId']!;
                      return ProfilePage(userId: userId);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
