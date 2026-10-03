import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Şık seçilince aktif olan «Çözümü Gör» — dikkat çeken kısa pulse (2 tur).
///
/// Animasyon iki durumda başlar:
///  * [enabled] false → true olduğunda,
///  * [pulseToken] değiştiğinde (ör. şık seçildiğinde üst widget artırır).
///
/// Kontrolcü `AnimationBehavior.preserve` kullanır: telefonda «animasyonları
/// kaldır» / pil tasarrufu / geliştirici «animator duration scale = off» gibi
/// ayarlar açıkken varsayılan (`normal`) davranış süreyi ~20 kat kısaltır ve
/// pulse hiç görünmez. Bu ipucu küçük ve tek seferlik olduğu için süresi
/// korunur.
class SolutionRevealButton extends StatefulWidget {
  const SolutionRevealButton({
    super.key,
    required this.enabled,
    required this.showingSolution,
    required this.style,
    required this.onPressed,
    this.pulseToken = 0,
  });

  final bool enabled;
  final bool showingSolution;
  final ButtonStyle style;
  final VoidCallback? onPressed;

  /// Değeri değişince (ve buton aktifse) pulse yeniden oynar.
  final int pulseToken;

  @override
  State<SolutionRevealButton> createState() => _SolutionRevealButtonState();
}

class _SolutionRevealButtonState extends State<SolutionRevealButton>
    with SingleTickerProviderStateMixin {
  static const _pulseDuration = Duration(milliseconds: 1200);
  static const _pulseCount = 2;
  static const _radius = 28.0;

  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _glow;
  late final Animation<double> _flash;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: _pulseDuration,
      animationBehavior: AnimationBehavior.preserve,
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.1)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.1, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 60,
      ),
    ]).animate(_ctrl);
    _glow = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 65,
      ),
    ]).animate(_ctrl);
    _flash = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.5)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.5, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 65,
      ),
    ]).animate(_ctrl);
  }

  int _runId = 0;

  Future<void> _play() async {
    if (!mounted || !widget.enabled || widget.showingSolution) return;
    final run = ++_runId;
    for (var i = 0; i < _pulseCount; i++) {
      if (!mounted || run != _runId) return;
      try {
        await _ctrl.forward(from: 0).orCancel;
      } on TickerCanceled {
        return;
      }
    }
  }

  @override
  void didUpdateWidget(covariant SolutionRevealButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    final becameEnabled = !oldWidget.enabled && widget.enabled;
    final tokenChanged = oldWidget.pulseToken != widget.pulseToken;
    if ((becameEnabled || tokenChanged) &&
        widget.enabled &&
        !widget.showingSolution) {
      _play();
    }
    // Çözüm açıldıysa veya buton pasifleştiyse animasyon dursun.
    if (!widget.enabled || widget.showingSolution) {
      if (_ctrl.isAnimating || _ctrl.value > 0) {
        _runId++;
        _ctrl.stop();
        _ctrl.value = 0;
      }
    }
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
        final g = _glow.value;
        final flash = _flash.value;
        return Transform.scale(
          scale: _scale.value,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_radius),
              boxShadow: g <= 0.02
                  ? null
                  : [
                      BoxShadow(
                        color: AppTheme.champagne.withValues(alpha: 0.6 * g),
                        blurRadius: 24 * g,
                        spreadRadius: 1.5 * g,
                      ),
                      BoxShadow(
                        color:
                            AppTheme.champagneLight.withValues(alpha: 0.3 * g),
                        blurRadius: 8 * g,
                      ),
                    ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                child!,
                if (flash > 0.01)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(_radius),
                          border: Border.all(
                            color: AppTheme.champagneLight
                                .withValues(alpha: flash),
                            width: 1.8,
                          ),
                          color:
                              AppTheme.champagne.withValues(alpha: flash * 0.4),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
      child: OutlinedButton(
        onPressed: widget.onPressed,
        style: widget.style,
        child: Text(
          widget.showingSolution ? 'Çözümü Gizle' : 'Çözümü Gör',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
