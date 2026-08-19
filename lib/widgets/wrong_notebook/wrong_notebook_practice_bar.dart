import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../scale_button.dart';

class WrongNotebookPracticeBar extends StatelessWidget {
  final int questionCount;
  final VoidCallback onPracticeAll;

  const WrongNotebookPracticeBar({
    super.key,
    required this.questionCount,
    required this.onPracticeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.barSurface(context),
        border: Border(
          top: BorderSide(color: AppTheme.hairline(context)),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.ink.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: ScaleButton(
          onPressed: onPracticeAll,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPracticeAll,
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFF8E7C0),
                      Color(0xFFE2C998),
                      Color(0xFFC9A86C),
                    ],
                  ),
                  border: Border.all(color: const Color(0xFFD4AF6A)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.play_arrow_rounded,
                      color: AppTheme.ink,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tüm yanlışları çöz ($questionCount)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: AppTheme.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
