import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/wrong_questions_screen.dart';
import '../services/ad_manager.dart';
import '../services/app_config_service.dart';
import '../services/auth_service.dart';
import '../services/content_bank_service.dart';
import '../theme/app_theme.dart';

/// Ana sayfa sol kenar — yanlış defteri balonu.
class WrongNotebookPromoBubble extends StatefulWidget {
  const WrongNotebookPromoBubble({super.key});

  @override
  State<WrongNotebookPromoBubble> createState() =>
      _WrongNotebookPromoBubbleState();
}

class _WrongNotebookPromoBubbleState extends State<WrongNotebookPromoBubble> {
  static const _kYRatio = 'wrong_notebook_bubble_y_ratio_v4';

  final GlobalKey _balloonKey = GlobalKey();
  /// Sol-orta, biraz aşağı (~%34).
  double _yRatio = 0.34;
  bool _ratioLoaded = false;

  static const _bubbleSize = 118.0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadRatio());
  }

  Future<void> _loadRatio() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_kYRatio);
    if (!mounted) return;
    setState(() {
      if (saved != null) _yRatio = saved.clamp(0.08, 0.92);
      _ratioLoaded = true;
    });
  }

  Future<void> _saveRatio(double ratio) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kYRatio, ratio.clamp(0.08, 0.92));
  }

  Future<void> _openWrongNotebook(BuildContext context) async {
    await AdManager.instance.onPageTransition();
    if (!context.mounted) return;
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const WrongQuestionsScreen(),
        ),
      ),
    );
  }

  ({double minY, double maxY, double y}) _verticalBounds(
    BuildContext context,
    double bubbleHeight,
  ) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    const topBar = 52.0;
    const bottomBar = 92.0;
    final minY = pad.top + topBar;
    final maxY = math.max(minY, size.height - pad.bottom - bottomBar - bubbleHeight);
    final y = minY + (maxY - minY) * _yRatio;
    return (minY: minY, maxY: maxY, y: y.clamp(minY, maxY));
  }

  void _onDragUpdate(BuildContext context, double deltaDy) {
    final box = _balloonKey.currentContext?.findRenderObject() as RenderBox?;
    final bubbleH = box?.size.height ?? _bubbleSize;
    final bounds = _verticalBounds(context, bubbleH);
    final span = bounds.maxY - bounds.minY;
    if (span <= 0) return;
    setState(() {
      final currentY = bounds.minY + span * _yRatio;
      final nextY = (currentY + deltaDy).clamp(bounds.minY, bounds.maxY);
      _yRatio = ((nextY - bounds.minY) / span).clamp(0.08, 0.92);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppConfigService.instance,
        AuthService.instance,
        ContentBankService.instance,
      ]),
      builder: (context, _) {
        final cfg = AppConfigService.instance;
        final auth = AuthService.instance;
        final hasGoogle = auth.isSignedIn && !auth.isAnonymous;
        final hasCompletedTest =
            ContentBankService.instance.hasCompletedAnyTest;
        if (!cfg.showWrongNotebookBubble ||
            !_ratioLoaded ||
            !hasGoogle ||
            !hasCompletedTest) {
          return const SizedBox.shrink();
        }

        final bounds = _verticalBounds(context, _bubbleSize);

        return Positioned(
          left: 2,
          top: bounds.y,
          child: _PromoBalloon(
            key: _balloonKey,
            label: cfg.wrongNotebookBubbleLabel,
            onDismiss: AppConfigService.instance.dismissWrongNotebookBubble,
            onOpen: () => _openWrongNotebook(context),
            onDragUpdate: (dy) => _onDragUpdate(context, dy),
            onDragEnd: () => unawaited(_saveRatio(_yRatio)),
          ),
        );
      },
    );
  }
}

class _PromoBalloon extends StatefulWidget {
  final String label;
  final VoidCallback onDismiss;
  final VoidCallback onOpen;
  final ValueChanged<double> onDragUpdate;
  final VoidCallback onDragEnd;

