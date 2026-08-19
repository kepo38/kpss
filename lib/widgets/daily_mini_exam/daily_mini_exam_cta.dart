import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../constants/daily_mini_exam_constants.dart';
import '../../theme/app_theme.dart';

class DailyMiniExamCta extends StatefulWidget {
  final String label;
  final bool enabled;
  final bool twoLineStart;

  const DailyMiniExamCta({
    super.key,
    required this.label,
    required this.enabled,
    this.twoLineStart = false,
  });

  @override
  State<DailyMiniExamCta> createState() => _DailyMiniExamCtaState();
}

class _DailyMiniExamCtaState extends State<DailyMiniExamCta>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (widget.enabled) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant DailyMiniExamCta oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.enabled && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);
    final disabledFill = dark
        ? Colors.white.withValues(alpha: 0.08)
        : AppTheme.ink.withValues(alpha: 0.06);
    final disabledText = dark
        ? Colors.white.withValues(alpha: 0.55)
        : AppTheme.slate.withValues(alpha: 0.7);
    const radius = 14.0;

    final body = Container(
      padding: EdgeInsets.symmetric(
        vertical: widget.twoLineStart ? 14 : 14,
        horizontal: widget.twoLineStart ? 16 : 14,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius - 1.5),
        gradient: widget.enabled
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFF8EE),
                  Color(0xFFF3E2B8),
                  Color(0xFFE8C878),
                  AppTheme.champagne,
                ],
                stops: [0.0, 0.35, 0.72, 1.0],
              )
            : null,
        color: widget.enabled ? null : disabledFill,
        border: widget.enabled
            ? Border.all(
                color: const Color(0xFFD4AF6A).withValues(alpha: 0.65),
                width: 1,
              )
            : null,
        boxShadow: widget.enabled
            ? [
                BoxShadow(
                  color: AppTheme.champagne.withValues(alpha: 0.38),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.55),
                  blurRadius: 0,
                  spreadRadius: 0.5,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: widget.twoLineStart && widget.enabled
          ? const Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DailyMiniExamConstants.ctaStartLine1,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 16.5,
                          height: 1.08,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.15,
                          color: AppTheme.ink,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 5),
                        child: _CtaGoldDivider(),
                      ),
                      _CtaStartLine2(),
                    ],
                  ),
                ),
                SizedBox(width: 10),
                _CtaPremiumMedallion(size: 34),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.15,
                      color: widget.enabled ? AppTheme.ink : disabledText,
                    ),
                  ),
                ),
                if (widget.enabled && !widget.twoLineStart) ...[
                  const SizedBox(width: 10),
                  const _CtaPremiumMedallion(size: 28),
                ],
              ],
            ),
    );

    if (!widget.enabled) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: AppTheme.hairline(context)),
        ),
        child: body,
      );
    }

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return CustomPaint(
          painter: _RunningGoldBorderPainter(
            progress: _ctrl.value,
            radius: radius,
          ),
          child: Padding(
            padding: const EdgeInsets.all(2.2),
            child: child,
          ),
        );
      },
      child: body,
    );
  }
}

class _CtaGoldDivider extends StatelessWidget {
  const _CtaGoldDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.champagne.withValues(alpha: 0.05),
            AppTheme.champagne.withValues(alpha: 0.55),
            AppTheme.champagne.withValues(alpha: 0.05),
          ],
        ),
      ),
    );
  }
}

class _CtaStartLine2 extends StatelessWidget {
  const _CtaStartLine2();

  @override
  Widget build(BuildContext context) {
    return Text(
      DailyMiniExamConstants.ctaStartLine2,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 11,
        height: 1.1,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
        color: AppTheme.ink.withValues(alpha: 0.68),
      ),
    );
  }
}

class _RunningGoldBorderPainter extends CustomPainter {
  final double progress;
  final double radius;

  _RunningGoldBorderPainter({
    required this.progress,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(1.1),
      Radius.circular(radius),
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = AppTheme.champagne.withValues(alpha: 0.38),
    );

    final shader = SweepGradient(
      transform: GradientRotation(progress * math.pi * 2),
      colors: const [
        Color(0x00FFFFFF),
        Color(0x66FFE5A0),
        Color(0xFFFFF8E7),
        Color(0xFFFFFFFF),
        Color(0xFFFFEDB0),
        Color(0xFFE8C878),
        Color(0x44C9A86C),
        Color(0x00FFFFFF),
      ],
      stops: const [0.0, 0.08, 0.14, 0.2, 0.28, 0.36, 0.46, 0.58],
    ).createShader(rect);

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant _RunningGoldBorderPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _CtaPremiumMedallion extends StatelessWidget {
  final double size;

  const _CtaPremiumMedallion({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF8EE),
            Color(0xFFF3E2B8),
            Color(0xFFE8C878),
            Color(0xFFC9A86C),
          ],
          stops: [0.0, 0.34, 0.72, 1.0],
        ),
        border: Border.all(
          color: const Color(0xFFD4AF6A).withValues(alpha: 0.92),
          width: 1.15,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.neonGold.withValues(alpha: 0.4),
            blurRadius: 10,
            spreadRadius: -1,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.55),
            blurRadius: 0,
            spreadRadius: 0.35,
            offset: const Offset(-0.5, -0.5),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/app_icon.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(
            Icons.emoji_events_rounded,
            size: size * 0.45,
            color: AppTheme.ink,
          ),
        ),
      ),
    );
  }
}
