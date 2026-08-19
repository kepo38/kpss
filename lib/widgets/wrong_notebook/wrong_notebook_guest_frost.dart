import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Misafir: yanlış sorular görünür ama buzlu; ortada giriş CTA.
class WrongNotebookGuestFrost extends StatelessWidget {
  final Widget child;
  final bool locked;
  final VoidCallback onSignIn;

  const WrongNotebookGuestFrost({
    super.key,
    required this.child,
    required this.locked,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    if (!locked) return child;

    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Opacity(opacity: 0.72, child: child),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppTheme.page(context).withValues(alpha: 0.28),
            ),
          ),
        ),
        Center(
          child: FilledButton(
            onPressed: onSignIn,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.champagne,
              foregroundColor: AppTheme.ink,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                fontSize: 15,
              ),
            ),
            child: const Text('GİRİŞ YAP'),
          ),
        ),
      ],
    );
  }
}
