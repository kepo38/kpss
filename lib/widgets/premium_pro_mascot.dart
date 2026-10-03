import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pro Üyelik pill'inin soluna yaslanan sevimli premium maskot.
enum PremiumMascotLayer { full, bodyOnly, pawOnly }

class PremiumProMascot extends StatefulWidget {
  final double height;
  final PremiumMascotLayer layer;

  const PremiumProMascot({
    super.key,
    this.height = 50,
    this.layer = PremiumMascotLayer.full,
  });

  @override
  State<PremiumProMascot> createState() => _PremiumProMascotState();
}

class _PremiumProMascotState extends State<PremiumProMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut).value;
        final bob = math.sin(t * math.pi) * 1.6;
        final lean = 0.06 + math.sin(t * math.pi) * 0.018;
        final blink = (t > 0.92 || t < 0.04) ? 0.12 : 1.0;
        return Transform.translate(
          offset: Offset(0, bob),
          child: Transform.rotate(
            angle: lean,
            alignment: Alignment.bottomRight,
            child: CustomPaint(
              size: Size(widget.height * 1.22, widget.height),
              painter: _CuteLeanMascotPainter(
                height: widget.height,
                blink: blink,
                layer: widget.layer,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CuteLeanMascotPainter extends CustomPainter {
  final double height;
  final double blink;
  final PremiumMascotLayer layer;

  _CuteLeanMascotPainter({
    required this.height,
    required this.blink,
    this.layer = PremiumMascotLayer.full,
  });

  bool get _shouldDrawBody =>
      layer == PremiumMascotLayer.full || layer == PremiumMascotLayer.bodyOnly;
  bool get _shouldDrawPaw =>
      layer == PremiumMascotLayer.full || layer == PremiumMascotLayer.pawOnly;

  @override
  void paint(Canvas canvas, Size size) {
    final h = height;
    final s = h / 50;

    if (_shouldDrawPaw && !_shouldDrawBody) {
      _paintPawArm(canvas, h, s);
      return;
    }

    if (!_shouldDrawBody) return;

    // Gölge — butona yaslanmış his
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(h * 0.38, h * 0.96),
        width: 22 * s,
        height: 5 * s,
      ),
      Paint()..color = AppTheme.ink.withValues(alpha: 0.1),
    );

    // Kuyruk / arka yıldız ucu (sol)
    final tail = Path()
      ..moveTo(8 * s, h * 0.58)
      ..quadraticBezierTo(2 * s, h * 0.5, 4 * s, h * 0.42)
      ..quadraticBezierTo(10 * s, h * 0.48, 12 * s, h * 0.56);
    canvas.drawPath(
      tail,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFEDB0), Color(0xFFE8C878)],
        ).createShader(Rect.fromLTWH(0, h * 0.4, 14 * s, h * 0.2)),
    );

    // Gövde — yumuşak altın yıldız-yumurta
    final bodyCenter = Offset(h * 0.36, h * 0.56);
    final body = Path()
      ..addOval(
        Rect.fromCenter(
          center: bodyCenter,
          width: 26 * s,
          height: 24 * s,
        ),
      );
    canvas.drawPath(
      body,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          colors: const [
            Color(0xFFFFF8E7),
            Color(0xFFFFEDB0),
            Color(0xFFE8C878),
            Color(0xFFD4AF6A),
          ],
          stops: const [0, 0.35, 0.72, 1],
        ).createShader(
          Rect.fromCenter(
            center: bodyCenter,
            width: 28 * s,
            height: 26 * s,
          ),
        ),
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9 * s
        ..color = Colors.white.withValues(alpha: 0.55),
    );

    // Minik lacivert yaka — marka dokunuşu
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(bodyCenter.dx, bodyCenter.dy + 8 * s),
        width: 18 * s,
        height: 10 * s,
      ),
      math.pi * 0.05,
      math.pi * 0.9,
      false,
      Paint()
        ..color = AppTheme.inkSoft
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2 * s
        ..strokeCap = StrokeCap.round,
    );

    // Kafa — büyük, sevimli
    final headCenter = Offset(h * 0.36, h * 0.34);
    canvas.drawCircle(
      headCenter,
      15.5 * s,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.5),
          colors: const [
            Color(0xFFFFFDF8),
            Color(0xFFFFEDB0),
            Color(0xFFF0D898),
          ],
        ).createShader(
          Rect.fromCircle(center: headCenter, radius: 16 * s),
        ),
    );
    canvas.drawCircle(
      headCenter,
      15.5 * s,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 * s
        ..color = Colors.white.withValues(alpha: 0.65),
    );

    // Taç — hafif eğik
    canvas.save();
    canvas.translate(headCenter.dx, headCenter.dy - 14 * s);
    canvas.rotate(-0.12);
    _drawMiniCrown(canvas, Offset.zero, s);
    canvas.restore();

    // Yanak
    for (final dx in [-7.5, 7.5]) {
      canvas.drawCircle(
        Offset(headCenter.dx + dx * s, headCenter.dy + 4 * s),
        3.2 * s,
        Paint()..color = const Color(0xFFFF9EAA).withValues(alpha: 0.38),
      );
    }

    // Gözler — büyük, sevimli
    _drawCuteEye(
      canvas,
      Offset(headCenter.dx - 5.5 * s, headCenter.dy - 0.5 * s),
      s,
      blink,
      lookingRight: true,
    );
    _drawCuteEye(
      canvas,
      Offset(headCenter.dx + 5.5 * s, headCenter.dy - 0.5 * s),
      s,
      blink,
      lookingRight: true,
      wink: false,
    );

    // Gülümseme
    final smile = Path()
      ..moveTo(headCenter.dx - 5 * s, headCenter.dy + 5.5 * s)
      ..quadraticBezierTo(
        headCenter.dx,
        headCenter.dy + 9.5 * s,
        headCenter.dx + 5.5 * s,
        headCenter.dy + 5 * s,
      );
    canvas.drawPath(
      smile,
      Paint()
        ..color = AppTheme.ink.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.35 * s
        ..strokeCap = StrokeCap.round,
    );

    // Kol + el — gövdeden çıkan, pill'e yaslanmış (sağa uzanan)
    if (_shouldDrawPaw) {
      _paintPawArm(canvas, h, s, bodyCenter: bodyCenter);
    }

    // Parıltı
    if (_shouldDrawBody) {
      _drawSparkle(canvas, Offset(h * 0.14, h * 0.16), 2.8 * s);
    }
  }

  void _paintPawArm(Canvas canvas, double h, double s, {Offset? bodyCenter}) {
    final body = bodyCenter ?? Offset(h * 0.36, h * 0.56);
    final shoulder = Offset(body.dx + 10 * s, body.dy - 2 * s);
    final elbow = Offset(h * 0.72, h * 0.46);
    final pawCenter = Offset(h * 0.94, h * 0.44);

    final armFill = Paint()
      ..color = const Color(0xFFFFEDB0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.4 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final arm = Path()
      ..moveTo(shoulder.dx, shoulder.dy)
      ..quadraticBezierTo(
        shoulder.dx + 10 * s,
        shoulder.dy - 8 * s,
        elbow.dx,
        elbow.dy,
      )
      ..quadraticBezierTo(
        elbow.dx + 8 * s,
        elbow.dy + 3 * s,
        pawCenter.dx - 5 * s,
        pawCenter.dy + 1 * s,
      );
    canvas.drawPath(arm, armFill);
    canvas.drawPath(
      arm,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1 * s
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: pawCenter,
          width: 13 * s,
          height: 10 * s,
        ),
        Radius.circular(5 * s),
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFF8EE),
            AppTheme.champagneLight.withValues(alpha: 0.95),
          ],
        ).createShader(
          Rect.fromCenter(
            center: pawCenter,
            width: 13 * s,
            height: 10 * s,
          ),
        ),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: pawCenter,
          width: 13 * s,
          height: 10 * s,
        ),
        Radius.circular(5 * s),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8 * s
        ..color = const Color(0xFFD4AF6A).withValues(alpha: 0.85),
    );
    for (final dx in [-3.0, 0.0, 3.0]) {
      canvas.drawCircle(
        Offset(pawCenter.dx + dx * s, pawCenter.dy - 1.5 * s),
        1.1 * s,
        Paint()..color = AppTheme.champagne.withValues(alpha: 0.55),
      );
    }
  }

  void _drawMiniCrown(Canvas canvas, Offset c, double s) {
    final path = Path()
      ..moveTo(c.dx - 9 * s, c.dy + 2 * s)
      ..lineTo(c.dx - 7 * s, c.dy - 4 * s)
      ..lineTo(c.dx - 3.5 * s, c.dy)
      ..lineTo(c.dx, c.dy - 5.5 * s)
      ..lineTo(c.dx + 3.5 * s, c.dy)
      ..lineTo(c.dx + 7 * s, c.dy - 4 * s)
      ..lineTo(c.dx + 9 * s, c.dy + 2 * s)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFEDB0), AppTheme.champagne, Color(0xFFC9A86C)],
        ).createShader(Rect.fromCenter(
          center: c,
          width: 20 * s,
          height: 10 * s,
        )),
    );
    canvas.drawCircle(
      Offset(c.dx, c.dy - 2.5 * s),
      1.4 * s,
      Paint()..color = Colors.white,
    );
  }

  void _drawCuteEye(
    Canvas canvas,
    Offset center,
    double s,
    double blinkOpen, {
    bool lookingRight = false,
    bool wink = false,
  }) {
    final openH = wink ? 1.2 * s : 5.8 * s * blinkOpen;
    if (wink) {
      canvas.drawArc(
        Rect.fromCenter(center: center, width: 5 * s, height: 4 * s),
        math.pi * 0.1,
        math.pi * 0.8,
        false,
        Paint()
          ..color = AppTheme.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4 * s
          ..strokeCap = StrokeCap.round,
      );
      return;
    }
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 6.2 * s, height: openH),
      Paint()..color = Colors.white,
    );
    if (blinkOpen > 0.35) {
      final pupilShift = lookingRight ? 1.1 * s : 0;
      canvas.drawCircle(
        Offset(center.dx + pupilShift, center.dy + 0.6 * s),
        2.2 * s,
        Paint()..color = AppTheme.ink,
      );
      canvas.drawCircle(
        Offset(center.dx + pupilShift + 1.2 * s, center.dy - 0.8 * s),
        0.9 * s,
        Paint()..color = Colors.white,
      );
    }
  }

  void _drawSparkle(Canvas canvas, Offset c, double r) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), p);
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), p);
  }

  @override
  bool shouldRepaint(covariant _CuteLeanMascotPainter oldDelegate) =>
      oldDelegate.height != height ||
      oldDelegate.blink != blink ||
      oldDelegate.layer != layer;
}
