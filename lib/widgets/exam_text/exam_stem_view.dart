import 'package:flutter/material.dart';

import '../../theme/exam_typography.dart';
import '../formatted_text.dart';
import 'option_column_layout.dart';

/// Soru kökü — panel önizlemesi ile aynı: 18pt, satır kırılımı, wrap.
class ExamStemView extends StatelessWidget {
  final String text;

  const ExamStemView({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return FormattedText(
      OptionColumnLayout.visibleStem(text),
      preserveLineBreaks: true,
      examLayout: true,
      examWrap: true,
      style: ExamTypography.body(
        color: Colors.white,
        fontSize: 18,
        height: 1.5,
      ),
    );
  }
}
