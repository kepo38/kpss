import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/subject_neon_palette.dart';
import 'scale_button.dart';

/// Ana sayfa modül satırı (Diğer araçlar / Premium).
class HomeModuleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool locked;
  final bool accent;

  const HomeModuleRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.locked = false,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleButton(
      onPressed: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: SubjectNeonPalette.lightNeonModule(
          neon: accent ? AppTheme.neonEdge : AppTheme.champagne,
          accent: accent,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: accent
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.neonEdge.withValues(alpha: 0.32),
                          AppTheme.neonGold.withValues(alpha: 0.14),
                        ],
                      )
                    : null,
                color: accent ? null : AppTheme.ink.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: accent
                    ? Border.all(
                        color: AppTheme.neonEdge.withValues(alpha: 0.55),
                      )
                    : null,
                boxShadow: accent
                    ? SubjectNeonPalette.glow(AppTheme.neonEdge, blur: 8)
                    : null,
              ),
              child: Icon(
                icon,
                size: 22,
                color: accent ? AppTheme.neonEdge : AppTheme.ink,
              ),
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
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: accent ? Colors.white : AppTheme.ink,
                          ),
                        ),
                      ),
                      if (locked) ...const [
                        SizedBox(width: 6),
                        Icon(
                          Icons.lock,
                          size: 13,
                          color: AppTheme.champagne,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: accent
                          ? Colors.white.withValues(alpha: 0.72)
                          : AppTheme.slate,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: accent
                  ? AppTheme.neonEdge.withValues(alpha: 0.85)
                  : AppTheme.slate.withValues(alpha: 0.45),
            ),
          ],
        ),
      ),
    );
  }
}
