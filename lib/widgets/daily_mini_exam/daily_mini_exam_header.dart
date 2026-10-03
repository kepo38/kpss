import 'package:flutter/material.dart';

import '../../constants/daily_mini_exam_constants.dart';
import '../../theme/app_theme.dart';
import '../../utils/daily_mini_exam_logic.dart';

class DailyMiniExamHeader extends StatelessWidget {
  const DailyMiniExamHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);
    final titleColor = AppTheme.onPage(context);
    final accent = dark ? AppTheme.champagneLight : AppTheme.champagne;

    return Padding(
      padding: const EdgeInsets.only(right: 78),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 2.5,
            height: 26,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  accent,
                  accent.withValues(alpha: 0.45),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.28),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              DailyMiniExamConstants.cardHeadline,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 16.5,
                height: 1.12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                color: titleColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DailyMiniExamClosingTimer extends StatelessWidget {
  final DailyMiniExamWindow window;
  final bool dark;

  const DailyMiniExamClosingTimer({
    super.key,
    required this.window,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = dark
        ? Colors.white.withValues(alpha: 0.72)
        : AppTheme.ink.withValues(alpha: 0.68);
    final timerColor =
        dark ? AppTheme.champagneLight : const Color(0xFF8F6E32);

    if (!window.isOpen) {
      return Text(
        'Açılış · ${DailyMiniExamConstants.opensClock}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          height: 1.1,
          color: labelColor,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Kapanış',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          formatHms(window.remaining),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontFeatures: const [FontFeature.tabularFigures()],
            fontFamily: 'serif',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1,
            letterSpacing: 0.4,
            color: timerColor,
          ),
        ),
      ],
    );
  }
}

class DailyMiniExamFreeRibbon extends StatelessWidget {
  final bool dark;

  const DailyMiniExamFreeRibbon({super.key, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Transform.translate(
        offset: const Offset(0, -1),
        child: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: AppTheme.champagne.withValues(alpha: dark ? 0.35 : 0.28),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: AppTheme.ink.withValues(alpha: dark ? 0.28 : 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: CustomPaint(
            painter: _RibbonPainter(dark: dark),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 7, 16, 11),
              child: Text(
                DailyMiniExamConstants.eyebrow,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.2,
                  height: 1,
                  color: dark ? AppTheme.ink : const Color(0xFF3D2E14),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RibbonPainter extends CustomPainter {
  final bool dark;

  const _RibbonPainter({required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - 7)
      ..lineTo(size.width * 0.56, size.height - 7)
      ..lineTo(size.width * 0.5, size.height)
      ..lineTo(size.width * 0.44, size.height - 7)
      ..lineTo(0, size.height - 7)
      ..close();

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: dark
            ? const [
                Color(0xFFF3E2B8),
                AppTheme.champagneLight,
                AppTheme.champagne,
              ]
            : const [
                Color(0xFFF7EED8),
                AppTheme.champagneLight,
                Color(0xFFC9A86C),
              ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(path, fill);

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppTheme.champagne.withValues(alpha: dark ? 0.55 : 0.65);
    canvas.drawPath(path, border);

    final shine = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.center,
        colors: [
          Colors.white.withValues(alpha: dark ? 0.28 : 0.42),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.45));
    canvas.drawPath(path, shine);
  }

  @override
  bool shouldRepaint(covariant _RibbonPainter oldDelegate) =>
      oldDelegate.dark != dark;
}
