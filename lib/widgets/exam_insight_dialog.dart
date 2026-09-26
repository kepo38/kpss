import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/exam_insight.dart';
import '../theme/app_theme.dart';

Future<void> showExamInsightDialog(
  BuildContext context,
  ExamInsight insight,
) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          Icon(Icons.insights_outlined, color: AppTheme.lightPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Deneme analizi',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: Text(
        insight.message,
        style: GoogleFonts.inter(
          fontSize: 15,
          height: 1.45,
          color: AppTheme.ink.withValues(alpha: 0.92),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Tamam'),
        ),
      ],
    ),
  );
}
