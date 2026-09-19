import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Resmi Google "G" markası (4 renk) — Icons.g_mobiledata yerine.
class GoogleGMark extends StatelessWidget {
  final double size;

  const GoogleGMark({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.12),
          child: CustomPaint(painter: _GoogleGPainter()),
        ),
      ),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(s / 2, s / 2);
    final stroke = s * 0.22;
    final r = (s - stroke) / 2;
    final rect = Rect.fromCircle(center: c, radius: r);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Clockwise from top: blue → green → yellow → red (classic G ring).
    void arc(Color color, double startDeg, double sweepDeg) {
      paint.color = color;
      canvas.drawArc(
        rect,
        startDeg * math.pi / 180,
        sweepDeg * math.pi / 180,
        false,
        paint,
      );
    }

    arc(_blue, -40, 100);
    arc(_green, 60, 85);
    arc(_yellow, 145, 70);
    arc(_red, 215, 105);

    // Blue horizontal arm of the G.
    final barH = stroke;
    final bar = RRect.fromRectAndRadius(
      Rect.fromLTWH(c.dx - stroke * 0.1, c.dy - barH / 2, r + stroke * 0.35, barH),
      Radius.circular(barH / 2),
    );
    canvas.drawRRect(bar, Paint()..color = _blue);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
