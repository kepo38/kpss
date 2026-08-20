import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/brand_constants.dart';
import '../theme/app_theme.dart';

/// Soru kökünde tek 45° filigran (şıklar hariç).
///
/// [fitToChild] açıkken işaret çocuk kutusuna göre küçülür.
/// [overlay] açıkken işaret çocuğun üstüne biner (harita/görsel).
class WatermarkWidget extends StatelessWidget {
  static const logoAsset = BrandConstants.watermarkAsset;

  final Widget child;
  final double opacity;
  final bool fitToChild;
  final bool overlay;

  const WatermarkWidget({
    super.key,
    required this.child,
    this.opacity = 0.26,
    this.fitToChild = false,
    this.overlay = false,
  });

  @override
  Widget build(BuildContext context) {
    final mark = Positioned.fill(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, box) {
            if (!box.hasBoundedWidth ||
                !box.hasBoundedHeight ||
                box.maxWidth <= 0 ||
                box.maxHeight <= 0) {
              return const SizedBox.shrink();
            }
            final minSize = fitToChild ? 36.0 : 96.0;
            final maxSize = fitToChild ? 120.0 : 148.0;
            final size = math
                .min(
                  maxSize,
                  math.min(
                    box.maxWidth * (fitToChild ? 0.72 : 0.48),
                    box.maxHeight * (fitToChild ? 0.92 : 0.62),
                  ),
                )
                .clamp(minSize, maxSize);
            return Align(
              alignment: overlay
                  ? Alignment.center
                  : (fitToChild
                      ? const Alignment(-0.42, 0.0)
                      : const Alignment(-0.78, -0.22)),
              child: _LogoMark(size: size, opacity: opacity),
            );
          },
        ),
      ),
    );
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: overlay ? [child, mark] : [mark, child],
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
