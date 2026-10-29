import 'package:flutter/material.dart';

import 'tokens.dart';

extension DesignContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;

  void toast(String message) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
