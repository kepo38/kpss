import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Ders kartları için premium neon vurgu renkleri.
class SubjectNeonPalette {
  SubjectNeonPalette._();

  static Color forSubject(String subjectId) {
    return switch (subjectId) {
      'turkce' => AppTheme.neonEdge,
      'matematik' => const Color(0xFF38BDF8),
      'tarih' => AppTheme.neonGold,
      'cografya' => const Color(0xFF34D399),
      'vatandaslik' => const Color(0xFFA78BFA),
      'guncel' => const Color(0xFFFB7185),
      _ => AppTheme.champagneLight,
    };
  }

  static List<BoxShadow> glow(Color neon, {double blur = 18, double spread = 0}) {
    return [
      BoxShadow(
        color: neon.withValues(alpha: 0.42),
        blurRadius: blur,
        spreadRadius: spread,
      ),
      BoxShadow(
        color: neon.withValues(alpha: 0.14),
        blurRadius: blur * 2.2,
        spreadRadius: spread,
      ),
    ];
  }

  static BoxDecoration darkGlassCard({
    required Color neon,
    double radius = 18,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppTheme.smoke.withValues(alpha: 0.98),
          AppTheme.smokeDeep.withValues(alpha: 0.96),
        ],
      ),
      border: Border.all(color: neon.withValues(alpha: 0.55), width: 1.2),
      boxShadow: glow(neon, blur: 16),
    );
  }

  static BoxDecoration lightNeonModule({
    required Color neon,
    bool accent = false,
    double radius = 14,
  }) {
    if (!accent) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: Colors.white.withValues(alpha: 0.9),
        border: Border.all(color: AppTheme.ink.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.ink.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      );
    }

    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppTheme.smoke.withValues(alpha: 0.97),
          AppTheme.smokeDeep.withValues(alpha: 0.94),
        ],
      ),
      border: Border.all(color: neon.withValues(alpha: 0.5), width: 1.1),
      boxShadow: glow(neon, blur: 14),
    );
  }
}
