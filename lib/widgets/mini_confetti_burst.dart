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
  OverlayEntry? _overlayEntry;

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
      duration: const Duration(milliseconds: 1800),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _removeOverlay();
          if (mounted) setState(() {});
        }
      });
    if (widget.trigger) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fire());
    }
  }

  @override
  void didUpdateWidget(covariant MiniConfettiBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _fire();
    } else if (!widget.trigger && oldWidget.trigger) {
      _ctrl.reset();
      _removeOverlay();
    }
  }

  void _fire() {
    _particles = _spawnParticles();
    _removeOverlay();
    _ctrl.forward(from: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showOverlay());
  }

  void _showOverlay() {
    if (!mounted || !_ctrl.isAnimating) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final origin = box.localToGlobal(Offset(box.size.width * 0.72, 8));

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return IgnorePointer(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              final progress = Curves.easeOutCubic.transform(_ctrl.value);
              return CustomPaint(
                painter: _OverlayConfettiPainter(
                  progress: progress,
                  particles: _particles,
                  origin: origin,
                ),
                size: MediaQuery.sizeOf(context),
              );
            },
          ),
        );
      },
    );
    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  List<_ConfettiParticle> _spawnParticles() {
    return List.generate(36, (_) {
      final shape = _random.nextInt(3);
      return _ConfettiParticle(
        originX: (_random.nextDouble() - 0.5) * 0.55,
        originY: 0,
        velocityX: (_random.nextDouble() - 0.5) * 220,
        velocityY: -(80 + _random.nextDouble() * 160),
        gravity: 320 + _random.nextDouble() * 180,
        rotation: _random.nextDouble() * math.pi * 2,
        spin: (_random.nextDouble() - 0.5) * 8,
        size: 4 + _random.nextDouble() * 6,
        color: _palette[_random.nextInt(_palette.length)],
        isCircle: shape == 0,
        isStrip: shape == 1,
      );
    });
  }

  @override
  void dispose() {
    _removeOverlay();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
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

class _OverlayConfettiPainter extends CustomPainter {
  final double progress;
  final List<_ConfettiParticle> particles;
  final Offset origin;

  _OverlayConfettiPainter({
    required this.progress,
    required this.particles,
    required this.origin,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress > 1) return;
    final t = progress;
    final fade = (1 - progress).clamp(0.0, 1.0);

    for (final p in particles) {
      final x = origin.dx + p.originX * 120 + p.velocityX * t;
      final y = origin.dy + p.originY + p.velocityY * t + p.gravity * t * t;
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
  bool shouldRepaint(covariant _OverlayConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.origin != origin;
}
