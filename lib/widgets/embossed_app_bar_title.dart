import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Koyu üst barda okunaklı, hafif kabartmalı altın başlık (Özet Konular, Test adı…).
class EmbossedAppBarTitle extends StatelessWidget {
  final String title;
  final int maxLines;
  final TextOverflow overflow;
  final bool alignLeft;

  const EmbossedAppBarTitle(
    this.title, {
    super.key,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.alignLeft = false,
  });

  static const _baseStyle = TextStyle(
    fontFamily: 'serif',
    fontWeight: FontWeight.w800,
    fontSize: 21,
    letterSpacing: 0.35,
    height: 1.05,
  );

  @override
  Widget build(BuildContext context) {
    final stackAlign = alignLeft ? Alignment.centerLeft : Alignment.center;
    final textAlign = alignLeft ? TextAlign.left : TextAlign.center;

    Widget layer(String text, TextStyle style) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
        style: style,
      );
    }

    final content = Stack(
      alignment: stackAlign,
      clipBehavior: Clip.none,
      children: [
        Transform.translate(
          offset: const Offset(0, 2.5),
          child: layer(
            title,
            _baseStyle.copyWith(
              color: Colors.black.withValues(alpha: 0.58),
            ),
          ),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF8E8),
              AppTheme.champagneLight,
              AppTheme.neonGold,
              AppTheme.champagne,
              Color(0xFFB8944A),
            ],
            stops: [0.0, 0.18, 0.42, 0.72, 1.0],
          ).createShader(bounds),
          child: layer(
            title,
            const TextStyle(
              fontFamily: 'serif',
              fontWeight: FontWeight.w800,
              fontSize: 21,
              letterSpacing: 0.35,
              height: 1.05,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Color(0xCCFFF5DC),
                  offset: Offset(0, -1),
                  blurRadius: 0,
                ),
                Shadow(
                  color: Color(0x55F7EED8),
                  offset: Offset(0, 1.5),
                  blurRadius: 5,
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (!alignLeft) return content;
    return Align(alignment: Alignment.centerLeft, widthFactor: 1, child: content);
  }
}
