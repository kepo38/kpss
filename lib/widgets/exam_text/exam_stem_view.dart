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
    final wrapped = FormattedText.wrapBareLatex(
      FormattedText.stripMarkup(visible),
    );
    final prepared = FormattedText.prepareExamJustifyText(wrapped);
    // Matematik / LaTeX köklerde TDK hecelemesi yapma (şıklarla aynı kural).
    final cleaned = FormattedText.looksLikeMath(prepared) ||
            prepared.contains(r'$')
        ? prepared
        : TurkishHyphenation.hyphenate(prepared);
    return FormattedText(
      cleaned,
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
