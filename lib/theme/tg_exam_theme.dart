import 'package:flutter/material.dart';

import 'app_theme.dart';

/// TG deneme — uygulama lacivert / şampanya paleti (quiz + karşılama).
abstract final class TgExamTheme {
  static const ink = AppTheme.ink;
  static const inkSoft = AppTheme.inkSoft;
  static const inkDeep = AppTheme.nightDeep;

  static const accent = AppTheme.champagne;
  static const accentLight = AppTheme.champagneLight;
  static const accentDeep = Color(0xFF9A7B45);
  static const accentMuted = Color(0xFF6B5A3E);

  /// Eski API uyumu — quiz ekranı bu isimleri kullanıyor.
  static const crimsonDeep = accentDeep;
  static const crimson = accent;
  static const crimsonBright = accentLight;
  static const roseGlow = accentLight;
  static const accentLine = accent;

  static const accentLineGradient = [
    accentDeep,
    accent,
    accentLight,
  ];

  static const welcomeBackdropGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF141E32),
      Color(0xFF162338),
      Color(0xFF121A2C),
      Color(0xFF0C1424),
    ],
    stops: [0.0, 0.35, 0.72, 1.0],
  );

  static const primaryButtonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFFE2C998),
      Color(0xFFC9A86C),
      Color(0xFFB8944A),
    ],
  );
}
