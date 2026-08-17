import 'package:flutter/material.dart';

import '../data/kpss_curriculum.dart';
import '../screens/study_hub_screen.dart';
import '../services/content_bank_service.dart';
import 'countdown_widget.dart';
import '../theme/app_theme.dart';
import '../theme/subject_neon_palette.dart';

/// Ana sayfa ders chip ızgarası.
class HomeSubjectChipGrid extends StatelessWidget {
  final KpssType kpssType;
  final void Function(KpssSubject subject) onSubjectTap;

  const HomeSubjectChipGrid({
    super.key,
    required this.kpssType,
    required this.onSubjectTap,
  });

  @override
  Widget build(BuildContext context) {
    final subjects = KpssCurriculum.subjectsFor(kpssType);
    final bank = ContentBankService.instance;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final subject in subjects)
          _HomeSubjectChip(
            name: subject.name,
            icon: subjectIcon(subject.id),
            neon: SubjectNeonPalette.forSubject(subject.id),
            subtitle:
                '${bank.catalogQuestionCountForSubject(kpssType, subject.id)} soru',
            onTap: () => onSubjectTap(subject),
          ),
      ],
    );
  }
}

class _HomeSubjectChip extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color neon;
  final String subtitle;
  final VoidCallback onTap;

  const _HomeSubjectChip({
    required this.name,
    required this.icon,
    required this.neon,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          width: (MediaQuery.sizeOf(context).width - 18 * 2 - 6) / 2,
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.inkSoft.withValues(alpha: 0.96),
                AppTheme.ink.withValues(alpha: 0.94),
              ],
            ),
            border: Border.all(color: neon.withValues(alpha: 0.5)),
            boxShadow: SubjectNeonPalette.glow(neon, blur: 7),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: neon),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: neon.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
