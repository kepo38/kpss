import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Kısa süreli konfeti patlaması — sıralama açılışı vb. için.
class MiniConfettiBurst extends StatefulWidget {
  final bool trigger;
  final Widget child;

  const MiniConfettiBurst({
    super.key,
    required this.trigger,
    required this.child,
  });

  @override
  State<MiniConfettiBurst> createState() => _MiniConfettiBurstState();
}

class _MiniConfettiBurstState extends State<MiniConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late List<_ConfettiParticle> _particles;
  final _random = math.Random();
  bool _fired = false;

  static const _palette = [
    Color(0xFFFFEDB0),
    Color(0xFFE8C878),
    AppTheme.champagne,
    AppTheme.champagneLight,
    Color(0xFFFFF8E7),
    Color(0xFF34D399),
    Color(0xFF60A5FA),
  ];

  @override
  void initState() {
    super.initState();
    _particles = _spawnParticles();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {});
        }
      });
    if (widget.trigger) _fire();
  }

  @override
  void didUpdateWidget(covariant MiniConfettiBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _fire();
    }
  }

  void _fire() {
    if (_fired) return;
    _fired = true;
    _particles = _spawnParticles();
    _ctrl.forward(from: 0);
  }

  List<_ConfettiParticle> _spawnParticles() {
    return List.generate(28, (_) {
      final shape = _random.nextInt(3);
      return _ConfettiParticle(
        originX: 0.38 + _random.nextDouble() * 0.24,
        originY: 0.55,
        velocityX: (_random.nextDouble() - 0.5) * 1.35,
        velocityY: 0.55 + _random.nextDouble() * 0.95,
        gravity: 0.85 + _random.nextDouble() * 0.35,
        rotation: _random.nextDouble() * math.pi * 2,
        spin: (_random.nextDouble() - 0.5) * 7,
        size: 4 + _random.nextDouble() * 5,
        color: _palette[_random.nextInt(_palette.length)],
        isCircle: shape == 0,
        isStrip: shape == 1,
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showOverlay = _ctrl.isAnimating || _ctrl.value > 0;
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            widget.child,
            if (showOverlay)
              Positioned(
                left: -8,
                right: -8,
                top: -36,
                height: 88,
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _ctrl,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _ConfettiPainter(
                          progress: Curves.easeOutCubic.transform(_ctrl.value),
                          particles: _particles,
                        ),
                        size: Size(constraints.maxWidth + 16, 88),
                      );
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ConfettiParticle {
  final double originX;
  final double originY;
  final double velocityX;
  final double velocityY;
  final double gravity;
  final double rotation;
  final double spin;
  final double size;
  final Color color;
  final bool isCircle;
  final bool isStrip;

  const _ConfettiParticle({
    required this.originX,
    required this.originY,
    required this.velocityX,
    required this.velocityY,
    required this.gravity,
    required this.rotation,
    required this.spin,
    required this.size,
    required this.color,
    required this.isCircle,
    required this.isStrip,
  });
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<_ConfettiParticle> particles;

  _ConfettiPainter({
    required this.progress,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final fade = (1 - progress).clamp(0.0, 1.0);

    for (final p in particles) {
      final t = progress;
      final x = (p.originX + p.velocityX * t) * size.width;
      final y = (p.originY - p.velocityY * t + p.gravity * t * t) * size.height;
      final paint = Paint()..color = p.color.withValues(alpha: fade * 0.95);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + p.spin * t);

      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size * 0.45, paint);
      } else if (p.isStrip) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size * 1.6,
              height: p.size * 0.55,
            ),
            const Radius.circular(1.5),
          ),
          paint,
        );
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
