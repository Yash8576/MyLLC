import 'package:flutter/foundation.dart';

class AppRefreshProvider extends ChangeNotifier {
  int _contentVersion = 0;
  int _productVersion = 0;

  int get contentVersion => _contentVersion;
  int get productVersion => _productVersion;

  void notifyContentPublished() {
    _contentVersion++;
    notifyListeners();
  }

  void notifyProductPublished() {
    _productVersion++;
    notifyListeners();
  }
}
