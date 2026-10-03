import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class DailyMiniExamSubjectMix extends StatelessWidget {
  const DailyMiniExamSubjectMix({super.key});

  static const _subjects = [
    ('Tarih', '5'),
    ('Coğrafya', '5'),
    ('Vatandaşlık', '5'),
    ('Türkçe', '5'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _SubjectTile(
                name: _subjects[0].$1,
                count: _subjects[0].$2,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SubjectTile(
                name: _subjects[1].$1,
                count: _subjects[1].$2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _SubjectTile(
                name: _subjects[2].$1,
                count: _subjects[2].$2,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SubjectTile(
                name: _subjects[3].$1,
                count: _subjects[3].$2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SubjectTile extends StatelessWidget {
  final String name;
  final String count;

  const _SubjectTile({
    required this.name,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);
    final titleColor = AppTheme.onPage(context);
    final tileFill = dark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.96);
    final tileBorder = dark
        ? AppTheme.champagne.withValues(alpha: 0.24)
        : AppTheme.champagne.withValues(alpha: 0.4);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: tileFill,
        border: Border.all(color: tileBorder),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: AppTheme.ink.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
                color: titleColor,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: AppTheme.champagne.withValues(alpha: dark ? 0.16 : 0.14),
              border: Border.all(
                color: AppTheme.champagne.withValues(alpha: dark ? 0.35 : 0.42),
              ),
            ),
            child: Text(
              count,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.15,
                color: dark ? AppTheme.champagneLight : const Color(0xFF8F6E32),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
