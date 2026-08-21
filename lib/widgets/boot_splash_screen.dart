import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import '../constants/brand_constants.dart';
import '../theme/app_theme.dart';
import 'brand_mark.dart';

/// Boot / atama splash süresi.
const kAssignmentSplashDuration = Duration(milliseconds: 3500);

/// Boot sırasında - koyu zemin, premium kayan çizgi ve atama mesajı.
class BootSplashScreen extends StatefulWidget {
  final VoidCallback? onComplete;

  const BootSplashScreen({super.key, this.onComplete});

  @override
  State<BootSplashScreen> createState() => _BootSplashScreenState();
}

class _BootSplashScreenState extends State<BootSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    if (widget.onComplete != null) {
      unawaited(_holdAndComplete());
    }
  }

  Future<void> _holdAndComplete() async {
    await Future<void>.delayed(kAssignmentSplashDuration);
    if (!mounted) return;
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.55,
                  colors: [
                    AppTheme.champagne.withValues(alpha: 0.12),
                    AppTheme.neonEdge.withValues(alpha: 0.04),
                    AppTheme.ink,
                  ],
                  stops: const [0, 0.42, 1],
                ),
              ),
            ),
          ),
          // 657 dairesi — tam ekranın matematiksel ortası (SafeArea dışı)
          const Center(child: _SplashAppIcon()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const Align(
                    alignment: Alignment(0, -0.72),
                    child: BrandMark(
                      dark: true,
                      showLogo: false,
                      logoSize: 56,
                      alignment: CrossAxisAlignment.center,
                      line1FontSize: 26,
                      line2FontSize: 14,
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Ataman Gerçekleşiyor',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              height: 1.1,
                              color: AppTheme.champagneLight,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _PremiumSlidingLine(progress: _ctrl),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashAppIcon extends StatelessWidget {
  const _SplashAppIcon();

  /// Siyah gölge daire (dış).
  static const _disc = 220.0;

  /// app_icon bunun içinde - biraz küçük ki siyah disk kenarı görünsün.
  static const _icon = 188.0;

  /// Düşük parlaklıkta bile okunur parlak altın.
  static const _brightGold = Color(0xFFFFE08A);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _disc,
      height: _disc,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: _disc,
            height: _disc,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF05070C),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.65),
                  blurRadius: 36,
                  spreadRadius: 6,
                ),
                BoxShadow(
                  color: _brightGold.withValues(alpha: 0.18),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          ClipOval(
            child: SizedBox(
              width: _icon,
              height: _icon,
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  _brightGold,
                  BlendMode.modulate,
                ),
                child: Image.asset(
                  BrandConstants.appIconAsset,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumSlidingLine extends StatelessWidget {
  final Animation<double> progress;

  const _PremiumSlidingLine({required this.progress});

  static const _trackWidth = 228.0;
  static const _beamWidth = 72.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(progress.value);
        const travel = _trackWidth + _beamWidth;
        final left = -_beamWidth + travel * t;

        return SizedBox(
          width: _trackWidth,
          height: 14,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 2.5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: AppTheme.champagne.withValues(alpha: 0.18),
                  border: Border.all(
                    color: AppTheme.champagne.withValues(alpha: 0.22),
                  ),
                ),
              ),
              Positioned(
                left: left,
                top: 5.75,
                child: Container(
                  width: _beamWidth,
                  height: 2.5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.transparent,
                        Color(0x66FFEEC8),
                        Color(0xFFFFEDB0),
                        AppTheme.champagneLight,
                        AppTheme.champagne,
                        Color(0xFFFFEDB0),
                        Color(0x66FFEEC8),
                        Colors.transparent,
                      ],
                      stops: [0, 0.12, 0.28, 0.42, 0.58, 0.72, 0.88, 1],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.neonGold.withValues(alpha: 0.55),
                        blurRadius: 10,
                        spreadRadius: -1,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: left + _beamWidth * 0.42,
                top: 2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.champagneLight,
                        AppTheme.champagne.withValues(alpha: 0.2),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.champagne.withValues(alpha: 0.65),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
