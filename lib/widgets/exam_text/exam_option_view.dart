import 'package:flutter/material.dart';

import '../../theme/exam_typography.dart';
import '../cached_remote_image.dart';
import '../formatted_text.dart';
import 'option_column_layout.dart';

/// Badge diameter (CircleAvatar radius 14) + gap after badge in option rows.
const double kOptionBadgeLeadingWidth = 28 + 12;

/// Matematik / kısa sayısal şık punto (normal şık 15).
const double kCompactOptionFontSize = 19;

/// Şık metni — ÖSYM hizası: uzun metin sola; matematik şıkları ortalı + sabit punto.
/// Eşleştirme satırında eşit sütun (yalnızca forceColumns).
class ExamOptionView extends StatelessWidget {
  final String text;
  final String? imageUrl;
  final int? forceColumns;

  const ExamOptionView({
    super.key,
    required this.text,
    this.imageUrl,
    this.forceColumns,
  });

  /// Yalnızca LaTeX `$…$` — eski kısa-metin eşiği kaldırıldı (hizayı bozuyordu).
  static bool isCompactOption(String text) {
    final visible = _visiblePlain(text);
    if (visible.isEmpty) return false;
    return visible.contains(r'$');
  }

  /// Matematik / kısa sayısal şık — ortalı büyük punto.
  static bool isMathStyleOption(String text, {String? imageUrl}) {
    if (imageUrl != null && imageUrl.trim().isNotEmpty) return false;
    if (isCompactOption(text)) return true;
    final visible = _visiblePlain(text);
    if (visible.isEmpty || visible.length > 56) return false;
    if (RegExp(r'^\d+$').hasMatch(visible)) return true;
    if (_isShortNumericOption(visible)) return true;
    return RegExp(r'[√⁄÷×±^_=\\]|\\sqrt|\\frac|\\dfrac|\\tfrac')
        .hasMatch(visible);
  }

  /// `0,1` · `0.5` · `-3/4` gibi kısa sayısal şıklar.
  static bool _isShortNumericOption(String visible) {
    if (visible.length > 16) return false;
    return RegExp(
      r'^-?\d+(?:[.,]\d+)?(?:\s*/\s*-?\d+(?:[.,]\d+)?)?$',
    ).hasMatch(visible);
  }

  static String _visiblePlain(String text) {
    return FormattedText.stripMarkup(text)
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _forcedCells(int columns) {
    final cells = OptionColumnLayout.cellsOf(text);
    if (cells != null && cells.length == columns) return cells;
    if (cells != null && cells.length > columns) {
      return cells.sublist(0, columns);
    }
    if (cells != null && cells.isNotEmpty) {
      return [
        ...cells,
        for (var i = cells.length; i < columns; i++) '',
      ];
    }
    final raw = _visiblePlain(text);
    if (raw.isEmpty) return List.filled(columns, '');
    final dashParts = raw
        .split(RegExp(r'\s+(?:[-–—―−]{1,3}|---+)\s+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (dashParts.length >= columns) {
      return dashParts.sublist(0, columns);
    }
    if (dashParts.length > 1) {
      return [
        ...dashParts,
        for (var i = dashParts.length; i < columns; i++) '',
      ];
    }
    return [
      raw,
      for (var i = 1; i < columns; i++) '',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 120, maxWidth: 280),
          child: CachedRemoteImage(
            imageUrl: url,
            fit: BoxFit.contain,
            // Köşe yuvarlama opak zemini “kutu” gibi gösterir; şeffaf PNG için kapalı.
            borderRadius: null,
            semanticLabel: 'Şık görseli',
          ),
        ),
      );
    }

    final columns = forceColumns;
    if (columns != null && columns >= 2) {
      final cells = _forcedCells(columns);
      final style = ExamTypography.option(color: Colors.white)
          .copyWith(fontWeight: FontWeight.w500, fontSize: 12, height: 1.2);
      return Row(
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Text(
                cells[i],
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ],
        ],
      );
    }

    final mathStyle = isMathStyleOption(text);
    final style = ExamTypography.option(
      color: Colors.white,
      fontSize: mathStyle ? kCompactOptionFontSize : 15,
    );

    // Şıklarda soft hyphen (TDK heceleme) kullanılmaz — Android/Tinos satır
    // kırılınca harfler üst üste binip boşluklar kaybolabiliyor.
    final wrapped = FormattedText.wrapBareLatex(FormattedText.stripMarkup(text));
    final prepared = FormattedText.prepareExamJustifyText(wrapped);
    return FormattedText(
      prepared,
      preserveLineBreaks: true,
      examLayout: true,
      examWrap: true,
      examScaleDown: false,
      textAlign: mathStyle ? TextAlign.center : TextAlign.start,
      style: style,
    );
  }
}

/// Şık listesinin üstünde İnanç / Mağara / Termal başlıkları.
class OptionColumnHeader extends StatelessWidget {
  final List<String> labels;

  const OptionColumnHeader({super.key, required this.labels});

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    final style = ExamTypography.option(color: const Color(0xFFE8C98A))
        .copyWith(fontWeight: FontWeight.w700, fontSize: 12, height: 1.2);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
      child: Row(
        children: [
          const SizedBox(width: kOptionBadgeLeadingWidth),
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Text(
                labels[i],
                textAlign: TextAlign.center,
                style: style,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
