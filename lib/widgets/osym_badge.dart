import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum OsymBadgeVariant { standard, premium }

/// ÖSYM kaynaklı soru damgası — resmi logo + "SORDU !" etiketi.
class OsymBadge extends StatelessWidget {
  static const _assetPath = 'assets/images/osym_sordu_badge.png';

  /// Kaynak PNG: 331×203 px
  static const aspectRatio = 331 / 203;

  final double height;
  final OsymBadgeVariant variant;

  const OsymBadge({
    super.key,
    required this.height,
    this.variant = OsymBadgeVariant.standard,
  });

  @override
  Widget build(BuildContext context) {
    final image = SizedBox(
      height: height,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Image.asset(
          _assetPath,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
        ),
      ),
    );

    final badge = switch (variant) {
      OsymBadgeVariant.premium =>
        _PremiumBadgeFrame(height: height, child: image),
      OsymBadgeVariant.standard => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.32),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: image,
        ),
    };

    return Semantics(
      label: 'ÖSYM sordu',
      child: badge,
    );
  }
}

class _PremiumBadgeFrame extends StatefulWidget {
  final double height;
  final Widget child;

  const _PremiumBadgeFrame({
    required this.height,
    required this.child,
  });

  @override
  State<_PremiumBadgeFrame> createState() => _PremiumBadgeFrameState();
}

class _PremiumBadgeFrameState extends State<_PremiumBadgeFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(10);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value;
        final pulse = 0.55 + 0.45 * math.sin(t * math.pi * 2);
        final angle = t * math.pi * 2;

        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: AppTheme.neonEdge.withValues(alpha: 0.18 + 0.22 * pulse),
                blurRadius: 10 + 10 * pulse,
                spreadRadius: 0.4 * pulse,
              ),
              BoxShadow(
                color: AppTheme.champagne.withValues(alpha: 0.12 + 0.16 * pulse),
                blurRadius: 16 + 8 * pulse,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: CustomPaint(
            painter: _ShimmerBorderPainter(
              progress: t,
              borderRadius: 10,
              strokeWidth: 1.7,
            ),
            child: Padding(
              padding: const EdgeInsets.all(1.7),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.4),
                  gradient: LinearGradient(
                    begin: Alignment(-math.cos(angle), -math.sin(angle)),
                    end: Alignment(math.cos(angle), math.sin(angle)),
                    colors: [
                      Colors.white,
                      AppTheme.champagneLight.withValues(alpha: 0.22 * pulse),
                      Colors.white,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.height * 0.06,
                    vertical: widget.height * 0.05,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _ShimmerBorderPainter extends CustomPainter {
  final double progress;
  final double borderRadius;
  final double strokeWidth;

  const _ShimmerBorderPainter({
    required this.progress,
    required this.borderRadius,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(borderRadius),
    );

    final sweep = SweepGradient(
      transform: GradientRotation(progress * math.pi * 2),
      colors: const [
        AppTheme.champagne,
        AppTheme.champagneLight,
        AppTheme.neonEdge,
        AppTheme.champagneLight,
        AppTheme.champagne,
        Colors.transparent,
        AppTheme.champagne,
      ],
      stops: const [0.0, 0.12, 0.22, 0.32, 0.42, 0.72, 1.0],
    );

    final paint = Paint()
      ..shader = sweep.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _ShimmerBorderPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// Soru kökü sarmalayıcı (ÖSYM rozeti quiz üst çizgisinde gösterilir).
class QuestionStemPanel extends StatelessWidget {
  final Widget child;

  const QuestionStemPanel({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => child;
}
