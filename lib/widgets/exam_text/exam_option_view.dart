import 'package:flutter/material.dart';

import '../../theme/exam_typography.dart';
import '../formatted_text.dart';
import 'option_column_layout.dart';

/// Şık metni — 15pt, wrap; eşleştirme satırında eşit sütun.
class ExamOptionView extends StatelessWidget {
  final String text;

  const ExamOptionView({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final cells = OptionColumnLayout.cellsOf(text);
    if (cells != null) {
      final style = ExamTypography.option(color: Colors.white);
      return Row(
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Text(
                cells[i],
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style.copyWith(fontSize: 12, height: 1.2),
              ),
            ),
          ],
        ],
      );
    }
    return FormattedText(
      FormattedText.wrapBareLatex(FormattedText.stripMarkup(text)),
      examLayout: true,
      examWrap: true,
      textAlign: TextAlign.start,
      style: ExamTypography.option(color: Colors.white),
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
        .copyWith(fontWeight: FontWeight.w700, fontSize: 12);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 16 + 28 + 12, right: 16),
      child: Row(
        children: [
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
