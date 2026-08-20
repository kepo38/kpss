import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Stüdyo bölüm başlığı.
class HomeSectionHeader extends StatelessWidget {
  final String title;
  final String? eyebrow;
  final Widget? trailing;

  const HomeSectionHeader(
    this.title, {
    super.key,
    this.eyebrow,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null && eyebrow!.isNotEmpty) ...[
                Text(
                  eyebrow!.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: AppTheme.champagne.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                  height: 1.1,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
