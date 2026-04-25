import 'package:flutter/foundation.dart';

class AddProductProvider extends ChangeNotifier {
  bool _hasUnsavedWork = false;

  bool get hasUnsavedWork => _hasUnsavedWork;

  void markEdited() {
    if (_hasUnsavedWork) {
      return;
    }
    _hasUnsavedWork = true;
    notifyListeners();
  }

  void clearAll() {
    if (!_hasUnsavedWork) {
      return;
    }
    _hasUnsavedWork = false;
    notifyListeners();
  }

  void markAsSaved() {
    clearAll();
  }
}
