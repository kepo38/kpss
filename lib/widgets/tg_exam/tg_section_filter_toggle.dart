import 'package:flutter/material.dart';

import '../../theme/tg_exam_theme.dart';

/// TG deneme üst şeridi — GY (1–60) / GK (61–120) bölüm filtresi.
enum TgSectionFilter { all, gy, gk }

class TgSectionFilterToggle extends StatelessWidget {
  final TgSectionFilter selected;
  final ValueChanged<TgSectionFilter> onChanged;

  const TgSectionFilterToggle({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  void _tap(TgSectionFilter target) {
    onChanged(selected == target ? TgSectionFilter.all : target);
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.black.withValues(alpha: 0.35),
        border: Border.all(
          color: TgExamTheme.accent.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: TgExamTheme.accent.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Segment(
              label: 'GY',
              selected: selected == TgSectionFilter.gy,
              onTap: () => _tap(TgSectionFilter.gy),
            ),
            Container(
              width: 1,
              height: 30,
              color: TgExamTheme.accent.withValues(alpha: 0.28),
            ),
            _Segment(
              label: 'GK',
              selected: selected == TgSectionFilter.gk,
              onTap: () => _tap(TgSectionFilter.gk),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? TgExamTheme.accent.withValues(alpha: 0.92)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: selected
                  ? TgExamTheme.ink
                  : TgExamTheme.accentLight.withValues(alpha: 0.88),
            ),
          ),
        ),
      ),
    );
  }
}
