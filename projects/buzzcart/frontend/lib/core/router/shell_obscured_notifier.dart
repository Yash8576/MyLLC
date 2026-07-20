import 'package:flutter/widgets.dart';

/// Tracks whether the main navigation shell (bottom nav / sidebar + branch
/// content) is currently covered by a route pushed on top of it on the root
/// navigator — e.g. Cart, Messages, Search, Settings. Those routes render
/// over the whole shell but don't change `StatefulNavigationShell.currentIndex`,
/// so widgets that only look at the active branch (like the inline reel
/// player) would otherwise keep playing underneath them.
///
/// Driven by [MainLayout] subscribing itself to [shellRouteObserver] via
/// [RouteAware] — `didPushNext`/`didPopNext` fire specifically for the
/// shell's own route being obscured/revealed, unlike a generic push/pop
/// depth counter which also fires for unrelated navigator churn (splash/auth
/// redirects, nested branch navigation) and would get this wrong.
final ValueNotifier<bool> shellObscuredNotifier = ValueNotifier<bool>(false);

/// Registered as a `NavigatorObserver` on the root [GoRouter] so [MainLayout]
/// can subscribe to changes affecting its own route via [RouteAware].
final RouteObserver<ModalRoute<dynamic>> shellRouteObserver =
    RouteObserver<ModalRoute<dynamic>>();
