import 'dart:ui';

import 'package:flutter/material.dart';

/// E-postanın ilk 4–5 harfini buzlu (bulanık) gösterir.
class FrostedEmail extends StatelessWidget {
  final String prefix;
  final String rest;
  final TextStyle? style;

  const FrostedEmail({
    super.key,
    required this.prefix,
    required this.rest,
    this.style,
  });

  factory FrostedEmail.fromParts({
    required String prefix,
    required String rest,
    TextStyle? style,
  }) {
    return FrostedEmail(prefix: prefix, rest: rest, style: style);
  }

  @override
  Widget build(BuildContext context) {
    final base = style ??
        TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.9),
        );

    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 4.2, sigmaY: 4.2),
              child: Text(prefix, style: base),
            ),
          ),
          TextSpan(text: rest, style: base),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
