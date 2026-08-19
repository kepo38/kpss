import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class WrongNotebookHeaderTitle extends StatelessWidget {
  const WrongNotebookHeaderTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final on = AppTheme.onPage(context);

    return Text(
      'Yanlış Defterim',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'serif',
        fontWeight: FontWeight.w700,
        fontSize: 17,
        height: 1.05,
        letterSpacing: -0.25,
        color: on,
      ),
    );
  }
}

class WrongNotebookHeaderPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool filled;
  final IconData? icon;

  const WrongNotebookHeaderPill({
    super.key,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final on = AppTheme.onPage(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: filled ? null : AppTheme.champagne.withValues(alpha: 0.1),
          gradient: filled
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF8E7C0),
                    Color(0xFFE2C998),
                    Color(0xFFC9A86C),
                  ],
                )
              : null,
          border: Border.all(
            color: filled
                ? const Color(0xFFD4AF6A)
                : AppTheme.champagne.withValues(alpha: 0.42),
          ),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: AppTheme.champagne.withValues(alpha: 0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: filled ? AppTheme.ink : on),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.05,
                height: 1.1,
                color: filled ? AppTheme.ink : on,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
