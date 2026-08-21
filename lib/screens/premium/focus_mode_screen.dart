import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/pomodoro_session_model.dart';
import '../../services/gamification_service.dart';
import '../../services/notification_service.dart';
import '../../services/pomodoro_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/scale_button.dart';

/// Neon odak paleti
class _Neon {
  static const base = Color(0xFF05060A);
  static const magenta = Color(0xFFD500F9);
  static const red = Color(0xFFFF1744);
  static const cyan = Color(0xFF00E5FF);
  static const blue = Color(0xFF2979FF);
  static const pinkSoft = Color(0xFFFF80AB);
}

class FocusModeScreen extends StatefulWidget {
  const FocusModeScreen({super.key});

  @override
  State<FocusModeScreen> createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends State<FocusModeScreen>
    with WidgetsBindingObserver {
  final _pomodoro = PomodoroService.instance;
  PomodoroPreset _preset = PomodoroPreset.kisa25;
  int _customMinutes = 30;
  int _remainingSeconds = 25 * 60;
  Timer? _timer;
  bool _isRunning = false;
  bool _isBreak = false;
  bool _fullscreen = false;
  bool _ambientBusy = false;
  DateTime? _sessionEndAt;

  int get _totalSeconds {
    if (_preset == PomodoroPreset.ozel) return _customMinutes * 60;
    return _preset.dakika * 60;
  }

  double get _progress {
    if (_totalSeconds <= 0) return 0;
    final total = _isBreak ? 5 * 60 : _totalSeconds;
    return (1.0 - (_remainingSeconds / total)).clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isRunning && _sessionEndAt != null) {
      final left = _sessionEndAt!.difference(DateTime.now()).inSeconds;
      if (left <= 0) {
        _onSessionComplete();
      } else if (left != _remainingSeconds) {
        setState(() => _remainingSeconds = left);
      }
    }
  }

