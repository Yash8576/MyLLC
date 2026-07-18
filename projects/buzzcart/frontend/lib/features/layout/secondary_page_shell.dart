import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'app_sidebar.dart';

/// Wraps a "sidebar destination" page (search / messages / cart / settings).
///
/// On desktop widths it renders the persistent [AppSidebar] alongside the page
/// so those screens feel like part of the app shell. On smaller widths it
/// returns the page unchanged, so it behaves as a standalone full-screen page
/// with its own back button and no bottom navigation.
class SecondaryPageShell extends StatelessWidget {
  /// The route path of the wrapped page, used to highlight the sidebar item.
  final String currentPath;
  final Widget child;

  const SecondaryPageShell({
    super.key,
    required this.currentPath,
    required this.child,
  });

  void _navigate(BuildContext context, String path) {
    // "On-top" flows are pushed so they keep a back button over this page;
    // every other destination replaces the current standalone route.
    if (path == '/add-product' || path == '/upload-content') {
      context.push(path);
    } else {
      context.go(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    if (!isDesktop) {
      return child;
    }

    return Scaffold(
      body: Row(
        children: [
          AppSidebar(
            currentPath: currentPath,
            onNavigate: (path) => _navigate(context, path),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
