import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'app_visibility_listener.dart';

class AppVisibilityListenerImpl implements AppVisibilityListener {
  JSFunction? _visibilityListener;
  JSFunction? _focusListener;
  JSFunction? _blurListener;

  @override
  void start(void Function(bool isVisible) onVisibilityChanged) {
    dispose();

    _visibilityListener = ((web.Event _) {
      onVisibilityChanged(!web.document.hidden);
    }).toJS;
    _focusListener = ((web.Event _) {
      onVisibilityChanged(true);
    }).toJS;
    _blurListener = ((web.Event _) {
      onVisibilityChanged(false);
    }).toJS;

    web.document.addEventListener(
      'visibilitychange',
      _visibilityListener,
    );
    web.window.addEventListener('focus', _focusListener);
    web.window.addEventListener('blur', _blurListener);
  }

  @override
  void dispose() {
    if (_visibilityListener != null) {
      web.document.removeEventListener(
        'visibilitychange',
        _visibilityListener,
      );
    }
    if (_focusListener != null) {
      web.window.removeEventListener('focus', _focusListener);
    }
    if (_blurListener != null) {
      web.window.removeEventListener('blur', _blurListener);
    }

    _visibilityListener = null;
    _focusListener = null;
    _blurListener = null;
  }
}
