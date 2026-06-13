import 'package:flutter/material.dart';

extension AppSnackBarMessenger on ScaffoldMessengerState {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
      showSingleSnackBar(
    SnackBar snackBar,
  ) {
    clearSnackBars();
    removeCurrentSnackBar();
    return showSnackBar(snackBar);
  }
}
