import 'dart:async';

import 'package:flutter/material.dart';
import 'app_preferences.dart';
import 'boot_store.dart';
enum AppThemePreference { system, light, dark }

/// Gece / gündüz / sistem teması tercihi.
class ThemePreferenceService extends ChangeNotifier {
  ThemePreferenceService._();
  static final ThemePreferenceService instance = ThemePreferenceService._();

  static const storageKey = 'theme_preference_v1';

  AppThemePreference _preference = AppThemePreference.system;
  bool _initialized = false;

  bool get isInitialized => _initialized;
  AppThemePreference get preference => _preference;

  ThemeMode get themeMode => switch (_preference) {
        AppThemePreference.system => ThemeMode.system,
        AppThemePreference.light => ThemeMode.light,
        AppThemePreference.dark => ThemeMode.dark,
      };

  String labelFor(AppThemePreference value) => switch (value) {
        AppThemePreference.system => 'Sistem',
        AppThemePreference.light => 'Gündüz',
        AppThemePreference.dark => 'Gece',
      };

  IconData iconFor(AppThemePreference value) => switch (value) {
        AppThemePreference.system => Icons.brightness_auto_outlined,
        AppThemePreference.light => Icons.light_mode_outlined,
        AppThemePreference.dark => Icons.dark_mode_outlined,
      };

  void applyBootSnapshot(BootSnapshot snapshot) {
    _preference = AppThemePreference.values.firstWhere(
      (p) => p.name == snapshot.themePreference,
      orElse: () => AppThemePreference.system,
    );
    _initialized = true;
    notifyListeners();
  }

  Future<void> initialize() async {
    final prefs = await AppPreferences.instance;
    final raw = prefs.getString(storageKey);
    if (raw != null) {
      _preference = AppThemePreference.values.firstWhere(
        (p) => p.name == raw,
        orElse: () => AppThemePreference.system,
      );
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> setPreference(AppThemePreference value) async {
    if (_preference == value) return;
    _preference = value;
    notifyListeners();
    final prefs = await AppPreferences.instance;
    await prefs.setString(storageKey, value.name);
    unawaited(BootStore.update(themePreference: value.name));
  }
}
