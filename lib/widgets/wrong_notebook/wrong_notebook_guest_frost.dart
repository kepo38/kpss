import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Misafir: yalnızca soru metni hafif buzlu; kalp / benzer açık kalır.
class WrongNotebookGuestFrost extends StatelessWidget {
  final Widget child;
  final bool locked;

  const WrongNotebookGuestFrost({
    super.key,
    required this.child,
    required this.locked,
  });

  @override
  Widget build(BuildContext context) {
    if (!locked) return child;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: IgnorePointer(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 2.4, sigmaY: 2.4),
          child: Opacity(opacity: 0.92, child: child),
        ),
      ),
    );
  }
}
