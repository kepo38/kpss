import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Tüm alt sayfalarda kullanılan belirgin geri tuşu.
class AppBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? color;
  final Color? backgroundColor;
  final Color? borderColor;

  const AppBackButton({
    super.key,
    this.onPressed,
    this.color,
    this.backgroundColor,
    this.borderColor,
  });

  /// Koyu / neon zeminlerde okunaklı geri tuşu.
  factory AppBackButton.onDark({
    Key? key,
    VoidCallback? onPressed,
    Color accent = Colors.white,
  }) {
    return AppBackButton(
      key: key,
      onPressed: onPressed,
      color: accent.withValues(alpha: 0.96),
      backgroundColor: accent.withValues(alpha: 0.14),
      borderColor: accent.withValues(alpha: 0.38),
    );
  }

  @override
  Widget build(BuildContext context) {
    final iconColor =
        color ?? Theme.of(context).iconTheme.color ?? AppTheme.ink;

    Widget icon = Icon(Icons.arrow_back_ios_new, size: 20, color: iconColor);

    if (backgroundColor != null) {
      icon = Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: borderColor != null
              ? Border.all(color: borderColor!, width: 1)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(Icons.arrow_back_ios_new, size: 18, color: iconColor),
      );
    }

    return IconButton(
      icon: icon,
      tooltip: 'Geri',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
    );
  }
}
