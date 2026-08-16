import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/pomodoro_session_model.dart';
import '../../services/gamification_service.dart';
import '../../services/pomodoro_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/scale_button.dart';

class FocusModeScreen extends StatefulWidget {
  const FocusModeScreen({super.key});

  @override
  State<FocusModeScreen> createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends State<FocusModeScreen> {
  final _pomodoro = PomodoroService.instance;
  PomodoroPreset _preset = PomodoroPreset.kisa25;
  int _customMinutes = 30;
  int _remainingSeconds = 25 * 60;
  Timer? _timer;
  bool _isRunning = false;
  bool _isBreak = false;
  bool _fullscreen = false;
  bool _ambientBusy = false;

  int get _totalSeconds {
    if (_preset == PomodoroPreset.ozel) return _customMinutes * 60;
    return _preset.dakika * 60;
  }

  void _startTimer() {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      if (_remainingSeconds == _totalSeconds || _remainingSeconds == 0) {
        _remainingSeconds = _totalSeconds;
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainingSeconds <= 0) {
        _onSessionComplete();
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isBreak = false;
      _remainingSeconds = _totalSeconds;
    });
  }

  void _onSessionComplete() {
    _timer?.cancel();
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
    setState(() {
      _isRunning = false;
      _isBreak = !_isBreak;
      _remainingSeconds = _isBreak ? 5 * 60 : _totalSeconds;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isBreak ? 'Mola zamanı!' : 'Odak seansı tamamlandı!'),
        ),
      );
    }
  }

  String get _timeLabel {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_pomodoro.stopAmbient());
    super.dispose();
  }

  Future<void> _selectAmbient(AmbientSound sound) async {
    if (_ambientBusy) return;
    setState(() => _ambientBusy = true);
    await _pomodoro.setSelectedSound(sound);
    if (mounted) {
      setState(() => _ambientBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_fullscreen) return _buildFullscreen();

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Odak Modu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.fullscreen),
            onPressed: () => setState(() => _fullscreen = true),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _TimerDisplay(time: _timeLabel, isBreak: _isBreak),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              children: PomodoroPreset.values.map((p) {
                return ChoiceChip(
                  label: Text(p == PomodoroPreset.ozel ? '$_customMinutes dk' : p.label),
                  selected: _preset == p,
                  onSelected: (_) {
                    setState(() {
                      _preset = p;
                      _remainingSeconds = _totalSeconds;
                    });
                  },
                );
              }).toList(),
            ),
            if (_preset == PomodoroPreset.ozel) ...[
              const SizedBox(height: 12),
              Slider(
                value: _customMinutes.toDouble(),
                min: 10,
                max: 120,
                divisions: 22,
                label: '$_customMinutes dk',
                onChanged: (v) => setState(() {
                  _customMinutes = v.round();
                  _remainingSeconds = _customMinutes * 60;
                }),
              ),
            ],
            const SizedBox(height: 24),
            Text('Ortam Sesi', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              'Odak için yumuşak döngüsel sesler',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.lightAccent.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AmbientSound.values.map((s) {
                final selected = _pomodoro.selectedSound == s;
                return FilterChip(
                  avatar: Icon(
                    selected && _pomodoro.ambientPlaying && s != AmbientSound.sessiz
                        ? Icons.volume_up_outlined
                        : s.icon,
                    size: 18,
                  ),
                  label: Text(s.label),
                  selected: selected,
                  onSelected: _ambientBusy
                      ? null
                      : (on) {
                          unawaited(_selectAmbient(on ? s : AmbientSound.sessiz));
                        },
                );
              }).toList(),
            ),
            if (_pomodoro.selectedSound != AmbientSound.sessiz) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.volume_down, size: 18, color: AppTheme.lightAccent.withValues(alpha: 0.7)),
                  Expanded(
                    child: Slider(
                      value: _pomodoro.ambientVolume,
                      min: 0.15,
                      max: 0.85,
                      divisions: 14,
                      label: '${(_pomodoro.ambientVolume * 100).round()}%',
                      onChanged: _ambientBusy
                          ? null
                          : (v) {
                              setState(() {});
                              unawaited(_pomodoro.setAmbientVolume(v));
                            },
                    ),
                  ),
                  Icon(Icons.volume_up, size: 18, color: AppTheme.lightAccent.withValues(alpha: 0.7)),
                ],
              ),
            ],
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleButton(
                  onPressed: _resetTimer,
                  child: OutlinedButton(onPressed: _resetTimer, child: const Text('Sıfırla')),
                ),
                const SizedBox(width: 16),
                ScaleButton(
                  onPressed: _isRunning ? _pauseTimer : _startTimer,
                  child: FilledButton.icon(
                    onPressed: _isRunning ? _pauseTimer : _startTimer,
                    icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                    label: Text(_isRunning ? 'Duraklat' : 'Başlat'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Bugün: ${_pomodoro.bugunToplamDakika} dk odak',
              style: GoogleFonts.inter(color: AppTheme.lightAccent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullscreen() {
    return Scaffold(
      backgroundColor: AppTheme.lightPrimary,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isBreak ? 'MOLA' : 'ODAK',
              style: GoogleFonts.inter(
                color: AppTheme.lightAccent,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _timeLabel,
              style: GoogleFonts.inter(
                fontSize: 72,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                  onPressed: () => setState(() => _fullscreen = false),
                ),
                const SizedBox(width: 24),
                IconButton(
                  icon: Icon(
                    _isRunning ? Icons.pause_circle : Icons.play_circle,
                    color: Colors.white,
                    size: 56,
                  ),
                  onPressed: _isRunning ? _pauseTimer : _startTimer,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimerDisplay extends StatelessWidget {
  final String time;
  final bool isBreak;

  const _TimerDisplay({required this.time, required this.isBreak});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Text(
              isBreak ? 'Mola' : 'Odaklan',
              style: GoogleFonts.inter(
                color: AppTheme.lightAccent,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              time,
              style: GoogleFonts.inter(
                fontSize: 56,
                fontWeight: FontWeight.bold,
                color: AppTheme.lightPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
