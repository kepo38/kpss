import 'package:flutter/material.dart';

import '../../theme/exam_typography.dart';
import '../formatted_text.dart';

/// Şık metni — 14pt, wrap.
class ExamOptionView extends StatelessWidget {
  final String text;

  const ExamOptionView({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return FormattedText(
      FormattedText.wrapBareLatex(FormattedText.stripMarkup(text)),
      examLayout: true,
      examWrap: true,
      style: ExamTypography.option(color: Colors.white),
    );
  }
}
