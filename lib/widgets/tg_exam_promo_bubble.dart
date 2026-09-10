import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/tg_exam/exam_welcome_screen.dart';
import '../services/kpss_preference_service.dart';
import '../services/tg_exam_service.dart';
import 'tg_exam_gates.dart';

/// Dersler sekmesi — yayınlı TG deneme aktifken sağda kırmızı-beyaz baloncuk.
class TgExamPromoBubble extends StatefulWidget {
  final bool subjectsTabVisible;

  const TgExamPromoBubble({
    super.key,
    this.subjectsTabVisible = false,
  });

  @override
  State<TgExamPromoBubble> createState() => _TgExamPromoBubbleState();
}

class _TgExamPromoBubbleState extends State<TgExamPromoBubble> {
  static const _kYRatio = 'tg_exam_bubble_y_ratio_v1';
  /// v2: önceki kapatmalar (yanlışlıkla X) demo denemesini gizlemesin.
  static const _kHiddenExamId = 'tg_exam_bubble_hidden_id_v3';

  final GlobalKey _balloonKey = GlobalKey();
  double _yRatio = 0.42;
  bool _ratioLoaded = false;
  int? _hiddenExamId;
  Timer? _tick;

  static const _bubbleSize = 118.0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPrefs());
    TgExamService.instance.addListener(_onService);
    KpssPreferenceService.instance.addListener(_onKpss);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_ensureLoaded());
    });
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant TgExamPromoBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.subjectsTabVisible && !oldWidget.subjectsTabVisible) {
      unawaited(_ensureLoaded(force: true));
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    TgExamService.instance.removeListener(_onService);
    KpssPreferenceService.instance.removeListener(_onKpss);
    super.dispose();
  }

  void _onService() {
    if (mounted) setState(() {});
  }

  void _onKpss() {
    unawaited(
      TgExamService.instance.setKpssType(
        KpssPreferenceService.instance.kpssType,
      ),
    );
  }

  Future<void> _ensureLoaded({bool force = false}) async {
    final service = TgExamService.instance;
    final type = KpssPreferenceService.instance.kpssType;
    if (!service.isInitialized || force || service.kpssType != type) {
      await service.initialize(kpssType: type);
    } else if (force || service.exams.isEmpty) {
      await service.refresh();
    }
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_kYRatio);
    if (!mounted) return;
    setState(() {
      if (saved != null) _yRatio = saved.clamp(0.08, 0.92);
      _hiddenExamId = prefs.getInt(_kHiddenExamId);
      _ratioLoaded = true;
    });
  }

  Future<void> _saveRatio(double ratio) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kYRatio, ratio.clamp(0.08, 0.92));
  }

  Future<void> _dismissForExam(int examId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kHiddenExamId, examId);
    if (!mounted) return;
    setState(() => _hiddenExamId = examId);
  }

  Future<void> _openExam(BuildContext context, int examId) async {
    if (!await TgExamGates.requireGoogleAccount(context)) return;
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExamWelcomeScreen(examId: examId),
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
    final maxY =
        math.max(minY, size.height - pad.bottom - bottomBar - bubbleHeight);
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
    if (!widget.subjectsTabVisible || !_ratioLoaded) {
      return const SizedBox.shrink();
    }
    final exam = TgExamService.instance.liveExam;
    if (exam == null || exam.id == _hiddenExamId) {
      return const SizedBox.shrink();
    }

    final bounds = _verticalBounds(context, _bubbleSize);
    return Positioned(
      right: 4,
      top: bounds.y,
      child: _TgBalloon(
        key: _balloonKey,
        onDismiss: () => unawaited(_dismissForExam(exam.id)),
        onOpen: () => unawaited(_openExam(context, exam.id)),
        onDragUpdate: (dy) => _onDragUpdate(context, dy),
        onDragEnd: () => unawaited(_saveRatio(_yRatio)),
      ),
    );
  }
}

class _TgBalloon extends StatefulWidget {
  final VoidCallback onDismiss;
  final VoidCallback onOpen;
  final ValueChanged<double> onDragUpdate;
  final VoidCallback onDragEnd;

