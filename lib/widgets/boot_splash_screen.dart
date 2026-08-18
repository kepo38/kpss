import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Boot sırasında — koyu zemin, premium kayan çizgi ve atama mesajı.
class BootSplashScreen extends StatefulWidget {
  const BootSplashScreen({super.key});

  @override
  State<BootSplashScreen> createState() => _BootSplashScreenState();
}

class _BootSplashScreenState extends State<BootSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
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
                  center: const Alignment(0, -0.05),
                  radius: 0.85,
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
          Center(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, child) {
                final pulse = 0.88 + 0.12 * math.sin(_ctrl.value * math.pi * 2);
                return Opacity(
                  opacity: pulse.clamp(0.82, 1.0),
                  child: child,
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Ataman Gerçekleşiyor',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      height: 1.1,
                      color: AppTheme.champagneLight,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _PremiumSlidingLine(progress: _ctrl),
                ],
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
