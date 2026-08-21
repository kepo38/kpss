import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ÖSYM sınav kitapçığı yazı standartları.
///
/// - Gövde / soru / şık: Times New Roman (mobilde [Tinos] yedek)
/// - Formül: Cambria Math karakterinde italik math (KaTeX / flutter_math glifleri)
/// - Tablo-şema harfi: Arial
abstract final class ExamTypography {
  /// Times New Roman — Android/iOS'ta [Google Fonts Tinos] (metrik uyumlu).
  static TextStyle body({
    required Color color,
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.w400,
    double height = 1.5,
  }) {
    return GoogleFonts.tinos(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      color: color,
    );
  }

  static TextStyle option({required Color color, double fontSize = 15}) {
    return body(
      color: color,
      fontSize: fontSize,
      height: 1.35,
      fontWeight: FontWeight.w400,
    );
  }

  static TextStyle solution({required Color color, double fontSize = 12}) {
    return body(
      color: color,
      fontSize: fontSize,
      height: 1.5,
    );
  }

  /// Formül harfleri gövde metniyle aynı biçim/punto (italik büyütme yok).
  static TextStyle mathFrom(TextStyle base) {
    return base.copyWith(fontStyle: FontStyle.normal);
  }

  /// Harita / şema üzerindeki harflendirme.
  static TextStyle sansLabel({
    required Color color,
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return TextStyle(
      fontFamily: 'Arial',
      fontFamilyFallback: const ['Helvetica', 'Roboto', 'sans-serif'],
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: 1.35,
      color: color,
    );
  }
}
