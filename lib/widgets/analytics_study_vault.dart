import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'scale_button.dart';

/// Gelişim sekmesi — Yanlış / Favori / Not kısayolları (ink–champagne vault).
class AnalyticsStudyVault extends StatelessWidget {
  final int wrongCount;
  final int favoriteCount;
  final int notesCount;
  final VoidCallback onWrongTap;
  final VoidCallback onFavoritesTap;
  final VoidCallback onNotesTap;

  const AnalyticsStudyVault({
    super.key,
    required this.wrongCount,
    required this.favoriteCount,
    required this.notesCount,
    required this.onWrongTap,
    required this.onFavoritesTap,
    required this.onNotesTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.champagne.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppTheme.champagne.withValues(alpha: 0.22),
              width: 0.8,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.pageTop(context).withValues(alpha: 0.95),
                AppTheme.page(context),
                AppTheme.pageDeep(context).withValues(alpha: 0.9),
              ],
              stops: const [0, 0.5, 1],
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _VaultCell(
                    icon: Icons.menu_book_rounded,
                    label: 'Yanlış',
                    count: wrongCount,
                    accent: const Color(0xFFF87171),
                    onTap: onWrongTap,
                  ),
                ),
                _VaultDivider(),
                Expanded(
                  child: _VaultCell(
                    icon: Icons.favorite_rounded,
                    label: 'Favoriler',
                    count: favoriteCount,
                    accent: AppTheme.champagneLight,
                    onTap: onFavoritesTap,
                  ),
                ),
                _VaultDivider(),
                Expanded(
                  child: _VaultCell(
                    icon: Icons.sticky_note_2_rounded,
                    label: 'Notlarım',
                    count: notesCount,
                    accent: AppTheme.neonEdge,
                    onTap: onNotesTap,
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

class _VaultDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return VerticalDivider(
      width: 1,
      thickness: 0.5,
      indent: 18,
      endIndent: 18,
      color: AppTheme.champagne.withValues(alpha: 0.18),
    );
  }
}

class _VaultCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color accent;
  final VoidCallback onTap;

  const _VaultCell({
    required this.icon,
    required this.label,
    required this.count,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleButton(
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 16, 10, 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.14),
                border: Border.all(color: accent.withValues(alpha: 0.28)),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(height: 12),
            Text(
              '$count',
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 26,
                height: 1,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
                color: AppTheme.onPage(context).withValues(alpha: count == 0 ? 0.4 : 0.95),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
