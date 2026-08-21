import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android FLAG_SECURE geçici aç/kapa — uygulama içi paylaşım görseli için.
class ScreenshotGate {
  ScreenshotGate._();

  static const _channel = MethodChannel('hedef_kamu/screenshot_gate');

  /// [allow] true iken sistem ekran görüntüsü serbest (yalnız kısa süre).
  static Future<void> setAllowed(bool allow) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('setAllowed', {'allow': allow});
    } catch (e) {
      debugPrint('ScreenshotGate: $e');
    }
  }

  static Future<T> runAllowingCapture<T>(Future<T> Function() action) async {
    await setAllowed(true);
    try {
      return await action();
    } finally {
      await setAllowed(false);
    }
  }
}
