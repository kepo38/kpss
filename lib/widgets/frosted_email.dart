import 'package:flutter/material.dart';

/// E-posta: @ öncesinde ilk 3 harf açık, geri kalanı gizli.
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
          TextSpan(text: prefix, style: base),
          TextSpan(
            text: rest,
            style: base.copyWith(
              color: base.color?.withValues(alpha: 0.55),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
