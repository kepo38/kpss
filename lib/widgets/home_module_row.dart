import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'scale_button.dart';

/// Stüdyo hub modül satırı — ink zemin, champagne vurgu.
class HomeModuleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool locked;
  final bool accent;
  final bool premiumTone;

  const HomeModuleRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.locked = false,
    this.accent = false,
    this.premiumTone = false,
  });

  @override
  Widget build(BuildContext context) {
    final gold = premiumTone || locked;
    final iconColor = gold ? AppTheme.champagneLight : const Color(0xFFB8C0CC);
    final titleColor = Colors.white.withValues(alpha: 0.94);
    final subColor = Colors.white.withValues(alpha: 0.48);

    return ScaleButton(
      onPressed: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gold
                ? [
                    const Color(0xFF1A2438),
                    const Color(0xFF141C2C),
                    const Color(0xFF101824),
                  ]
                : [
                    const Color(0xFF161E2E),
                    const Color(0xFF121A28),
                  ],
          ),
          border: Border.all(
            color: gold
                ? AppTheme.champagne.withValues(alpha: 0.38)
                : Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: gold
                  ? AppTheme.champagne.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.22),
              blurRadius: gold ? 16 : 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gold
                      ? [
                          AppTheme.champagne.withValues(alpha: 0.28),
                          AppTheme.champagne.withValues(alpha: 0.08),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.1),
                          Colors.white.withValues(alpha: 0.03),
                        ],
                ),
                border: Border.all(
                  color: gold
                      ? AppTheme.champagne.withValues(alpha: 0.45)
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Icon(icon, size: 22, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 16.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            height: 1.15,
                            color: titleColor,
                          ),
                        ),
                      ),
                      if (locked) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: AppTheme.champagne.withValues(alpha: 0.14),
                            border: Border.all(
                              color: AppTheme.champagne.withValues(alpha: 0.35),
                            ),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: AppTheme.champagneLight,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.3,
                      color: subColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13,
              color: gold
                  ? AppTheme.champagne.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.28),
            ),
          ],
        ),
      ),
    );
  }
}
