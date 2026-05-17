import 'app_visibility_listener_stub.dart'
    if (dart.library.html) 'app_visibility_listener_web.dart';

abstract class AppVisibilityListener {
  factory AppVisibilityListener() = AppVisibilityListenerImpl;

  void start(void Function(bool isVisible) onVisibilityChanged);
  void dispose();
}