  const _TgBalloon({
    super.key,
    required this.onDismiss,
    required this.onOpen,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  static const size = 72.0;
  static const borderInset = 4.0;

  static const redWhiteRing = SweepGradient(
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFFECACA),
      Color(0xFFDC2626),
      Color(0xFF7F1D1D),
      Color(0xFFFFFFFF),
      Color(0xFFB91C1C),
      Color(0xFFFFFFFF),
    ],
    stops: [0.0, 0.16, 0.34, 0.5, 0.66, 0.84, 1.0],
  );

  @override
  State<_TgBalloon> createState() => _TgBalloonState();
}

class _TgBalloonState extends State<_TgBalloon> with TickerProviderStateMixin {
  late final AnimationController _ripple;
  late final AnimationController _idle;
  late final AnimationController _shine;

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
  }

  @override
  void dispose() {
    _ripple.dispose();
    _idle.dispose();
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const halo = 118.0;
    const bubble = _TgBalloon.size;

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: halo,
        height: halo,
        child: AnimatedBuilder(
          animation: Listenable.merge([_ripple, _idle, _shine]),
          builder: (context, _) {
            final float = math.sin(_idle.value * math.pi * 2) * 3.5;
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(halo, halo),
                  painter: _RedRipplePainter(
                    progress: _ripple.value,
                    coreRadius: bubble / 2,
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, float),
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
                                  color: const Color(0xFFDC2626)
                                      .withValues(alpha: 0.38),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.14),
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
                                    gradient: _TgBalloon.redWhiteRing,
                                  ),
                                ),
                                Container(
                                  width: bubble - _TgBalloon.borderInset * 2,
                                  height: bubble - _TgBalloon.borderInset * 2,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFFFFFFFF),
                                        Color(0xFFFFF1F2),
                                        Color(0xFFB91C1C),
                                        Color(0xFF7F1D1D),
                                      ],
                                      stops: [0.0, 0.28, 0.62, 1.0],
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Center(
                                          child: Transform.rotate(
                                            angle: -0.08,
                                            child: const Text.rich(
                                              TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: 'TG\n',
                                                    style: TextStyle(
                                                      fontFamily: 'serif',
                                                      fontSize: 15,
                                                      height: 0.95,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      letterSpacing: 1.1,
                                                      color: Color(0xFF7F1D1D),
                                                      shadows: [
                                                        Shadow(
                                                          color: Colors.white,
                                                          offset: Offset(0, 1),
                                                          blurRadius: 0,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: 'DENEME',
                                                    style: TextStyle(
                                                      fontFamily: 'serif',
                                                      fontSize: 9,
                                                      height: 1.05,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      letterSpacing: 0.6,
                                                      color: Color(0xFFFFF7F7),
                                                      shadows: [
                                                        Shadow(
                                                          color:
                                                              Color(0x88000000),
                                                          offset: Offset(0, 1),
                                                          blurRadius: 1,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                        IgnorePointer(
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment(
                                                  -1 + _shine.value * 2,
                                                  -1,
                                                ),
                                                end: Alignment(
                                                  _shine.value * 2,
                                                  1,
                                                ),
                                                colors: [
                                                  Colors.white.withValues(
                                                    alpha: 0.0,
                                                  ),
                                                  Colors.white.withValues(
                                                    alpha: 0.28,
                                                  ),
                                                  Colors.white.withValues(
                                                    alpha: 0.0,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
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
                        child: _CloseChip(onTap: widget.onDismiss),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CloseChip extends StatelessWidget {
  final VoidCallback onTap;

  const _CloseChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: const Color(0xFFDC2626), width: 1.2),
          ),
          child: const Icon(
            Icons.close,
            size: 13,
            color: Color(0xFF7F1D1D),
          ),
        ),
      ),
    );
  }
}

class _RedRipplePainter extends CustomPainter {
  final double progress;
  final double coreRadius;

  _RedRipplePainter({
    required this.progress,
    required this.coreRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 2; i++) {
      final t = ((progress + i * 0.45) % 1.0);
      final radius = coreRadius + 8 + t * 22;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * (1 - t)
        ..color = Color.lerp(
          const Color(0xFFFFFFFF),
          const Color(0xFFDC2626),
          t,
        )!
            .withValues(alpha: 0.38 * (1 - t));
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RedRipplePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.coreRadius != coreRadius;
  }
}
