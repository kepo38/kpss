import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pro pill üzerine yaslanan pati — kompakt, üst katmanda.
class PremiumMascotPawOnPill extends StatelessWidget {
  const PremiumMascotPawOnPill({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      size: Size(38, 30),
      painter: _PawOnPillPainter(),
    );
  }
}

class _PawOnPillPainter extends CustomPainter {
  const _PawOnPillPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(-14, -8);
    canvas.scale(0.72);

    const s = 1.0;
    const h = 50.0;
    final shoulder = Offset(h * 0.48, h * 0.54);
    final elbow = Offset(h * 0.68, h * 0.48);
    final pawCenter = Offset(h * 0.88, h * 0.46);

    final arm = Path()
      ..moveTo(shoulder.dx, shoulder.dy)
      ..quadraticBezierTo(
        shoulder.dx + 8 * s,
        shoulder.dy - 6 * s,
        elbow.dx,
        elbow.dy,
      )
      ..quadraticBezierTo(
        elbow.dx + 6 * s,
        elbow.dy + 2 * s,
        pawCenter.dx - 4 * s,
        pawCenter.dy,
      );
    canvas.drawPath(
      arm,
      Paint()
        ..color = const Color(0xFFFFEDB0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5 * s
        ..strokeCap = StrokeCap.round,
    );

    final pawRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: pawCenter,
        width: 13 * s,
        height: 10 * s,
      ),
      Radius.circular(5 * s),
    );
    canvas.drawRRect(
      pawRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF8EE),
            AppTheme.champagneLight,
          ],
        ).createShader(pawRect.outerRect),
    );
    canvas.drawRRect(
      pawRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9 * s
        ..color = const Color(0xFFD4AF6A),
    );
    for (final dx in [-3.0, 0.0, 3.0]) {
      canvas.drawCircle(
        Offset(pawCenter.dx + dx * s, pawCenter.dy - 1.5 * s),
        1.2 * s,
        Paint()..color = AppTheme.champagne.withValues(alpha: 0.6),
      );
    }
    canvas.restore();

    canvas.drawCircle(
      Offset(size.width - 4, size.height * 0.42),
      2.2,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
