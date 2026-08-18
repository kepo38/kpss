import 'package:flutter/material.dart';

import '../../theme/exam_typography.dart';
import '../formatted_text.dart';

/// Çözüm metni — 15pt, wrap (yatay kesilme yok).
class ExamSolutionView extends StatelessWidget {
  final String text;

  const ExamSolutionView({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return FormattedText(
      text,
      preserveLineBreaks: true,
      examLayout: true,
      examWrap: true,
      examScaleDown: false,
      style: ExamTypography.solution(
        color: Colors.white.withValues(alpha: 0.92),
        fontSize: 15,
      ),
    );
  }
}
