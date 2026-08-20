import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'wrong_notebook_utils.dart';

class WrongNotebookSubjectFilter extends StatelessWidget {
  final List<(String subject, int count)> subjects;
  final int totalCount;
  final String? selectedSubject;
  final ValueChanged<String?> onChanged;

  final int minSubjectsToShow;
  final Color? defaultAccent;

  const WrongNotebookSubjectFilter({
    super.key,
    required this.subjects,
    required this.totalCount,
    required this.selectedSubject,
    required this.onChanged,
    this.minSubjectsToShow = 2,
    this.defaultAccent,
  });

  @override
  Widget build(BuildContext context) {
    if (subjects.length < minSubjectsToShow) return const SizedBox.shrink();

    final accent = defaultAccent ?? AppTheme.champagne;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _FilterPill(
            label: 'Tümü',
            count: totalCount,
            selected: selectedSubject == null,
            accent: accent,
            onTap: () => onChanged(null),
          ),
          const SizedBox(width: 8),
          ...subjects.map(
            (s) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _FilterPill(
                label: s.$1,
                count: s.$2,
                selected: selectedSubject == s.$1,
                accent: wrongNotebookSubjectAccent(s.$1),
                onTap: () => onChanged(
                  selectedSubject == s.$1 ? null : s.$1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final on = AppTheme.onPage(context);
    final card = AppTheme.surfaceCard(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected
              ? accent.withValues(alpha: 0.16)
              : card.withValues(alpha: 0.75),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.55)
                : AppTheme.hairline(context),
            width: selected ? 1.2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.14),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent,
                ),
              ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? on : on.withValues(alpha: 0.78),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: selected
                    ? on.withValues(alpha: 0.08)
                    : AppTheme.ink.withValues(alpha: 0.05),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: selected ? on : on.withValues(alpha: 0.55),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
