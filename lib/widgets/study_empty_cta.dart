import 'package:flutter/material.dart';

import '../data/kpss_curriculum.dart';
import '../screens/study_hub_screen.dart';
import '../theme/app_theme.dart';
import '../theme/subject_neon_palette.dart';
import 'countdown_widget.dart';
import 'scale_button.dart';

/// Boş liste durumlarında ders önerisi + test çöz CTA.
class StudyEmptyCta extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final KpssType kpssType;
  final bool light;

  const StudyEmptyCta({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.kpssType = KpssType.lisans,
    this.light = true,
  });

  Future<void> _openSubject(BuildContext context, KpssSubject subject) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SubjectTopicsScreen(
          kpssType: kpssType,
          subject: subject,
        ),
      ),
    );
  }

  Future<void> _openStudyHub(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudyHubScreen(kpssType: kpssType),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subjects = KpssCurriculum.subjectsFor(kpssType);
    final suggested = subjects.isNotEmpty ? subjects.first : null;
    final titleColor = light ? AppTheme.ink : Colors.white;
    final bodyColor = light
        ? AppTheme.slate.withValues(alpha: 0.75)
        : Colors.white.withValues(alpha: 0.55);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 52,
              color: light
                  ? AppTheme.slate.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: titleColor.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.5, color: bodyColor),
            ),
            if (suggested != null) ...[
              const SizedBox(height: 22),
              ScaleButton(
                onPressed: () => _openSubject(context, suggested),
                child: FilledButton.icon(
                  onPressed: () => _openSubject(context, suggested),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.champagne.withValues(alpha: 0.2),
                    foregroundColor: light ? AppTheme.ink : Colors.white,
                    side: BorderSide(
                      color: AppTheme.champagne.withValues(alpha: 0.65),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                  icon: Icon(
                    Icons.play_arrow_rounded,
                    color: SubjectNeonPalette.forSubject(suggested.id),
                  ),
                  label: Text('${suggested.name} dersinden 1 test çöz'),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => _openStudyHub(context),
                child: Text(
                  'Tüm dersleri gör',
                  style: TextStyle(
                    color: light ? AppTheme.champagne : AppTheme.champagneLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
