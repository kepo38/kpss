import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/brand_constants.dart';
import '../theme/app_theme.dart';

/// Soru kökünün arkasında 45° eğik marka filigranı (şıkların üstünde değil).
class WatermarkWidget extends StatelessWidget {
  static const logoAsset = BrandConstants.watermarkAsset;

  final Widget child;
  final double opacity;

  const WatermarkWidget({
    super.key,
    required this.child,
    this.opacity = 0.52,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        return Stack(
          clipBehavior: Clip.hardEdge,
          alignment: Alignment.topCenter,
          children: [
            // 1) Filigran altta
            Positioned.fill(
              child: IgnorePointer(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final height = box.maxHeight;
                    if (!height.isFinite || height <= 0) {
                      return const SizedBox.shrink();
                    }
                    return _AdaptiveWatermarkLayer(
                      width: width,
                      height: height,
                      opacity: opacity,
                    );
                  },
                ),
              ),
            ),
            // 2) Soru metni üstte
            child,
          ],
        );
      },
    );
  }
}

class _AdaptiveWatermarkLayer extends StatelessWidget {
  final double width;
  final double height;
  final double opacity;

  const _AdaptiveWatermarkLayer({
    required this.width,
    required this.height,
    required this.opacity,
  });

  static const sizeScale = 1.5;

  static double logoSizeFor({
    required double width,
    required double height,
  }) {
    final widthBased = width * 0.72 * sizeScale;
    final heightBased = height * 0.82 * sizeScale;
    return math.min(widthBased, heightBased).clamp(156.0, 390.0);
  }

  static int logoCountFor({required double width, required double height}) {
    if (height < width * 1.1) return 1;
    if (height < width * 2.0) return 2;
    return 3;
  }

  static double logoCenterY({
    required int index,
    required int count,
    required double height,
  }) {
    if (count <= 1) return height * 0.48;
    final step = height / (count + 1);
    return step * (index + 1);
  }

  @override
  Widget build(BuildContext context) {
    if (width <= 0 || height <= 0) return const SizedBox.shrink();

    final logoSize = logoSizeFor(width: width, height: height);
    final count = logoCountFor(width: width, height: height);

    return ClipRect(
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          for (var i = 0; i < count; i++)
            Positioned(
              left: 0,
              right: 0,
              top: logoCenterY(index: i, count: count, height: height) -
                  logoSize / 2,
              height: logoSize,
              child: Center(
                child: _LogoMark(size: logoSize, opacity: opacity),
              ),
            ),
        ],
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
    final logoSide = size * 0.58;
    final line1Size = size * 0.11;
    final line2Size = size * 0.075;

    return Transform.rotate(
      angle: -math.pi / 4,
      child: Opacity(
        opacity: opacity,
        child: Column(
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
            SizedBox(height: size * 0.008),
            Text(
              BrandConstants.brandLine1,
              textAlign: TextAlign.center,
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
    );
  }
}
