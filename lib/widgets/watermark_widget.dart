import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/brand_constants.dart';
import '../theme/app_theme.dart';

/// Soru kökünün arkasında tek, 45° eğik marka filigranı.
class WatermarkWidget extends StatelessWidget {
  static const logoAsset = BrandConstants.watermarkAsset;

  final Widget child;
  final double opacity;

  const WatermarkWidget({
    super.key,
    required this.child,
    this.opacity = 0.36,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.hardEdge,
      alignment: Alignment.topCenter,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: LayoutBuilder(
              builder: (context, box) {
                if (!box.maxWidth.isFinite ||
                    !box.maxHeight.isFinite ||
                    box.maxWidth <= 0 ||
                    box.maxHeight <= 0) {
                  return const SizedBox.shrink();
                }
                return _SingleWatermarkLayer(
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

class _SingleWatermarkLayer extends StatelessWidget {
  /// Uzun sorularda filigranı yalnızca üst banta koy — gövde boyunca çoğalmaz.
  static const bandHeight = 280.0;
  static const markSize = 200.0;

  final double width;
  final double height;
  final double opacity;

  const _SingleWatermarkLayer({
    required this.width,
    required this.height,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    final band = math.min(height, bandHeight);
    final size = math.min(markSize, math.min(width * 0.62, band * 0.72));

    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: width,
        height: band,
        child: Center(
          child: ClipRect(
            child: SizedBox(
              width: size,
              height: size,
              child: FittedBox(
                fit: BoxFit.contain,
                child: _LogoMark(size: size, opacity: opacity),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  final double size;
  final double opacity;

  const _LogoMark({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    final logoSide = size * 0.52;
    final line1Size = size * 0.1;
    final line2Size = size * 0.068;

    return Transform.rotate(
      angle: -math.pi / 4,
      child: Opacity(
        opacity: opacity,
        child: SizedBox(
          width: size,
          height: size,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                WatermarkWidget.logoAsset,
                width: logoSide,
                height: logoSide,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                color: AppTheme.champagneLight,
                colorBlendMode: BlendMode.srcIn,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.track_changes_rounded,
                  size: logoSide * 0.72,
                  color: AppTheme.champagneLight,
                ),
              ),
              SizedBox(height: size * 0.01),
              Text(
                BrandConstants.brandLine1,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: line1Size,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: 1.2,
                  color: AppTheme.champagneLight,
                ),
              ),
              SizedBox(height: size * 0.004),
              Text(
                BrandConstants.brandLine2,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'sans-serif',
                  fontSize: line2Size,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 2.4,
                  color: AppTheme.champagneLight.withValues(alpha: 0.92),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
