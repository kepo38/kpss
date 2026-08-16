import 'package:flutter/material.dart';

/// Hedef Kamu — premium görsel dil.
class AppTheme {
  AppTheme._();

  // Ink navy + champagne gold; neon kenar ışığı (kontrollü)
  static const Color ink = Color(0xFF0C1424);
  static const Color inkSoft = Color(0xFF162338);
  static const Color champagne = Color(0xFFC9A86C);
  static const Color champagneLight = Color(0xFFE2C998);
  static const Color neonEdge = Color(0xFF5EEAD4); // soğuk cyan kenar
  static const Color neonGold = Color(0xFFE8C87A);
  static const Color parchment = Color(0xFFF5F6F8);
  static const Color mist = Color(0xFFE8ECF2);
  static const Color slate = Color(0xFF5A6578);
  /// Ders kartları — füme duman gri
  static const Color smoke = Color(0xFF4B5059);
  static const Color smokeDeep = Color(0xFF3C4048);
  /// Ana kabuk / Soru-Özet-Deneme açık zemin
  static const Color cream = Color(0xFFF3F0EA);
  static const Color creamTop = Color(0xFFF7F3EC);
  static const Color creamDeep = Color(0xFFEEE8DF);
  static const Color night = Color(0xFF0C1424);
  static const Color nightTop = Color(0xFF141E32);
  static const Color nightDeep = Color(0xFF090F1A);

  // Geriye uyumluluk
  static const Color lightBackground = parchment;
  static const Color lightPrimary = ink;
  static const Color lightAccent = champagne;
  static const Color darkBackground = ink;
  static const Color darkCard = inkSoft;

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color page(BuildContext context) =>
      isDark(context) ? night : cream;

  static Color pageTop(BuildContext context) =>
      isDark(context) ? nightTop : creamTop;

  static Color pageDeep(BuildContext context) =>
      isDark(context) ? nightDeep : creamDeep;

  static Color onPage(BuildContext context) =>
      isDark(context) ? Colors.white : ink;

  static Color mutedOnPage(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.55)
      : slate;

  static Color surfaceCard(BuildContext context) =>
      isDark(context) ? inkSoft : Colors.white;

  static Color barSurface(BuildContext context) => isDark(context)
      ? inkSoft.withValues(alpha: 0.98)
      : Colors.white.withValues(alpha: 0.94);

  static Color hairline(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.1)
      : ink.withValues(alpha: 0.08);

  static const double borderRadius = 14.0;

  static TextStyle get displayStyle => const TextStyle(
        fontFamily: 'serif',
        fontWeight: FontWeight.w600,
        height: 0.95,
        letterSpacing: -1.5,
        color: ink,
      );

  static TextStyle get brandStyle => const TextStyle(
        fontFamily: 'serif',
        fontWeight: FontWeight.w700,
        height: 0.9,
        letterSpacing: -2,
        color: Colors.white,
      );

  static TextStyle get bodyStyle => const TextStyle(
        fontFamily: 'sans-serif',
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: slate,
      );

  static TextStyle get labelStyle => const TextStyle(
        fontFamily: 'sans-serif',
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: ink,
      );

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: ink,
      brightness: Brightness.light,
      primary: ink,
      secondary: champagne,
      surface: parchment,
    );

    // Sistem fontu — ilk açılışta Google Fonts ağı beklemesin.
    final baseText = ThemeData(brightness: Brightness.light).textTheme.apply(
          bodyColor: ink,
          displayColor: ink,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: parchment,
      textTheme: baseText,
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: parchment,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontFamily: 'serif',
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          textStyle: const TextStyle(
            fontFamily: 'sans-serif',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: champagne, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: mist,
        thickness: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: champagne,
      brightness: Brightness.dark,
      primary: champagne,
      secondary: champagneLight,
      surface: night,
    );

    final baseText = ThemeData(brightness: Brightness.dark).textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: night,
      textTheme: baseText,
      cardTheme: CardThemeData(
        elevation: 0,
        color: inkSoft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: night,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'serif',
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: champagne,
          foregroundColor: ink,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: champagneLight,
          side: BorderSide(color: champagne.withValues(alpha: 0.5), width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.12),
        thickness: 1,
      ),
    );
  }
}
