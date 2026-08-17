import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// AppBar kalbi: dolunca zıplar, parlar; eklenince kısa toast gösterir.
class FavoriteHeartButton extends StatefulWidget {
  final bool isFavorite;
  final Future<void> Function() onToggle;

  const FavoriteHeartButton({
    super.key,
    required this.isFavorite,
    required this.onToggle,
  });

  @override
  State<FavoriteHeartButton> createState() => _FavoriteHeartButtonState();
}

class _FavoriteHeartButtonState extends State<FavoriteHeartButton>
    with TickerProviderStateMixin {
  late final AnimationController _burstCtrl;
  late final AnimationController _toastCtrl;
  late final Animation<double> _scale;
  late final Animation<double> _glow;
  late final Animation<double> _sparkle;
  late final Animation<double> _toastOpacity;
  late final Animation<Offset> _toastSlide;

  OverlayEntry? _toastEntry;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _burstCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _toastCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 1.35).chain(
          CurveTween(curve: Curves.easeOutBack),
        ),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.35, end: 1).chain(
          CurveTween(curve: Curves.easeOutCubic),
        ),
        weight: 65,
      ),
    ]).animate(_burstCtrl);

    _glow = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0, end: 1), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 1, end: 0), weight: 70),
    ]).animate(CurvedAnimation(parent: _burstCtrl, curve: Curves.easeOut));

    _sparkle = CurvedAnimation(
      parent: _burstCtrl,
      curve: const Interval(0.05, 0.85, curve: Curves.easeOut),
    );

    _toastOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 12),
      TweenSequenceItem(tween: ConstantTween(1), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 33),
    ]).animate(_toastCtrl);

    _toastSlide = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween(begin: const Offset(0, -0.35), end: Offset.zero),
        weight: 18,
      ),
      TweenSequenceItem(tween: ConstantTween(Offset.zero), weight: 52),
      TweenSequenceItem(
        tween: Tween(begin: Offset.zero, end: const Offset(0, -0.2)),
        weight: 30,
      ),
    ]).animate(CurvedAnimation(parent: _toastCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _removeToast();
    _burstCtrl.dispose();
    _toastCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_busy) return;
    _busy = true;
    final wasFavorite = widget.isFavorite;
    try {
      await widget.onToggle();
      if (!mounted) return;
      if (!wasFavorite) {
        _burstCtrl.forward(from: 0);
        _showAddedToast();
      }
    } finally {
      _busy = false;
    }
  }

  void _removeToast() {
    _toastEntry?.remove();
    _toastEntry = null;
  }

  void _showAddedToast() {
    _removeToast();
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    _toastEntry = OverlayEntry(
      builder: (context) {
        final top = MediaQuery.paddingOf(context).top + kToolbarHeight + 10;
        return Positioned(
          top: top,
          left: 24,
          right: 24,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _toastCtrl,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _toastOpacity,
                  child: SlideTransition(
                    position: _toastSlide,
                    child: child,
                  ),
                );
              },
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.inkSoft.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppTheme.champagne.withValues(alpha: 0.45),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.champagne.withValues(alpha: 0.22),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite_rounded,
                          size: 15,
                          color: AppTheme.champagne,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Favorilere eklendi',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_toastEntry!);
    _toastCtrl.forward(from: 0).whenComplete(() {
      if (mounted) _removeToast();
    });
  }

  @override
  Widget build(BuildContext context) {
    final filled = widget.isFavorite;
    return IconButton(
      tooltip: filled ? 'Favorilerden çıkar' : 'Favorilere ekle',
      onPressed: _handleTap,
      icon: AnimatedBuilder(
        animation: Listenable.merge([_burstCtrl]),
        builder: (context, _) {
          return SizedBox(
            width: 28,
            height: 28,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (_glow.value > 0.02)
                  Container(
                    width: 26 + 10 * _glow.value,
                    height: 26 + 10 * _glow.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.champagne.withValues(
                            alpha: 0.55 * _glow.value,
                          ),
                          blurRadius: 14 * _glow.value,
                          spreadRadius: 1.5 * _glow.value,
                        ),
                      ],
                    ),
                  ),
                if (_sparkle.value > 0)
                  CustomPaint(
                    size: const Size(34, 34),
                    painter: _HeartSparklePainter(
                      progress: _sparkle.value,
                      color: AppTheme.champagneLight,
                    ),
                  ),
                Transform.scale(
                  scale: filled ? _scale.value : 1,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, anim) {
                      return ScaleTransition(scale: anim, child: child);
                    },
                    child: Icon(
                      filled
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      key: ValueKey(filled),
                      color: filled ? AppTheme.champagne : Colors.white70,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeartSparklePainter extends CustomPainter {
  final double progress;
  final Color color;

  _HeartSparklePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;
    const rays = 6;
    for (var i = 0; i < rays; i++) {
      final angle = (i / rays) * math.pi * 2 - math.pi / 2;
      final travel = 6 + 10 * progress;
      final opacity = (1 - progress).clamp(0.0, 1.0);
      final sparkleSize = 1.6 + 1.4 * (1 - progress);
      final pos = Offset(
        center.dx + math.cos(angle) * travel,
        center.dy + math.sin(angle) * travel,
      );
      paint.color = color.withValues(alpha: 0.85 * opacity);
      canvas.drawCircle(pos, sparkleSize, paint);
      // Tiny cross sparkle
      paint.strokeWidth = 1.2;
      paint.style = PaintingStyle.stroke;
      canvas.drawLine(
        pos.translate(-sparkleSize * 1.4, 0),
        pos.translate(sparkleSize * 1.4, 0),
        paint,
      );
      canvas.drawLine(
        pos.translate(0, -sparkleSize * 1.4),
        pos.translate(0, sparkleSize * 1.4),
        paint,
      );
      paint.style = PaintingStyle.fill;
    }
  }

  @override
  bool shouldRepaint(covariant _HeartSparklePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
