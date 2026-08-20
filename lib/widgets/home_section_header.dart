import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Stüdyo bölüm başlığı.
class HomeSectionHeader extends StatelessWidget {
  final String title;
  final String? eyebrow;
  final Widget? trailing;
  final Color? accent;

  const HomeSectionHeader(
    this.title, {
    super.key,
    this.eyebrow,
    this.trailing,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = accent ?? AppTheme.champagne;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null && eyebrow!.isNotEmpty) ...[
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 12,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      eyebrow!.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        color: accentColor.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
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
