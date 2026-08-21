import 'package:flutter/material.dart';

import '../../theme/exam_typography.dart';
import '../../utils/turkish_hyphenation.dart';
import '../formatted_text.dart';
import 'option_column_layout.dart';

/// Badge diameter (CircleAvatar radius 14) + gap after badge in option rows.
const double kOptionBadgeLeadingWidth = 28 + 12;

/// Short / math-ish şık: larger type (default option is 15).
const double kCompactOptionFontSize = 18;

/// Visible-char threshold for compact (centered + larger) option layout.
const int kCompactOptionCharLimit = 20;

/// Şık metni — 15pt wrap (prose); kısa/math şıklar ortalı + daha büyük punto.
/// Eşleştirme satırında eşit sütun (yalnızca forceColumns) — tasarım korunur.
class ExamOptionView extends StatelessWidget {
  final String text;
  final int? forceColumns;

  const ExamOptionView({
    super.key,
    required this.text,
    this.forceColumns,
  });

  /// Compact when text is short (≤ [kCompactOptionCharLimit] visible chars
  /// after markup strip) **or** contains LaTeX `$` delimiters.
  /// Long Turkish prose stays start-aligned at normal option size.
  static bool isCompactOption(String text) {
    final visible = FormattedText.stripMarkup(text)
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (visible.isEmpty) return false;
    if (visible.contains(r'$')) return true;
    return visible.length <= kCompactOptionCharLimit;
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
    final raw = FormattedText.stripMarkup(text)
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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
                TurkishHyphenation.hyphenate(cells[i]),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ],
        ],
      );
    }

    final compact = isCompactOption(text);
    final style = ExamTypography.option(
      color: Colors.white,
      fontSize: compact ? kCompactOptionFontSize : 15,
    );

    return FormattedText(
      TurkishHyphenation.hyphenate(
        FormattedText.wrapBareLatex(FormattedText.stripMarkup(text)),
      ),
      examLayout: true,
      examWrap: true,
      textAlign: compact ? TextAlign.center : TextAlign.start,
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
