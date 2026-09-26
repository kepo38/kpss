import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native screenshot QA allowlist ile aynı cihazlar (VPN uyarısından muaf).
class DevDeviceAllowlist {
  DevDeviceAllowlist._();

  static const _channel = MethodChannel('hedef_kamu/screenshot_gate');
  static bool? _cached;

  static Future<bool> isExempt() async {
    if (kIsWeb) return false;
    if (_cached != null) return _cached!;
    if (defaultTargetPlatform != TargetPlatform.android) {
      _cached = false;
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>('isDevAllowlisted');
      _cached = result == true;
    } catch (_) {
      _cached = false;
    }
    return _cached!;
  }

  @visibleForTesting
  static void debugResetCache() => _cached = null;
}
