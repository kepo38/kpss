import 'package:flutter/material.dart';

/// TG deneme oturumu — kırmızı / siyah premium palet (karşılama + quiz).
abstract final class TgExamTheme {
  static const ink = Color(0xFF12080C);
  static const inkSoft = Color(0xFF1A0A10);
  static const crimsonDeep = Color(0xFF6B0F1A);
  static const crimson = Color(0xFF9B1B2E);
  static const crimsonBright = Color(0xFFC41E3A);
  static const roseGlow = Color(0xFFFF6B7A);
  static const accentLight = Color(0xFFFF8A96);

  static const accentLineGradient = [
    crimsonDeep,
    crimsonBright,
    roseGlow,
  ];
}
