import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/subject_neon_palette.dart';

/// Ana sayfa bölüm başlığı (neon çubuk + serif başlık).
class HomeSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const HomeSectionHeader(this.title, {super.key, this.trailing});

  static const _titleStyle = TextStyle(
    fontFamily: 'serif',
    fontSize: 26,
    fontWeight: FontWeight.w600,
    color: AppTheme.ink,
    letterSpacing: -0.5,
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 22,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppTheme.neonEdge, AppTheme.champagne],
            ),
            boxShadow: SubjectNeonPalette.glow(AppTheme.neonEdge, blur: 6),
          ),
        ),
        const SizedBox(width: 10),
        Text(title, style: _titleStyle),
        if (trailing != null) ...[
          const SizedBox(width: 10),
          trailing!,
        ],
      ],
    );
  }
}
