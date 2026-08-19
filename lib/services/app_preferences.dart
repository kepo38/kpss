import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences tek örnek — cold start'ta paralel getInstance gecikmesini önler.
class AppPreferences {
  AppPreferences._();

  static SharedPreferences? _instance;
  static Future<SharedPreferences>? _loading;
  static DateTime? _firstOpenAt;

  static const _kFirstOpenMs = 'device_first_open_ms_v1';

  static Future<SharedPreferences> get instance async {
    if (_instance != null) return _instance!;
    _loading ??= SharedPreferences.getInstance();
    _instance = await _loading!;
    return _instance!;
  }

  static Future<void> warmup() async {
    await instance;
    await firstOpenAt();
  }

  /// Cihaza ilk kurulum anı. Bundan önceki duyuru/mesaj profilde yok.
  static Future<DateTime> firstOpenAt() async {
    if (_firstOpenAt != null) return _firstOpenAt!;
    final prefs = await instance;
    final ms = prefs.getInt(_kFirstOpenMs);
    if (ms != null) {
      _firstOpenAt = DateTime.fromMillisecondsSinceEpoch(ms);
    } else {
      _firstOpenAt = DateTime.now();
      await prefs.setInt(_kFirstOpenMs, _firstOpenAt!.millisecondsSinceEpoch);
    }
    return _firstOpenAt!;
  }

  static bool isPreInstall(DateTime? createdAt) {
    final start = _firstOpenAt;
    if (createdAt == null || start == null) return false;
    return !createdAt.toUtc().isAfter(start.toUtc());
  }
}
