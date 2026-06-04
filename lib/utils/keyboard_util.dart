// lib/utils/keyboard_util.dart
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class KeyboardUtil {
  /// Paksa tampilkan keyboard software (berguna di emulator Android Studio)
  static Future<void> show() async {
    await SystemChannels.textInput.invokeMethod('TextInput.show');
  }

  /// Sembunyikan keyboard
  static void hide(BuildContext context) {
    FocusScope.of(context).unfocus();
  }
}