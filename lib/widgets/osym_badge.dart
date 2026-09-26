import 'dart:async';
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
  /// Dokununca 2 sn görünen sınav adı (ör. 2025 KPSS).
  final String? examLabel;

  const OsymBadge({
    super.key,
    required this.height,
    this.variant = OsymBadgeVariant.standard,
    this.examLabel,
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

    final label = (examLabel ?? '').trim();
    return Semantics(
      label: label.isEmpty ? 'ÖSYM sordu' : 'ÖSYM sordu, $label',
      button: label.isNotEmpty,
      child: label.isEmpty ? badge : _OsymExamHint(label: label, child: badge),
    );
  }
}

class _OsymExamHint extends StatefulWidget {
  final String label;
  final Widget child;

  const _OsymExamHint({required this.label, required this.child});

  @override
  State<_OsymExamHint> createState() => _OsymExamHintState();
}

class _OsymExamHintState extends State<_OsymExamHint> {
  OverlayEntry? _entry;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  void _hide() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }

  void _show() {
    _hide();
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.maybeOf(context);
    if (box == null || !box.hasSize || overlay == null) return;
    final origin = box.localToGlobal(Offset.zero);
    final size = box.size;
    _entry = OverlayEntry(
      builder: (context) {
        final screen = MediaQuery.sizeOf(context).width;
        final maxW = math.min(260.0, screen - 24);
        var left = origin.dx + size.width / 2 - maxW / 2;
        left = left.clamp(12.0, screen - maxW - 12);
        return Positioned(
          left: left,
          top: origin.dy + size.height + 6,
          width: maxW,
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xF01A140C),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.champagne.withValues(alpha: 0.55),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.champagneLight,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      height: 1.25,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_entry!);
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) _hide();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _show,
      behavior: HitTestBehavior.opaque,
      child: widget.child,
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
            painter: PremiumShimmerBorderPainter(
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

/// Dönen şampanya/neon kenar — ÖSYM premium çerçeve ile aynı dil.
class PremiumShimmerBorderPainter extends CustomPainter {
  final double progress;
  final double borderRadius;
  final double strokeWidth;

  const PremiumShimmerBorderPainter({
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
  bool shouldRepaint(covariant PremiumShimmerBorderPainter oldDelegate) =>
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
