import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'scale_button.dart';

/// Gelişim sekmesi — Yanlış / Favori / Not kısayolları.
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
    return Row(
      children: [
        Expanded(
          child: _VaultTile(
            icon: Icons.menu_book_rounded,
            label: 'Yanlış',
            count: wrongCount,
            gradient: const [
              Color(0xFFFFF1F1),
              Color(0xFFFFE4E4),
            ],
            accent: const Color(0xFFDC2626),
            accentSoft: const Color(0xFFF87171),
            onTap: onWrongTap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _VaultTile(
            icon: Icons.favorite_rounded,
            label: 'Favoriler',
            count: favoriteCount,
            gradient: const [
              Color(0xFFFFF8EE),
              Color(0xFFFAEFDC),
            ],
            accent: const Color(0xFFB8944A),
            accentSoft: AppTheme.champagne,
            onTap: onFavoritesTap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _VaultTile(
            icon: Icons.sticky_note_2_rounded,
            label: 'Notlarım',
            count: notesCount,
            gradient: const [
              Color(0xFFEEF8FF),
              Color(0xFFE0F2FE),
            ],
            accent: const Color(0xFF0284C7),
            accentSoft: AppTheme.neonEdge,
            onTap: onNotesTap,
          ),
        ),
      ],
    );
  }
}

class _VaultTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final List<Color> gradient;
  final Color accent;
  final Color accentSoft;
  final VoidCallback onTap;

  const _VaultTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.gradient,
    required this.accent,
    required this.accentSoft,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final on = AppTheme.onPage(context);

    return ScaleButton(
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          border: Border.all(color: accent.withValues(alpha: 0.14)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accentSoft.withValues(alpha: 0.95),
                    accent,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, size: 19, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: accent,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '$count',
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 28,
                height: 1,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
                color: on.withValues(alpha: count == 0 ? 0.35 : 0.95),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
