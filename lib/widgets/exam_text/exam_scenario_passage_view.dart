import 'package:flutter/material.dart';

import '../../theme/exam_typography.dart';
import '../../utils/turkish_hyphenation.dart';
import '../formatted_text.dart';

/// Olay kurgusu (ortak senaryo metni) — softWrap, punto sabit; FittedBox yok.
class ExamScenarioPassageView extends StatelessWidget {
  final String text;

  const ExamScenarioPassageView({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final prepared = FormattedText.looksLikeMath(text) || text.contains(r'$')
        ? text
        : TurkishHyphenation.hyphenate(text);
    return FormattedText(
      prepared,
      preserveLineBreaks: true,
      examLayout: true,
      examWrap: true,
      examScaleDown: false,
      textAlign: TextAlign.start,
      style: ExamTypography.body(
        color: Colors.white,
        fontSize: 15,
        height: 1.5,
      ),
    );
  }
}
