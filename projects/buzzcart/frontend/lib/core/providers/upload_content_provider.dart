import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../models/models.dart';

class UploadContentProvider extends ChangeNotifier {
  String _selectedMediaType = 'photo';
  final List<XFile> _selectedFiles = [];
  final List<ProductModel> _taggedProducts = [];
  String _caption = '';
  bool _hasUnsavedWork = false;
  VoidCallback? _onUploadSuccess;
  String _photoAspectRatio = 'square'; // 'square', 'portrait', 'landscape'

  String get selectedMediaType => _selectedMediaType;
  List<XFile> get selectedFiles => List.unmodifiable(_selectedFiles);
  List<ProductModel> get taggedProducts => List.unmodifiable(_taggedProducts);
  String get caption => _caption;
  bool get hasUnsavedWork => _hasUnsavedWork;
  String get photoAspectRatio => _photoAspectRatio;

  void setOnUploadSuccess(VoidCallback? callback) {
    _onUploadSuccess = callback;
  }

  void notifyUploadSuccess() {
    _onUploadSuccess?.call();
    notifyListeners();
  }

  void setMediaType(String type) {
    _selectedMediaType = type;
    if (type != 'reel') {
      _taggedProducts.clear();
    }
    _hasUnsavedWork = true;
    notifyListeners();
  }

  void setPhotoAspectRatio(String ratio) {
    _photoAspectRatio = ratio;
    _hasUnsavedWork = true;
    notifyListeners();
  }

  void addFile(XFile file) {
    _selectedFiles.add(file);
    _hasUnsavedWork = true;
    notifyListeners();
  }

  void removeFile(int index) {
    if (index >= 0 && index < _selectedFiles.length) {
      _selectedFiles.removeAt(index);
      _hasUnsavedWork = _selectedFiles.isNotEmpty || _caption.isNotEmpty;
      notifyListeners();
    }
  }

  void setCaption(String text) {
    _caption = text;
    _hasUnsavedWork = text.isNotEmpty || _selectedFiles.isNotEmpty;
    notifyListeners();
  }

  void setTaggedProducts(List<ProductModel> products) {
    _taggedProducts
      ..clear()
      ..addAll(products);
    _hasUnsavedWork = _caption.isNotEmpty ||
        _selectedFiles.isNotEmpty ||
        _taggedProducts.isNotEmpty;
    notifyListeners();
  }

  void clearAll() {
    _selectedMediaType = 'photo';
    _selectedFiles.clear();
    _taggedProducts.clear();
    _caption = '';
    _photoAspectRatio = 'square';
    _hasUnsavedWork = false;
    notifyListeners();
  }

  void markAsSaved() {
    _hasUnsavedWork = false;
    notifyListeners();
  }
}
