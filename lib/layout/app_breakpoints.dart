import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Telefon / tablet / geniş ekran kırılımları — tek kaynak.
class AppBreakpoints {
  AppBreakpoints._();

  /// Tablet ve üzeri (kısa kenar veya genişlik).
  static const double tabletMinWidth = 600;

  /// 3 sütunlu ders grid'i için fiziksel genişlik eşiği.
  static const double wideMinWidth = 900;

  /// Web önizleme çerçevesi (mevcut davranış korunur).
  static const double webFrameMaxWidth = 430;

  /// Tablet'te ortalanmış içerik sütunu.
  static const double tabletContentMaxWidth = 560;

  /// Geniş tablette 3'lü grid için biraz daha ferah sütun.
  static const double wideContentMaxWidth = 720;

  static double screenWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static bool isTablet(BuildContext context) =>
      screenWidth(context) >= tabletMinWidth;

  static bool isWide(BuildContext context) =>
      screenWidth(context) >= wideMinWidth;

  static bool shouldFrameNativeTablet(BuildContext context) =>
      !kIsWeb && isTablet(context);

  /// Uygulama içeriğinin maksimum genişliği.
  static double contentMaxWidth(BuildContext context) {
    if (kIsWeb) return webFrameMaxWidth;
    final w = screenWidth(context);
    if (w >= wideMinWidth) return wideContentMaxWidth;
    if (w >= tabletMinWidth) return tabletContentMaxWidth;
    return w;
  }

  /// Dersler ekranı grid sütun sayısı (içerik sütunu genişliğine göre).
  static int subjectGridColumns(BuildContext context) {
    final frameW = contentMaxWidth(context);
    // Tablet çerçevesi (~560px) içinde 3 kart okunaklı; telefonda 2.
    if (frameW >= 540) return 3;
    return 2;
  }

  static double subjectGridAspectRatio(int columns) =>
      columns >= 3 ? 1.05 : 1.28;

  static EdgeInsets quizOptionPadding(
    BuildContext context, {
    required bool mathStyle,
  }) {
    if (!isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 16, vertical: 14);
    }
    return EdgeInsets.symmetric(
      horizontal: 16,
      vertical: mathStyle ? 8 : 10,
    );
  }

  static double quizOptionMinHeight(
    BuildContext context, {
    required bool mathStyle,
  }) {
    if (!mathStyle) return 0;
    return isTablet(context) ? 40 : 52;
  }

  /// Yanlış defteri kart önizlemesi — tablette daha fazla satır.
  static int wrongNotebookPreviewMaxLines(BuildContext context) =>
      isTablet(context) ? 5 : 3;
}
