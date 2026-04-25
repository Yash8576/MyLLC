// Native platform (iOS, Android, Desktop) configuration
import 'dart:io' show Platform;

class PlatformConfig {
  static String get baseHost {
    if (Platform.isAndroid) {
      // Android emulator: 10.0.2.2 maps to host machine's localhost
      return '10.0.2.2';
    } else {
      // iOS simulator, macOS, Windows, Linux: Use localhost
      return 'localhost';
    }
  }

  static String get initialRouteOverride => '';
}
