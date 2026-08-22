import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'scale_button.dart';

/// Stüdyo hub modül satırı — renkli ikon kutusu + ink zemin.
class HomeModuleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool locked;
  final bool disabled;
  final bool accent;
  final bool premiumTone;
  final Color? tint;

  const HomeModuleRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.locked = false,
    this.disabled = false,
    this.accent = false,
    this.premiumTone = false,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final inactive = disabled;
    final gold = !inactive && (premiumTone || locked);
    final tintColor = tint ??
        (gold ? AppTheme.champagne : AppTheme.neonEdge);
    final iconColor = inactive
        ? Colors.white.withValues(alpha: 0.35)
        : (gold ? AppTheme.champagneLight : tintColor);
    final titleColor = Colors.white.withValues(alpha: inactive ? 0.42 : 0.96);
    final subColor = Colors.white.withValues(alpha: inactive ? 0.32 : 0.52);
    final effectiveSubtitle =
        inactive ? 'Geçici olarak kapalı' : subtitle;

    return ScaleButton(
      onPressed: inactive ? null : onTap,
      child: Opacity(
        opacity: inactive ? 0.55 : 1,
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
                    Color.lerp(const Color(0xFF1A2438), tintColor, 0.12)!,
                    const Color(0xFF121A28),
                  ]
                : [
                    Color.lerp(const Color(0xFF182234), tintColor, 0.14)!,
                    const Color(0xFF101824),
                  ],
          ),
          border: Border.all(
            color: gold
                ? AppTheme.champagne.withValues(alpha: 0.42)
                : tintColor.withValues(alpha: 0.28),
            width: 1.05,
          ),
          boxShadow: [
            BoxShadow(
              color: tintColor.withValues(alpha: gold ? 0.14 : 0.1),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    tintColor.withValues(alpha: 0.42),
                    tintColor.withValues(alpha: 0.12),
                  ],
                ),
                border: Border.all(
                  color: tintColor.withValues(alpha: 0.55),
                ),
                boxShadow: [
                  BoxShadow(
                    color: tintColor.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
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
                      if (inactive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: const Color(0xFF64748B).withValues(alpha: 0.22),
                            border: Border.all(
                              color: const Color(0xFF94A3B8).withValues(alpha: 0.45),
                            ),
                          ),
                          child: Text(
                            'PASİF',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                      ] else if (locked) ...[
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
                    effectiveSubtitle,
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
              color: tintColor.withValues(alpha: 0.75),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
