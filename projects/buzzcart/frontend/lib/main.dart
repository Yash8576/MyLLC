import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/cart_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/upload_content_provider.dart';
import 'core/providers/add_product_provider.dart';
import 'core/providers/app_refresh_provider.dart';
import 'core/services/api_service.dart';
import 'core/router/app_router.dart';
import 'features/messages/providers/messages_provider.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    MediaKit.ensureInitialized();
    VideoPlayerMediaKit.ensureInitialized(windows: true);
  }

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>(
          create: (_) => ApiService(),
          lazy: false, // Initialize immediately
        ),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(
            apiService: context.read<ApiService>(),
          ),
          lazy: false, // Initialize immediately to load token
        ),
        ChangeNotifierProxyProvider<AuthProvider, MessagesProvider>(
          create: (context) => MessagesProvider(
            apiService: context.read<ApiService>(),
          ),
          update: (context, authProvider, messagesProvider) {
            final provider = messagesProvider ??
                MessagesProvider(apiService: context.read<ApiService>());
            provider.updateAuthState(
              isAuthenticated: authProvider.isAuthenticated,
              user: authProvider.user,
            );
            return provider;
          },
        ),
        ChangeNotifierProvider<CartProvider>(
          create: (context) => CartProvider(
            apiService: context.read<ApiService>(),
          ),
        ),
        ChangeNotifierProvider<UploadContentProvider>(
          create: (_) => UploadContentProvider(),
        ),
        ChangeNotifierProvider<AddProductProvider>(
          create: (_) => AddProductProvider(),
        ),
        ChangeNotifierProvider<AppRefreshProvider>(
          create: (_) => AppRefreshProvider(),
        ),
      ],
      child: const BuzzSocialCartApp(),
    ),
  );
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.unknown,
      };
}

class BuzzSocialCartApp extends StatefulWidget {
  const BuzzSocialCartApp({super.key});

  @override
  State<BuzzSocialCartApp> createState() => _BuzzSocialCartAppState();
}

class _BuzzSocialCartAppState extends State<BuzzSocialCartApp> {
  GoRouter? _router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _router ??= createAppRouter(context.read<AuthProvider>());
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp.router(
      title: 'BuzzCart - Social Commerce',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _AppScrollBehavior(),
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeProvider.themeMode,
      routerConfig: _router!,
    );
  }
}
