import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Yanlış defteri soru ekranı — süre yerindeki Not Al.
class QuizTakeNoteButton extends StatelessWidget {
  final bool hasNote;
  final VoidCallback onTap;

  const QuizTakeNoteButton({
    super.key,
    required this.hasNote,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.champagne.withValues(alpha: hasNote ? 0.28 : 0.16),
                    const Color(0xFF1C2A42).withValues(alpha: 0.9),
                  ],
                ),
                border: Border.all(
                  color: AppTheme.champagne.withValues(alpha: 0.55),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.champagne.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasNote
                        ? Icons.sticky_note_2_rounded
                        : Icons.edit_note_rounded,
                    size: 18,
                    color: AppTheme.champagneLight,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    hasNote ? 'Notum' : 'Not Al',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'KAYITLI KALIR',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.85,
            color: AppTheme.champagne.withValues(alpha: 0.78),
          ),
        ),
      ],
    );
  }
}
