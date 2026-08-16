import 'package:flutter/material.dart';

import '../services/social_links_service.dart';

/// Instagram uygulama ikonu — resmi 2016 logo (radyal gradyan + kamera).
class InstagramLinkButton extends StatelessWidget {
  final double size;

  const InstagramLinkButton({
    super.key,
    this.size = 34,
  });

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.223;

    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: SocialLinksService.openInstagramProfile,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          splashColor: Colors.white24,
          highlightColor: Colors.white10,
          child: CustomPaint(
            size: Size.square(size),
            painter: const _InstagramLogoPainter(),
          ),
        ),
      ),
    );
  }
}

/// Instagram app icon (2016–): sarı → turuncu → pembe → mor → mavi.
class _InstagramLogoPainter extends CustomPainter {
  const _InstagramLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final iconRect = Offset.zero & size;
    final icon = RRect.fromRectAndRadius(
      iconRect,
      Radius.circular(w * 0.223),
    );

    final fill = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.4, 1.14),
        radius: 1.35,
        colors: [
          Color(0xFFFDF497),
          Color(0xFFFDF497),
          Color(0xFFFD5949),
          Color(0xFFD6249F),
          Color(0xFF285AEB),
        ],
        stops: [0.0, 0.05, 0.45, 0.60, 0.90],
      ).createShader(iconRect);

    canvas.drawRRect(icon, fill);

    final strokeW = w * 0.07;
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final inset = w * 0.22;
    final camera = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, w - inset * 2, w - inset * 2),
      Radius.circular(w * 0.155),
    );
    canvas.drawRRect(camera, stroke);

    canvas.drawCircle(
      Offset(w * 0.5, w * 0.5),
      w * 0.155,
      stroke,
    );

    canvas.drawCircle(
      Offset(w * 0.72, w * 0.28),
      w * 0.042,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
