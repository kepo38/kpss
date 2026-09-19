import 'package:flutter/material.dart';

import '../../theme/tg_exam_theme.dart';
import '../../utils/tg_exam_subject_filter.dart';
import 'tg_section_filter_toggle.dart';

/// GY / GK seçiliyken soru numaralarının üstünde ders filtresi.
class TgSubjectFilterBar extends StatelessWidget {
  final TgSectionFilter section;
  final String? selectedSubjectKey;
  final Map<String, int> subjectCounts;
  final ValueChanged<String?> onChanged;

  const TgSubjectFilterBar({
    super.key,
    required this.section,
    required this.selectedSubjectKey,
    required this.subjectCounts,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final keys = TgExamSubjectKeys.forSection(section);
    if (keys.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [
                TgExamTheme.accent.withValues(alpha: 0.16),
                TgExamTheme.accentDeep.withValues(alpha: 0.08),
              ],
            ),
            border: Border.all(
              color: TgExamTheme.accent.withValues(alpha: 0.38),
            ),
            boxShadow: [
              BoxShadow(
                color: TgExamTheme.accent.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final key in keys)
                  _SubjectPill(
                    label: TgExamSubjectKeys.labelFor(key),
                    count: subjectCounts[key] ?? 0,
                    selected: selectedSubjectKey == key,
                    onTap: () => onChanged(
                      selectedSubjectKey == key ? null : key,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubjectPill extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _SubjectPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: selected ? TgExamTheme.primaryButtonGradient : null,
            color: selected ? null : Colors.black.withValues(alpha: 0.22),
            border: Border.all(
              color: selected
                  ? TgExamTheme.accentLight.withValues(alpha: 0.85)
                  : TgExamTheme.accent.withValues(alpha: 0.42),
              width: selected ? 1.4 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: TgExamTheme.accent.withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.25,
                  color: selected ? TgExamTheme.ink : TgExamTheme.accentLight,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected
                        ? TgExamTheme.ink.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? TgExamTheme.ink
                          : Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
