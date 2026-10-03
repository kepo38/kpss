import 'package:flutter/material.dart';

import '../../theme/exam_typography.dart';
import '../../utils/turkish_hyphenation.dart';
import '../formatted_text.dart';
import 'option_column_layout.dart';

/// Soru kökü — soft satırlar birleşir, Android/iOS'ta TextAlign.justify.
class ExamStemView extends StatelessWidget {
  final String text;

  const ExamStemView({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final visible = OptionColumnLayout.visibleStem(text);
    // stripMarkup çağırma — panel `**kalın**` / `__altı çizili__` işaretlerini
    // telefonda FormattedText._parseMarkdown ile uygular; strip edersek düz görünür.
    final wrapped = FormattedText.wrapBareLatex(visible);
    final prepared = FormattedText.prepareStoredExamJustifyText(wrapped);
    // Matematik / LaTeX köklerde TDK hecelemesi yapma (şıklarla aynı kural).
    final cleaned = FormattedText.looksLikeMath(prepared) ||
            prepared.contains(r'$')
        ? prepared
        : TurkishHyphenation.hyphenate(prepared);
    return FormattedText(
      cleaned,
      preNormalized: true,
      preserveLineBreaks: true,
      examLayout: true,
      examWrap: true,
      examScaleDown: false,
      textAlign: TextAlign.justify,
      style: ExamTypography.body(
        color: Colors.white,
        fontSize: 18,
        height: 1.5,
      ),
    );
  }
}
