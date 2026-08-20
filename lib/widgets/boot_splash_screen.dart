import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import '../constants/brand_constants.dart';
import '../theme/app_theme.dart';
import 'brand_mark.dart';

/// Boot / atama splash süresi.
const kAssignmentSplashDuration = Duration(milliseconds: 3500);

/// Boot sırasında — koyu zemin, premium kayan çizgi ve atama mesajı.
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
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  Transform.translate(
                    offset: const Offset(0, -40),
                    child: const BrandMark(
                      dark: true,
                      showLogo: false,
                      logoSize: 56,
                      alignment: CrossAxisAlignment.center,
                      line1FontSize: 26,
                      line2FontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _SplashAppIcon(),
                  const SizedBox(height: 52),
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
                  const Spacer(flex: 1),
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

  static const _size = 220.0;
  static const _glow = 220.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _glow,
      height: _glow,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: _glow,
            height: _glow,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.22),
                  Colors.black.withValues(alpha: 0.10),
                  AppTheme.ink.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
          ClipOval(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                const Color(0xFF7D8B94).withValues(alpha: 0.72),
                BlendMode.modulate,
              ),
              child: Opacity(
                opacity: 0.62,
                child: Image.asset(
                  BrandConstants.appIconAsset,
                  width: _size,
                  height: _size,
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
        final travel = _trackWidth + _beamWidth;
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
