import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_preferences.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Her gün / hesap kapsamında girilen **ilk** testte ortada yumuşak zoom ipucu.
///
/// Misafir ile Google hesabı ayrı sayılır — misafirken görüp sonra giriş
/// yapan kullanıcı ilk testinde ipucunu yeniden görür.
class QuizZoomDailyHint extends StatefulWidget {
  final bool enabled;

  const QuizZoomDailyHint({super.key, this.enabled = true});

  static const _prefsPrefix = 'quiz_zoom_hint_day_v2_';

  @override
  State<QuizZoomDailyHint> createState() => _QuizZoomDailyHintState();
}

class _QuizZoomDailyHintState extends State<QuizZoomDailyHint> {
  bool _visible = false;
  Timer? _showTimer;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) unawaited(_maybeShow());
  }

  @override
  void didUpdateWidget(covariant QuizZoomDailyHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) {
      unawaited(_maybeShow());
    }
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  String _todayKey() {
    final n = DateTime.now();
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return '${n.year}-$m-$d';
  }

  /// Misafir / Google (veya kalıcı hesap) ayrı slot.
  String _scopeId() {
    final auth = AuthService.instance;
    if (auth.hasPermanentAccount) {
      final id = auth.user?.id.trim();
      if (id != null && id.isNotEmpty) return 'u_$id';
      return 'signed_in';
    }
    return 'guest';
  }

  Future<void> _maybeShow() async {
    if (!widget.enabled) return;
    final prefs = await AppPreferences.instance;
    final today = _todayKey();
    final key = '${QuizZoomDailyHint._prefsPrefix}${_scopeId()}';
    if (prefs.getString(key) == today) return;
    if (!mounted) return;

    // Sayfa otursun, sonra ortada yumuşak belirsın.
    _showTimer?.cancel();
    _showTimer = Timer(const Duration(milliseconds: 900), () async {
      if (!mounted) return;
      await prefs.setString(key, today);
      if (!mounted) return;
      setState(() => _visible = true);
      _hideTimer?.cancel();
      _hideTimer = Timer(const Duration(milliseconds: 4200), () {
        if (mounted) setState(() => _visible = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        child: AnimatedScale(
          scale: _visible ? 1 : 0.92,
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
          child: Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF152238).withValues(alpha: 0.97),
                        AppTheme.ink.withValues(alpha: 0.94),
                      ],
                    ),
                    border: Border.all(
                      color: AppTheme.champagne.withValues(alpha: 0.65),
                      width: 1.1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: AppTheme.champagne.withValues(alpha: 0.14),
                        blurRadius: 16,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.champagne.withValues(alpha: 0.16),
                            border: Border.all(
                              color:
                                  AppTheme.champagne.withValues(alpha: 0.55),
                            ),
                          ),
                          child: const Icon(
                            Icons.touch_app_rounded,
                            size: 20,
                            color: AppTheme.champagneLight,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text.rich(
                          TextSpan(
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                              color: Colors.white.withValues(alpha: 0.92),
                            ),
                            children: const [
                              TextSpan(text: 'Çift dokunarak '),
                              TextSpan(
                                text: 'SORU',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.champagneLight,
                                ),
                              ),
                              TextSpan(text: ' ve '),
                              TextSpan(
                                text: 'ÇÖZÜMLERİ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.champagneLight,
                                ),
                              ),
                              TextSpan(text: ' yakınlaştır'),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