  Future<void> _startTimer() async {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      if (_remainingSeconds == _totalSeconds || _remainingSeconds == 0) {
        _remainingSeconds = _isBreak ? 5 * 60 : _totalSeconds;
      }
      _sessionEndAt = DateTime.now().add(Duration(seconds: _remainingSeconds));
    });
    await _pomodoro.setSessionActive(true);
    await NotificationService.instance.scheduleFocusTimerComplete(
      endsAt: _sessionEndAt!,
      isBreakEnding: _isBreak,
    );
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_sessionEndAt != null) {
        final left = _sessionEndAt!.difference(DateTime.now()).inSeconds;
        if (left <= 0) {
          _onSessionComplete();
          return;
        }
        setState(() => _remainingSeconds = left);
      } else if (_remainingSeconds <= 0) {
        _onSessionComplete();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  Future<void> _pauseTimer() async {
    _timer?.cancel();
    _sessionEndAt = null;
    await NotificationService.instance.cancelFocusTimerComplete();
    await _pomodoro.setSessionActive(false);
    setState(() => _isRunning = false);
  }

  Future<void> _resetTimer() async {
    _timer?.cancel();
    _sessionEndAt = null;
    await NotificationService.instance.cancelFocusTimerComplete();
    await _pomodoro.setSessionActive(false);
    setState(() {
      _isRunning = false;
      _isBreak = false;
      _remainingSeconds = _totalSeconds;
    });
  }

  Future<void> _onSessionComplete() async {
    _timer?.cancel();
    _sessionEndAt = null;
    await _pomodoro.setSessionActive(false);
    await NotificationService.instance.cancelFocusTimerComplete();

    final endingBreak = _isBreak;
    if (!_isBreak) {
      _pomodoro.completeSession(PomodoroSessionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sureDakika: _totalSeconds ~/ 60,
        baslangic: DateTime.now().subtract(Duration(seconds: _totalSeconds)),
        bitis: DateTime.now(),
        tamamlandi: true,
      ));
      GamificationService.instance.recordStudyMinutes(_totalSeconds ~/ 60);
    }

    unawaited(_pomodoro.playCompletionChime());
    unawaited(HapticFeedback.heavyImpact());
    unawaited(NotificationService.instance.showFocusTimerComplete(
      isBreakEnding: endingBreak,
    ));

    if (!mounted) return;
    setState(() {
      _isRunning = false;
      _isBreak = !_isBreak;
      _remainingSeconds = _isBreak ? 5 * 60 : _totalSeconds;
    });

    if (!mounted) return;
    final title = endingBreak ? 'Mola bitti' : 'Odak tamamlandı';
    final body = endingBreak
        ? 'Yeni bir odak turuna başlayabilirsin.'
        : 'Harika iş. 5 dk mola veya yeni tur.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.inkSoft,
        content: Text(
          '$title — $body',
          style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  String get _timeLabel {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    unawaited(NotificationService.instance.cancelFocusTimerComplete());
    unawaited(_pomodoro.setSessionActive(false));
    unawaited(_pomodoro.stopAmbient());
    super.dispose();
  }

  Future<void> _selectAmbient(AmbientSound sound) async {
    if (_ambientBusy) return;
    setState(() => _ambientBusy = true);
    await _pomodoro.setSelectedSound(sound);
    if (mounted) setState(() => _ambientBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_fullscreen) return _buildFullscreen();

    return Scaffold(
      backgroundColor: _Neon.base,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _NeonBackdrop(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PremiumTimerRing(
                          time: _timeLabel,
                          progress: _progress,
                          isBreak: _isBreak,
                          isRunning: _isRunning,
                        ),
                        const SizedBox(height: 22),
                        _buildPlayControls(),
                        const SizedBox(height: 28),
                        _buildPresets(),
                        if (_preset == PomodoroPreset.ozel) ...[
                          const SizedBox(height: 8),
                          _buildCustomSlider(),
                        ],
                        const SizedBox(height: 28),
                        _buildAmbientSection(),
                        const SizedBox(height: 18),
                        Text(
                          'Bugün · ${_pomodoro.bugunToplamDakika} dk odak',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            letterSpacing: 0.4,
                            color: _Neon.cyan.withValues(alpha: 0.65),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          const AppBackButton(),
          Expanded(
            child: Column(
              children: [
                Text(
                  'ODAK MODU',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Neon odak seansı',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    letterSpacing: 0.8,
                    color: _Neon.cyan.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.fullscreen_rounded,
              color: Colors.white.withValues(alpha: 0.85),
            ),
            onPressed: () => setState(() => _fullscreen = true),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayControls() {
    final accent = _isBreak ? _Neon.pinkSoft : _Neon.cyan;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleButton(
              onPressed: () => unawaited(_isRunning ? _pauseTimer() : _startTimer()),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: 0.35),
                      _Neon.magenta.withValues(alpha: 0.25),
                    ],
                  ),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.85),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.45),
                      blurRadius: 22,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: _Neon.magenta.withValues(alpha: 0.22),
                      blurRadius: 28,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(width: 18),
            ScaleButton(
              onPressed: () => unawaited(_resetTimer()),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPresets() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: PomodoroPreset.values.map((p) {
        final selected = _preset == p;
        final label = p == PomodoroPreset.ozel ? '$_customMinutes dk' : p.label;
        return GestureDetector(
          onTap: _isRunning
              ? null
              : () => setState(() {
                    _preset = p;
                    _remainingSeconds = _totalSeconds;
                  }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: selected
                  ? const LinearGradient(
                      colors: [
                        Color(0xFF00E5FF),
                        Color(0xFF2979FF),
                        Color(0xFFD500F9),
                      ],
                    )
                  : null,
              color: selected ? null : Colors.white.withValues(alpha: 0.06),
              border: Border.all(
                color: selected
                    ? _Neon.cyan
                    : Colors.white.withValues(alpha: 0.12),
                width: selected ? 1.2 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: _Neon.cyan.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  const Icon(Icons.check_rounded, size: 15, color: Colors.white),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.88),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCustomSlider() {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: _Neon.cyan,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
        thumbColor: _Neon.cyan,
        overlayColor: _Neon.cyan.withValues(alpha: 0.18),
      ),
      child: Slider(
        value: _customMinutes.toDouble(),
        min: 10,
        max: 120,
        divisions: 22,
        label: '$_customMinutes dk',
        onChanged: _isRunning
            ? null
            : (v) => setState(() {
                  _customMinutes = v.round();
                  _remainingSeconds = _customMinutes * 60;
                }),
      ),
    );
  }

  Widget _buildAmbientSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ortam Sesi',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Doğa · kafe · kütüphane · deniz · binaural Hz — kilitliyken de çalar',
          style: GoogleFonts.manrope(
            fontSize: 12,
            color: _Neon.cyan.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AmbientSound.values.map((s) {
            final selected = _pomodoro.selectedSound == s;
            final playing = selected &&
                _pomodoro.ambientPlaying &&
                s != AmbientSound.sessiz;
            return Opacity(
              opacity: _ambientBusy ? 0.55 : 1,
              child: GestureDetector(
                onTap: _ambientBusy
                    ? null
                    : () => unawaited(
                          _selectAmbient(selected ? AmbientSound.sessiz : s),
                        ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: (MediaQuery.sizeOf(context).width - 56) / 2,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: selected
                        ? _Neon.magenta.withValues(alpha: 0.16)
                        : Colors.white.withValues(alpha: 0.05),
                    border: Border.all(
                      color: selected
                          ? _Neon.cyan.withValues(alpha: 0.75)
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: _Neon.cyan.withValues(alpha: 0.18),
                              blurRadius: 12,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected
                              ? _Neon.cyan.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.06),
                        ),
                        child: Icon(
                          playing ? Icons.graphic_eq_rounded : s.icon,
                          size: 17,
                          color: selected
                              ? _Neon.cyan
                              : Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.label,
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.95),
                              ),
                            ),
                            Text(
                              s.subtitle,
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                color: _Neon.magenta.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (_pomodoro.selectedSound != AmbientSound.sessiz) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.volume_down_rounded,
                  size: 18, color: Colors.white.withValues(alpha: 0.45)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: _Neon.cyan,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
                    thumbColor: _Neon.cyan,
                  ),
                  child: Slider(
                    value: _pomodoro.ambientVolume,
                    min: 0.12,
                    max: 0.9,
                    divisions: 16,
                    onChanged: _ambientBusy
                        ? null
                        : (v) {
                            setState(() {});
                            unawaited(_pomodoro.setAmbientVolume(v));
                          },
                  ),
                ),
              ),
              Icon(Icons.volume_up_rounded,
                  size: 18, color: Colors.white.withValues(alpha: 0.45)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildFullscreen() {
    return Scaffold(
      backgroundColor: _Neon.base,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _NeonBackdrop(),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.fullscreen_exit_rounded, color: Colors.white70),
                    onPressed: () => setState(() => _fullscreen = false),
                  ),
                ),
                const Spacer(),
                Text(
                  _isBreak ? 'MOLA' : 'ODAK',
                  style: GoogleFonts.manrope(
                    color: _isBreak ? _Neon.pinkSoft : _Neon.cyan,
                    letterSpacing: 6,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _timeLabel,
                  style: GoogleFonts.manrope(
                    fontSize: 78,
                    fontWeight: FontWeight.w300,
                    color: Colors.white,
                    letterSpacing: 2,
                    height: 1,
                  ),
                ),
                const Spacer(),
                ScaleButton(
                  onPressed: () =>
                      unawaited(_isRunning ? _pauseTimer() : _startTimer()),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (_isBreak ? _Neon.pinkSoft : _Neon.cyan)
                            .withValues(alpha: 0.9),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_isBreak ? _Neon.pinkSoft : _Neon.cyan)
                              .withValues(alpha: 0.45),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NeonBackdrop extends StatelessWidget {
  const _NeonBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: _Neon.base),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: const Alignment(-0.9, -1.0),
              end: const Alignment(0.9, 1.0),
              colors: [
                _Neon.magenta.withValues(alpha: 0.22),
                _Neon.base,
                _Neon.blue.withValues(alpha: 0.2),
              ],
              stops: const [0.0, 0.48, 1.0],
            ),
          ),
        ),
        Positioned(
          top: -80,
          left: -60,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _Neon.red.withValues(alpha: 0.55),
                    _Neon.magenta.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -100,
          right: -70,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _Neon.cyan.withValues(alpha: 0.5),
                    _Neon.blue.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PremiumTimerRing extends StatelessWidget {
  final String time;
  final double progress;
  final bool isBreak;
  final bool isRunning;

  const _PremiumTimerRing({
    required this.time,
    required this.progress,
    required this.isBreak,
    required this.isRunning,
  });

  Color get _progressColor => isBreak ? _Neon.pinkSoft : _Neon.cyan;

  @override
  Widget build(BuildContext context) {
    final glow = _progressColor;
    return Center(
      child: SizedBox(
        width: 260,
        height: 260,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: glow.withValues(alpha: isRunning ? 0.28 : 0.12),
                    blurRadius: 40,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            CustomPaint(
              size: const Size(260, 260),
              painter: _RingPainter(
                progress: progress,
                trackColor: Colors.white.withValues(alpha: 0.08),
                progressColor: glow,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isBreak ? 'Mola' : 'Odaklan',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w600,
                    color: glow.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  time,
                  style: GoogleFonts.manrope(
                    fontSize: 56,
                    fontWeight: FontWeight.w300,
                    color: Colors.white,
                    letterSpacing: 1,
                    height: 1,
                  ),
                ),
                if (isRunning) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: glow.withValues(alpha: 0.15),
                      border: Border.all(
                        color: glow.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      'ÇALIŞIYOR',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                        color: glow,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;

  _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final prog = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [
          progressColor.withValues(alpha: 0.55),
          progressColor,
          progressColor.withValues(alpha: 0.9),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      prog,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.progressColor != progressColor;
}
