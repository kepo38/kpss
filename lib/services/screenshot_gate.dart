import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android FLAG_SECURE geçici aç/kapa — uygulama içi paylaşım görseli için.
class ScreenshotGate {
  ScreenshotGate._();

  static const _channel = MethodChannel('hedef_kamu/screenshot_gate');

  /// [allow] true iken sistem ekran görüntüsü serbest (yalnız kısa süre).
  /// Dönüş: native çağrı başarılıysa true; web/iOS’ta no-op true.
  static Future<bool> setAllowed(bool allow) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      await _channel.invokeMethod<void>('setAllowed', {'allow': allow});
      debugPrint('ScreenshotGate: setAllowed($allow) ok');
      return true;
    } catch (e) {
      debugPrint('ScreenshotGate: setAllowed($allow) FAIL $e');
      return false;
    }
  }

  static Future<T> runAllowingCapture<T>(Future<T> Function() action) async {
    final ok = await setAllowed(true);
    debugPrint('ScreenshotGate: runAllowingCapture begin ok=$ok');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    try {
      return await action();
    } finally {
      await setAllowed(false);
      debugPrint('ScreenshotGate: runAllowingCapture end (secure restored)');
    }
  }
}
