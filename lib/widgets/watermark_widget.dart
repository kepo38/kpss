import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/brand_constants.dart';
import '../theme/app_theme.dart';

/// Soru kökünün arkasında tek 45° filigran (şıklar hariç).
///
/// Tam ortalanmaz: metin sola hizalı olduğu için kısa satırların sağındaki
/// boşluğa düşmesin diye marka metin tarafına (sola) yaslanır.
class WatermarkWidget extends StatelessWidget {
  static const logoAsset = BrandConstants.watermarkAsset;

  final Widget child;
  final double opacity;

  const WatermarkWidget({
    super.key,
    required this.child,
    this.opacity = 0.26,
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
                final size = math
                    .min(
                      148.0,
                      math.min(box.maxWidth * 0.48, box.maxHeight * 0.62),
                    )
                    .clamp(96.0, 148.0);
                // LTR soru metni: sola yakın, dikeyde hafif yukarı — boş sağ
                // alan ve alt boşluktan uzak.
                return Align(
                  alignment: const Alignment(-0.78, -0.22),
                  child: _LogoMark(size: size, opacity: opacity),
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
