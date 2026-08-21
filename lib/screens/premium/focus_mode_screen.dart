import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/brand_constants.dart';
import '../../models/pomodoro_session_model.dart';
import '../../services/auth_service.dart';
import '../../services/pomodoro_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/account_link_card.dart';
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
  final _auth = AuthService.instance;
  bool _fullscreen = false;
  bool _deepWorkBusy = false;
  bool _ambientBusy = false;

  bool get _isGoogleUser => _auth.hasPermanentAccount;

  String get _userDisplayName {
    final isim = _auth.user?.isim.trim() ?? '';
    if (isim.isEmpty) return BrandConstants.defaultProfileName;
    return isim;
  }

  String get _todayStudyLabel {
    final total = _pomodoro.bugunToplamDakika;
    if (total <= 0) return 'Bugün henüz ders yok';
    final hours = total ~/ 60;
    final mins = total % 60;
    if (hours <= 0) return 'Bugün · $mins dk';
    if (mins <= 0) return 'Bugün · $hours sa';
    return 'Bugün · $hours sa $mins dk';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pomodoro.addListener(_onPomodoroChanged);
    _auth.addListener(_onAuthChanged);
    _pomodoro.onSessionCompleteUi = _showSessionCompleteSnack;
    _enforceGuestLimits();
  }

  void _onPomodoroChanged() {
    if (mounted) setState(() {});
  }

  void _onAuthChanged() {
    if (!mounted) return;
    _enforceGuestLimits();
    setState(() {});
  }

  void _enforceGuestLimits() {
    if (_isGoogleUser) return;
    if (_fullscreen) _fullscreen = false;
    if (_pomodoro.preset != PomodoroPreset.dk20 && !_pomodoro.isRunning) {
      _pomodoro.setPreset(PomodoroPreset.dk20);
    }
  }

  Future<bool> _requireGoogle({
    required String title,
    required String subtitle,
  }) async {
    if (_isGoogleUser) return true;
    final ok = await AccountLinkCard.prompt(
      context,
      title: title,
      subtitle: subtitle,
    );
    if (!mounted) return false;
    return ok && _auth.hasPermanentAccount;
  }

  void _showSessionCompleteSnack({
    required bool endingBreak,
    required String title,
    required String body,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.inkSoft,
        content: Text(
          '$title — $body',
          style: GoogleFonts.manrope(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pomodoro.syncFromLifecycle();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pomodoro.removeListener(_onPomodoroChanged);
    _auth.removeListener(_onAuthChanged);
    if (_pomodoro.onSessionCompleteUi == _showSessionCompleteSnack) {
      _pomodoro.onSessionCompleteUi = null;
    }
    // Timer + Deep Work serviste kalır — geri gelince / testlerde müzik sürer.
    super.dispose();
  }

  Future<void> _selectAmbient(AmbientSound sound) async {
    if (_ambientBusy) return;
    setState(() => _ambientBusy = true);
    await _pomodoro.setSelectedSound(sound);
    if (mounted) setState(() => _ambientBusy = false);
  }

  Future<void> _onPresetTap(PomodoroPreset p) async {
    if (_pomodoro.isRunning) return;
    if (!_isGoogleUser && p != PomodoroPreset.dk20) {
      final ok = await _requireGoogle(
        title: 'Daha uzun odak',
        subtitle:
            'Misafir en fazla 20 dk seçebilir. 40 / 60 dk için Google ile giriş yap.',
      );
      if (!ok || !mounted) return;
    }
    _pomodoro.setPreset(p);
  }

  Future<void> _onFullscreenTap() async {
    if (!_isGoogleUser) {
      await _requireGoogle(
        title: 'Tam ekran odak',
        subtitle:
            'Tam ekran Pomodoro için Google ile giriş yapman gerekiyor.',
      );
      return;
    }
    setState(() => _fullscreen = true);
  }

  Future<void> _toggleDeepWorkMusic() async {
    if (_deepWorkBusy) return;

    if (_pomodoro.deepWorkPlaying) {
      setState(() => _deepWorkBusy = true);
      await _pomodoro.stopDeepWork();
      if (mounted) setState(() => _deepWorkBusy = false);
      return;
    }

    setState(() => _deepWorkBusy = true);
    try {
      await _pomodoro.playDeepWork();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.inkSoft,
          content: Text(
            'Deep Work müziği çalınamadı.',
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    if (mounted) setState(() => _deepWorkBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_fullscreen && _isGoogleUser) return _buildFullscreen();
    if (_fullscreen && !_isGoogleUser) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _fullscreen = false);
      });
    }

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
                          time: _pomodoro.timeLabel,
                          progress: _pomodoro.progress,
                          isBreak: _pomodoro.isBreak,
                          isRunning: _pomodoro.isRunning,
                        ),
                        const SizedBox(height: 22),
                        _buildPlayControls(),
                        const SizedBox(height: 22),
                        _buildPresets(),
                        const SizedBox(height: 28),
                        _buildDeepWorkMusicButton(),
                        const SizedBox(height: 16),
                        _buildAmbientButtons(),
                        const SizedBox(height: 28),
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
    final canFullscreen = _isGoogleUser;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          const AppBackButton(),
          Expanded(
            child: Text(
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
          ),
          IconButton(
            icon: Icon(
              canFullscreen
                  ? Icons.fullscreen_rounded
                  : Icons.lock_outline_rounded,
              color: Colors.white.withValues(alpha: canFullscreen ? 0.85 : 0.45),
            ),
            tooltip: canFullscreen
                ? 'Tam ekran'
                : 'Tam ekran için Google girişi',
            onPressed: () => unawaited(_onFullscreenTap()),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayControls() {
    final accent = _pomodoro.isBreak ? _Neon.pinkSoft : _Neon.cyan;
    return Center(
      child: ScaleButton(
        onPressed: () => unawaited(
          _pomodoro.isRunning ? _pomodoro.pauseTimer() : _pomodoro.startTimer(),
        ),
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
            _pomodoro.isRunning
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),
      ),
    );
  }

  Widget _buildPresets() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < PomodoroPreset.values.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              _buildPresetChip(PomodoroPreset.values[i]),
            ],
          ],
        ),
        if (!_isGoogleUser) ...[
          const SizedBox(height: 8),
          Text(
            'Misafir · en fazla 20 dk · Google ile daha uzun süre',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 11,
              color: _Neon.cyan.withValues(alpha: 0.55),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => unawaited(_pomodoro.resetTimer()),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white.withValues(alpha: 0.55),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'Sıfırla',
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPresetChip(PomodoroPreset p) {
    final selected = _pomodoro.preset == p;
    final locked = !_isGoogleUser && p != PomodoroPreset.dk20;
    return Opacity(
      opacity: locked ? 0.55 : 1,
      child: GestureDetector(
        onTap: _pomodoro.isRunning
            ? null
            : () => unawaited(_onPresetTap(p)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              if (locked) ...[
                Icon(
                  Icons.lock_outline_rounded,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 5),
              ] else if (selected) ...[
                const Icon(Icons.check_rounded, size: 15, color: Colors.white),
                const SizedBox(width: 5),
              ],
              Text(
                p.label,
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
      ),
    );
  }

  Widget _buildAmbientButtons() {
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: AmbientSound.values
              .where((s) => s != AmbientSound.sessiz)
              .map((s) {
            final selected = _pomodoro.selectedSound == s;
            final playing = selected && _pomodoro.ambientPlaying;
            return Opacity(
              opacity: _ambientBusy ? 0.55 : 1,
              child: GestureDetector(
                onTap: _ambientBusy
                    ? null
                    : () => unawaited(
                          _selectAmbient(
                            selected ? AmbientSound.sessiz : s,
                          ),
                        ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: (MediaQuery.sizeOf(context).width - 56) / 2,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                        child: Text(
                          s.label,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
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
              Icon(
                Icons.volume_down_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.45),
              ),
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
              Icon(
                Icons.volume_up_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDeepWorkMusicButton() {
    final playing = _pomodoro.deepWorkPlaying;
    return Opacity(
      opacity: _deepWorkBusy ? 0.55 : 1,
      child: ScaleButton(
        onPressed: _deepWorkBusy
            ? null
            : () => unawaited(_toggleDeepWorkMusic()),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _Neon.magenta.withValues(alpha: playing ? 0.42 : 0.28),
                _Neon.blue.withValues(alpha: playing ? 0.32 : 0.22),
                _Neon.cyan.withValues(alpha: playing ? 0.28 : 0.18),
              ],
            ),
            border: Border.all(
              color: playing
                  ? _Neon.cyan.withValues(alpha: 0.9)
                  : _Neon.magenta.withValues(alpha: 0.75),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: (playing ? _Neon.cyan : _Neon.magenta)
                    .withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: _Neon.cyan.withValues(alpha: 0.18),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _Neon.magenta.withValues(alpha: 0.22),
                  border: Border.all(
                    color: _Neon.cyan.withValues(alpha: 0.55),
                  ),
                ),
                child: Icon(
                  playing ? Icons.stop_rounded : Icons.headphones_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Deep Work Music',
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      playing
                          ? 'Çalıyor · durdurmak için dokun'
                          : 'Pomodoro bitene kadar döngü',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _Neon.cyan.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                playing
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_filled_rounded,
                size: 22,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullscreen() {
    final accent = _pomodoro.isBreak ? _Neon.pinkSoft : _Neon.cyan;
    return Scaffold(
      backgroundColor: _Neon.base,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _NeonBackdrop(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final h = constraints.maxHeight;
                final timerCenterY = h * 0.5;
                final nameCenterY = timerCenterY / 2;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      top: 10,
                      left: 20,
                      right: 72,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DERS ÇALIŞIYORUM',
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2.4,
                              color: Colors.white.withValues(alpha: 0.94),
                              height: 1.1,
                              shadows: [
                                Shadow(
                                  color: accent.withValues(alpha: 0.4),
                                  blurRadius: 14,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.08),
                                  accent.withValues(alpha: 0.12),
                                ],
                              ),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.45),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.18),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: Text(
                              _todayStudyLabel,
                              style: GoogleFonts.manrope(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.35,
                                color: accent.withValues(alpha: 0.95),
                                height: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: const Icon(
                          Icons.fullscreen_exit_rounded,
                          color: Colors.white70,
                        ),
                        onPressed: () => setState(() => _fullscreen = false),
                      ),
                    ),
                    Positioned(
                      top: nameCenterY - 72,
                      left: 24,
                      right: 24,
                      height: 144,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Quiz filigranı ile aynı: eğik + soluk HEDEF KAMU markası.
                          IgnorePointer(
                            child: Transform.rotate(
                              angle: -math.pi / 4,
                              child: Opacity(
                                opacity: 0.22,
                                child: Image.asset(
                                  BrandConstants.watermarkAsset,
                                  width: 132,
                                  height: 132,
                                  fit: BoxFit.contain,
                                  color: AppTheme.champagneLight,
                                  colorBlendMode: BlendMode.srcIn,
                                  errorBuilder: (_, __, ___) => Image.asset(
                                    BrandConstants.logoAsset,
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.contain,
                                    color: AppTheme.champagneLight,
                                    colorBlendMode: BlendMode.srcIn,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _userDisplayName,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 30,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.4,
                                color: Colors.white,
                                height: 1.05,
                                shadows: [
                                  Shadow(
                                    color: accent.withValues(alpha: 0.55),
                                    blurRadius: 18,
                                  ),
                                  Shadow(
                                    color:
                                        _Neon.magenta.withValues(alpha: 0.25),
                                    blurRadius: 28,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _PremiumChronometerMark(accent: accent),
                          const SizedBox(height: 18),
                          Text(
                            _pomodoro.timeLabel,
                            style: GoogleFonts.manrope(
                              fontSize: 78,
                              fontWeight: FontWeight.w300,
                              color: Colors.white,
                              letterSpacing: 2,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 40,
                      child: Center(
                        child: ScaleButton(
                          onPressed: () => unawaited(
                            _pomodoro.isRunning
                                ? _pomodoro.pauseTimer()
                                : _pomodoro.startTimer(),
                          ),
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: accent.withValues(alpha: 0.9),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.45),
                                  blurRadius: 24,
                                ),
                              ],
                            ),
                            child: Icon(
                              _pomodoro.isRunning
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Premium kronometre işareti — sabit duvar saati değil, odak sayacı.
class _PremiumChronometerMark extends StatelessWidget {
  final Color accent;

  const _PremiumChronometerMark({required this.accent});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 62,
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.32),
              blurRadius: 18,
              spreadRadius: 0.5,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: CustomPaint(
          painter: _PremiumChronometerPainter(accent: accent),
        ),
      ),
    );
  }
}

class _PremiumChronometerPainter extends CustomPainter {
  final Color accent;

  _PremiumChronometerPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final caseCenter = Offset(w / 2, h * 0.58);
    final caseR = w * 0.42;

    // Üst düğme (kronometre crown)
    final stem = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w / 2, caseCenter.dy - caseR - 4),
        width: 5.2,
        height: 9,
      ),
      const Radius.circular(1.5),
    );
    final crown = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w / 2, caseCenter.dy - caseR - 11.5),
        width: 12,
        height: 7,
      ),
      const Radius.circular(2.2),
    );
    final metal = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.92),
          accent.withValues(alpha: 0.85),
          Colors.white.withValues(alpha: 0.55),
        ],
      ).createShader(Rect.fromCircle(center: caseCenter, radius: caseR + 14));
    canvas.drawRRect(stem, metal);
    canvas.drawRRect(crown, metal);

    // Yan kontrol (klasik kronograf)
    final side = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(caseCenter.dx + caseR + 1.5, caseCenter.dy - 6),
        width: 5,
        height: 10,
      ),
      const Radius.circular(1.4),
    );
    canvas.drawRRect(side, metal);

    // Dış kasa
    final caseFill = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0xFF1A2233),
          Color(0xFF0A0E16),
        ],
      ).createShader(Rect.fromCircle(center: caseCenter, radius: caseR));
    canvas.drawCircle(caseCenter, caseR, caseFill);

    final outerRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawCircle(caseCenter, caseR - 0.8, outerRing);

    final glowRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..color = accent.withValues(alpha: 0.28);
    canvas.drawCircle(caseCenter, caseR - 0.8, glowRing);

    // İç bezel
    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = accent.withValues(alpha: 0.45);
    canvas.drawCircle(caseCenter, caseR * 0.78, inner);

    // 60’lık kronometre tick’leri
    final tick = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < 60; i++) {
      final angle = (i / 60) * math.pi * 2 - math.pi / 2;
      final major = i % 5 == 0;
      tick
        ..strokeWidth = major ? 1.7 : 0.9
        ..color = Colors.white.withValues(alpha: major ? 0.88 : 0.35);
      final outer = caseR - 5.5;
      final innerLen = caseR - (major ? 11.5 : 8.2);
      canvas.drawLine(
        caseCenter + Offset(math.cos(angle) * innerLen, math.sin(angle) * innerLen),
        caseCenter + Offset(math.cos(angle) * outer, math.sin(angle) * outer),
        tick,
      );
    }

    // Tek ince saniye kolu — 12’de hazır (kronometre başlangıç pozisyonu)
    const handAngle = -math.pi / 2;
    final hand = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.7
      ..color = accent.withValues(alpha: 0.95);
    canvas.drawLine(
      caseCenter,
      caseCenter +
          Offset(
            math.cos(handAngle) * (caseR * 0.58),
            math.sin(handAngle) * (caseR * 0.58),
          ),
      hand,
    );
    // Kısa karşı ağırlık
    canvas.drawLine(
      caseCenter,
      caseCenter +
          Offset(
            math.cos(handAngle + math.pi) * (caseR * 0.14),
            math.sin(handAngle + math.pi) * (caseR * 0.14),
          ),
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.4
        ..color = Colors.white.withValues(alpha: 0.7),
    );

    canvas.drawCircle(
      caseCenter,
      2.6,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );
    canvas.drawCircle(caseCenter, 1.2, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(covariant _PremiumChronometerPainter oldDelegate) {
    return oldDelegate.accent != accent;
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
                  isBreak ? 'Mola' : 'HEDEF Kamu',
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
