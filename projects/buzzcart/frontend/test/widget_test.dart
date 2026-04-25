// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:provider/provider.dart';

import 'package:buzz_social_cart/core/providers/add_product_provider.dart';
import 'package:buzz_social_cart/core/providers/app_refresh_provider.dart';
import 'package:buzz_social_cart/core/providers/auth_provider.dart';
import 'package:buzz_social_cart/core/providers/cart_provider.dart';
import 'package:buzz_social_cart/core/providers/theme_provider.dart';
import 'package:buzz_social_cart/core/providers/upload_content_provider.dart';
import 'package:buzz_social_cart/core/services/api_service.dart';
import 'package:buzz_social_cart/features/messages/providers/messages_provider.dart';
import 'package:buzz_social_cart/main.dart';

void main() {
  testWidgets('App builds smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>(
            create: (_) => ApiService(),
          ),
          ChangeNotifierProvider<ThemeProvider>(
            create: (_) => ThemeProvider(),
          ),
          ChangeNotifierProvider<AuthProvider>(
            create: (context) => AuthProvider(
              apiService: context.read<ApiService>(),
            ),
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

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
