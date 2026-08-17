import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/brand_constants.dart';
import '../theme/app_theme.dart';

/// Soru kökünün arkasında, metin alanını kaplayan 45° filigran (şıklar hariç).
class WatermarkWidget extends StatelessWidget {
  static const logoAsset = BrandConstants.watermarkAsset;

  final Widget child;
  final double opacity;

  const WatermarkWidget({
    super.key,
    required this.child,
    this.opacity = 0.28,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: LayoutBuilder(
              builder: (context, box) {
                if (!box.hasBoundedWidth ||
                    !box.hasBoundedHeight ||
                    box.maxWidth <= 0 ||
                    box.maxHeight <= 0) {
                  return const SizedBox.shrink();
                }
                return _CoveringWatermarkLayer(
                  width: box.maxWidth,
                  height: box.maxHeight,
                  opacity: opacity,
                );
              },
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Metin gövdesinin tamamını aralıklı markalarla örter (tek boş nokta bırakmaz).
class _CoveringWatermarkLayer extends StatelessWidget {
  static const markSize = 148.0;
  static const stepX = 168.0;
  static const stepY = 132.0;

  final double width;
  final double height;
  final double opacity;

  const _CoveringWatermarkLayer({
    required this.width,
    required this.height,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    final size = math
        .min(markSize, math.min(width * 0.55, height * 0.7))
        .clamp(112.0, markSize);

    // Kısa gövdede tek merkezî marka yeterli.
    if (height < size * 1.35) {
      return Center(
        child: _LogoMark(size: size, opacity: opacity),
      );
    }

    final cols = math.max(1, (width / stepX).ceil());
    final rows = math.max(1, (height / stepY).ceil());
    final children = <Widget>[];

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final stagger = row.isOdd ? stepX * 0.45 : 0.0;
        final left = col * stepX + stagger - size * 0.15;
        final top = row * stepY - size * 0.1;
        if (left > width || top > height) continue;
        children.add(
          Positioned(
            left: left,
            top: top,
            width: size,
            height: size,
            child: _LogoMark(size: size, opacity: opacity),
          ),
        );
      }
    }

    return ClipRect(
      child: Stack(clipBehavior: Clip.hardEdge, children: children),
    );
  }
}

class _LogoMark extends StatelessWidget {
  final double size;
  final double opacity;

  const _LogoMark({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    final logoSide = size * 0.48;
    final line1Size = size * 0.09;
    final line2Size = size * 0.062;

    return Transform.rotate(
      angle: -math.pi / 4,
      child: Opacity(
        opacity: opacity,
        child: SizedBox(
          width: size,
          height: size,
          child: FittedBox(
            fit: BoxFit.contain,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  WatermarkWidget.logoAsset,
                  width: logoSide,
                  height: logoSide,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  color: AppTheme.champagneLight,
                  colorBlendMode: BlendMode.srcIn,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.track_changes_rounded,
                    size: logoSide * 0.72,
                    color: AppTheme.champagneLight,
                  ),
                ),
                SizedBox(height: size * 0.008),
                Text(
                  BrandConstants.brandLine1,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: line1Size,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    letterSpacing: 1.0,
                    color: AppTheme.champagneLight,
                  ),
                ),
                SizedBox(height: size * 0.003),
                Text(
                  BrandConstants.brandLine2,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'sans-serif',
                    fontSize: line2Size,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: 2.0,
                    color: AppTheme.champagneLight.withValues(alpha: 0.92),
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
