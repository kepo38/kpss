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
    final cleaned = TurkishHyphenation.hyphenate(
      FormattedText.prepareExamJustifyText(
        OptionColumnLayout.visibleStem(text),
      ),
    );
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
