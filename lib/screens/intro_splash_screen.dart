import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Açılış: logo + slogan birlikte → logo yukarı → slogan ortada.
/// Kısa animasyon; ana sayfa boot'unu bloklamaz.
class IntroSplashScreen extends StatefulWidget {
  const IntroSplashScreen({super.key});

  @override
  State<IntroSplashScreen> createState() => _IntroSplashScreenState();
}

class _IntroSplashScreenState extends State<IntroSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _master;
  late final AnimationController _breathe;
  late final AnimationController _crossfade;
  late final Animation<double> _lift;

  static const _slogans = [
    'Hedefe giden yol, burada başlar.',
    'Disiplinli çalışma, net sonuç.',
    'Sınav gününe hazır ol.',
  ];

  int _sloganIndex = 0;

  static const _letterStyle = TextStyle(
    fontFamily: 'serif',
    fontWeight: FontWeight.w700,
    height: 0.9,
    letterSpacing: -2.5,
    color: Colors.white,
  );

  static const _odakStyle = TextStyle(
    fontFamily: 'sans-serif',
    color: AppTheme.champagne,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 6.5,
  );

  static const _taglineStyle = TextStyle(
    fontFamily: 'serif',
    color: Color(0xE6FFFFFF),
    fontSize: 19,
    fontWeight: FontWeight.w500,
    height: 1.35,
    letterSpacing: -0.2,
  );

  @override
  void initState() {
    super.initState();

    // İlk kare: logo + slogan ortada (opacity 1)
    // ~0.9s: logo yukarı kayar
    _master = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _crossfade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..addStatusListener(_onCrossfadeStatus);

    _lift = CurvedAnimation(
      parent: _master,
      curve: const Interval(0.15, 1.0, curve: Curves.easeInOutCubic),
    );

    // Kısa tut → lift
    Future<void>.delayed(const Duration(milliseconds: 280), () {
      if (mounted) _master.forward();
    });
    _master.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Future<void>.delayed(const Duration(milliseconds: 900), _startNextSlogan);
      }
    });
  }

  void _startNextSlogan() {
    if (!mounted) return;
    _crossfade.forward(from: 0);
  }

  void _onCrossfadeStatus(AnimationStatus status) {
    if (!mounted) return;
    if (status == AnimationStatus.completed) {
      setState(() {
        _sloganIndex = (_sloganIndex + 1) % _slogans.length;
      });
      _crossfade.reverse();
    } else if (status == AnimationStatus.dismissed) {
      Future<void>.delayed(const Duration(milliseconds: 1600), _startNextSlogan);
    }
  }

  @override
  void dispose() {
    _crossfade.removeStatusListener(_onCrossfadeStatus);
    _master.dispose();
    _breathe.dispose();
    _crossfade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final letterSize = (size.width * 0.16).clamp(44.0, 80.0);
    final liftPx = size.height * 0.22;

    return Scaffold(
      backgroundColor: AppTheme.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _StaticAtmosphere(),
          SafeArea(
            child: AnimatedBuilder(
              animation: Listenable.merge([_master, _breathe, _crossfade]),
              builder: (context, _) {
                final lift = _lift.value;
                final crossT = Curves.easeIn.transform(_crossfade.value);
                final sloganOpacity =
                    (1.0 - crossT) * (0.88 + _breathe.value * 0.12);

                return Stack(
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Transform.translate(
                        offset: Offset(0, -liftPx * lift),
                        child: _BrandBlock(letterSize: letterSize),
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Transform.translate(
                        offset: Offset(
                          0,
                          (1.0 - lift) * (letterSize * 0.55 + 56) - crossT * 8,
                        ),
                        child: Opacity(
                          opacity: sloganOpacity.clamp(0.0, 1.0),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 36),
                            child: Text(
                              _slogans[_sloganIndex],
                              textAlign: TextAlign.center,
                              style: _taglineStyle,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 28,
                      child: Opacity(
                        opacity: 0.35 + lift * 0.65,
                        child: _LoadingPulse(breathe: _breathe),
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

class _BrandBlock extends StatelessWidget {
  final double letterSize;

  const _BrandBlock({required this.letterSize});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final letter in const ['K', 'P', 'S', 'S'])
                Text(
                  letter,
                  style: _IntroSplashScreenState._letterStyle.copyWith(
                    fontSize: letterSize,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: letterSize * 1.6,
          child: const ColoredBox(
            color: AppTheme.champagne,
            child: SizedBox(height: 1.5, width: double.infinity),
          ),
        ),
        const SizedBox(height: 16),
        const Text('ODAK', style: _IntroSplashScreenState._odakStyle),
      ],
    );
  }
}

class _LoadingPulse extends StatelessWidget {
  final Animation<double> breathe;

  const _LoadingPulse({required this.breathe});

  @override
  Widget build(BuildContext context) {
    final w = 28.0 + (breathe.value * 36.0);
    return Center(
      child: Container(
        width: w,
        height: 2,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          gradient: LinearGradient(
            colors: [
              AppTheme.champagne.withValues(alpha: 0.15),
              AppTheme.champagne.withValues(
                alpha: 0.55 + breathe.value * 0.35,
              ),
              AppTheme.champagne.withValues(alpha: 0.15),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaticAtmosphere extends StatelessWidget {
  const _StaticAtmosphere();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Stack(
      children: [
        Positioned(
          top: -size.height * 0.2,
          left: -size.width * 0.3,
          child: SizedBox(
            width: size.width * 1.2,
            height: size.width * 1.2,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x1FC9A86C), Colors.transparent],
                ),
              ),
            ),
          ),
        ),
        const Positioned(
          bottom: -80,
          right: -60,
          child: SizedBox(
            width: 280,
            height: 280,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0xE6162338), Colors.transparent],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
