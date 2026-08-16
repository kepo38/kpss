import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences tek örnek — cold start'ta paralel getInstance gecikmesini önler.
class AppPreferences {
  AppPreferences._();

  static SharedPreferences? _instance;
  static Future<SharedPreferences>? _loading;

  static Future<SharedPreferences> get instance async {
    if (_instance != null) return _instance!;
    _loading ??= SharedPreferences.getInstance();
    _instance = await _loading!;
    return _instance!;
  }

  static Future<void> warmup() async {
    await instance;
  }
}