  const _PromoBalloon({
    super.key,
    required this.label,
    required this.onDismiss,
    required this.onOpen,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  static const size = 70.0;
  static const borderInset = 4.0;

  /// Premium mavi-yeşil dönen çerçeve.
  static const premiumRing = SweepGradient(
    colors: [
      Color(0xFF5EEAD4),
      Color(0xFF34D399),
      Color(0xFF22D3EE),
      Color(0xFF60A5FA),
      Color(0xFF2DD4BF),
      Color(0xFF5EEAD4),
    ],
    stops: [0.0, 0.2, 0.4, 0.6, 0.82, 1.0],
  );

  @override
  State<_PromoBalloon> createState() => _PromoBalloonState();
}

class _PromoBalloonState extends State<_PromoBalloon>
    with TickerProviderStateMixin {
  late final AnimationController _ripple;
  late final AnimationController _idle;
  late final AnimationController _shine;
  late final AnimationController _nudge;
  late final AnimationController _textReveal;

  @override
  void initState() {
    super.initState();
    _ripple = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _shine = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _nudge = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
    _textReveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
  }

  @override
  void dispose() {
    _ripple.dispose();
    _idle.dispose();
    _shine.dispose();
    _nudge.dispose();
    _textReveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);
    const halo = 118.0;
    const bubble = _PromoBalloon.size;
    final lines = _parseBubbleLines(widget.label);

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: halo,
        height: halo,
        child: AnimatedBuilder(
          animation: Listenable.merge(
            [_ripple, _idle, _shine, _nudge, _textReveal],
          ),
          builder: (context, _) {
            final float = math.sin(_idle.value * math.pi * 2) * 4.0;
            final nudgeT = Curves.easeInOut.transform(
              ((_nudge.value - 0.72) / 0.18).clamp(0.0, 1.0),
            );
            final bounce = 1.0 +
                0.07 * math.sin(nudgeT * math.pi) *
                    (1.0 - (nudgeT - 0.5).abs() * 0.15);
            final tilt = 0.10 * math.sin(nudgeT * math.pi * 3);

            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(halo, halo),
                  painter: _PromoRipplePainter(
                    progress: _ripple.value,
                    color: const Color(0xFF5EEAD4),
                    sparklePhase: _idle.value,
                    coreRadius: bubble / 2,
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, float),
                  child: Transform.rotate(
                    angle: tilt,
                    child: Transform.scale(
                      scale: bounce,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onVerticalDragUpdate: (d) =>
                                widget.onDragUpdate(d.delta.dy),
                            onVerticalDragEnd: (_) => widget.onDragEnd(),
                            onTap: widget.onOpen,
                            child: SizedBox(
                              width: bubble,
                              height: bubble,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF5EEAD4)
                                          .withValues(alpha: 0.42),
                                      blurRadius: 14,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 4),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: dark ? 0.32 : 0.12,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    const DecoratedBox(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: _PromoBalloon.premiumRing,
                                      ),
                                    ),
                                    Container(
                                      width: bubble -
                                          _PromoBalloon.borderInset * 2,
                                      height: bubble -
                                          _PromoBalloon.borderInset * 2,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: dark
                                              ? const [
                                                  Color(0xFF0E2230),
                                                  Color(0xFF081820),
                                                  Color(0xFF041018),
                                                ]
                                              : const [
                                                  Color(0xFF0A4D44),
                                                  Color(0xFF063830),
                                                  Color(0xFF032821),
                                                ],
                                        ),
                                        border: Border.all(
                                          color: const Color(0xFF5EEAD4)
                                              .withValues(alpha: 0.55),
                                          width: 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF022C26)
                                                .withValues(alpha: 0.45),
                                            blurRadius: 6,
                                            spreadRadius: -1,
                                          ),
                                        ],
                                      ),
                                      child: ClipOval(
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            DecoratedBox(
                                              decoration: BoxDecoration(
                                                gradient: RadialGradient(
                                                  center: const Alignment(
                                                    -0.35,
                                                    -0.4,
                                                  ),
                                                  radius: 1.05,
                                                  colors: [
                                                    const Color(0xFF2DD4BF)
                                                        .withValues(
                                                      alpha: dark ? 0.14 : 0.22,
                                                    ),
                                                    Colors.transparent,
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Center(
                                              child: _Bubble3DSequentialLabel(
                                                line1: lines.$1,
                                                line2: lines.$2,
                                                reveal: _textReveal.value,
                                                dark: dark,
                                                tilt: tilt,
                                              ),
                                            ),
                                            _ShineSweep(
                                              progress: _shine.value,
                                              dark: dark,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: _BubbleCloseButton(
                              onTap: widget.onDismiss,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  (String, String) _parseBubbleLines(String raw) {
    final text = _turkishUpper(raw.trim());
    if (text.contains('\n')) {
      final parts = text.split('\n');
      if (parts.length >= 2) {
        return (parts.first.trim(), parts.sublist(1).join(' ').trim());
      }
    }
    final parts = text.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return (parts.first, parts.sublist(1).join(' '));
    }
    return ('YANLIŞ', 'DEFTERİM');
  }

  static String _turkishUpper(String input) {
    final buf = StringBuffer();
    for (final ch in input.split('')) {
      switch (ch) {
        case 'i':
          buf.write('İ');
        case 'ı':
          buf.write('I');
        case 'ş':
          buf.write('Ş');
        case 'ğ':
          buf.write('Ğ');
        case 'ü':
          buf.write('Ü');
        case 'ö':
          buf.write('Ö');
        case 'ç':
          buf.write('Ç');
        default:
          buf.write(ch.toUpperCase());
      }
    }
    return buf.toString();
  }
}

/// Sırayla YANLIŞ → DEFTERİM; extrude + perspektif ile daire içine sığar.
class _Bubble3DSequentialLabel extends StatelessWidget {
  final String line1;
  final String line2;
  final double reveal;
  final bool dark;
  final double tilt;

  const _Bubble3DSequentialLabel({
    required this.line1,
    required this.line2,
    required this.reveal,
    required this.dark,
    required this.tilt,
  });

  @override
  Widget build(BuildContext context) {
    final line1T = Curves.easeOutBack.transform(
      (reveal / 0.32).clamp(0.0, 1.0),
    );
    final line2T = Curves.easeOutBack.transform(
      ((reveal - 0.38) / 0.32).clamp(0.0, 1.0),
    );
    final holdWobble = math.sin(reveal * math.pi * 2) * 0.015;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0024)
        ..rotateX(-0.1 + holdWobble)
        ..rotateY(0.06 + tilt * 0.35),
      child: SizedBox(
        width: 66,
        height: 58,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _Bubble3DLine(
              text: line1,
              reveal: line1T,
            ),
            if (line2T > 0) ...[
              SizedBox(height: 1 + line2T),
              _Bubble3DLine(
                text: line2,
                reveal: line2T,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Bubble3DLine extends StatelessWidget {
  final String text;
  final double reveal;

  const _Bubble3DLine({
    required this.text,
    required this.reveal,
  });

  static const _baseStyle = TextStyle(
    fontFamily: 'serif',
    fontSize: 8.5,
    height: 1.0,
    letterSpacing: 0.2,
    fontWeight: FontWeight.w900,
  );

  @override
  Widget build(BuildContext context) {
    if (reveal <= 0) return const SizedBox.shrink();

    const face = Color(0xFFF0FDFA);
    const depth = Color(0xFF011612);
    const edge = Color(0xFF5EEAD4);
    final pop = reveal.clamp(0.0, 1.0);

    return Opacity(
      opacity: pop,
      child: Transform.scale(
        scale: 0.72 + pop * 0.28,
        alignment: Alignment.center,
        child: Transform.translate(
          offset: Offset(0, (1 - pop) * 5),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              for (var i = 5; i >= 1; i--)
                Transform.translate(
                  offset: Offset(i * 0.28, i * 0.38),
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: _baseStyle.copyWith(
                      color: depth.withValues(alpha: 0.28 * i),
                    ),
                  ),
                ),
              Text(
                text,
                textAlign: TextAlign.center,
                style: _baseStyle.copyWith(
                  color: face,
                  shadows: const [
                    Shadow(
                      color: Color(0xCC011612),
                      offset: Offset(0, 1.2),
                      blurRadius: 0,
                    ),
                    Shadow(
                      color: Color(0x885EEAD4),
                      offset: Offset(0, 0),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(-0.45, -0.55),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: _baseStyle.copyWith(
                    color: edge.withValues(alpha: 0.55 * pop),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BubbleCloseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BubbleCloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(
            color: AppTheme.ink.withValues(alpha: 0.85),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: const Icon(
          Icons.close_rounded,
          size: 13,
          color: AppTheme.ink,
        ),
      ),
    );
  }
}

class _ShineSweep extends StatelessWidget {
  final double progress;
  final bool dark;

  const _ShineSweep({
    required this.progress,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final t = ((progress - 0.15) / 0.45).clamp(0.0, 1.0);
    if (t <= 0 || t >= 1) return const SizedBox.shrink();
    final x = -40.0 + 110.0 * t;
    return IgnorePointer(
      child: Transform.translate(
        offset: Offset(x, -8),
        child: Transform.rotate(
          angle: -0.72,
          child: Container(
            width: 18,
            height: 110,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFF99F6E4).withValues(alpha: dark ? 0.12 : 0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PromoRipplePainter extends CustomPainter {
  final double progress;
  final Color color;
  final double sparklePhase;
  final double coreRadius;

  const _PromoRipplePainter({
    required this.progress,
    required this.color,
    required this.sparklePhase,
    required this.coreRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.shortestSide / 2;

    void ring(double delay) {
      final p = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (p <= 0) return;
      final r = coreRadius + (maxR - coreRadius) * p;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (2.6 * (1 - p)).clamp(0.7, 2.6)
          ..color = color.withValues(alpha: 0.48 * (1 - p)),
      );
    }

    ring(0);
    ring(0.38);

    const sparkles = 5;
    for (var i = 0; i < sparkles; i++) {
      final phase = (sparklePhase + i / sparkles) % 1.0;
      final appear = math.sin(phase * math.pi);
      if (appear <= 0.08) continue;
      final angle = (i / sparkles) * math.pi * 2 + sparklePhase * math.pi * 2;
      final dist = coreRadius + 10 + 8 * appear;
      final p = Offset(
        center.dx + math.cos(angle) * dist,
        center.dy + math.sin(angle) * dist,
      );
      final s = 1.4 + 1.8 * appear;
      canvas.drawCircle(
        p,
        s,
        Paint()
          ..color = const Color(0xFF99F6E4).withValues(alpha: 0.7 * appear),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PromoRipplePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.sparklePhase != sparklePhase ||
        oldDelegate.color != color;
  }
}
