import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/special_tests_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/countdown_widget.dart';
import 'osym_badge.dart';
import 'scale_button.dart';

/// Dersler sekmesi en altı — ortalanmış ışıklı «ÖZEL TESTLER» girişi.
class SpecialTestsEntry extends StatelessWidget {
  final KpssType kpssType;

  const SpecialTestsEntry({super.key, required this.kpssType});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    const gridGutter = 16.0;
    const crossSpacing = 8.0;
    final tileWidth = (width - gridGutter * 2 - crossSpacing) / 2;
    final buttonWidth = (tileWidth * 1.62).clamp(168.0, width - 48);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 4),
      child: Align(
        alignment: Alignment.center,
        child: SizedBox(
          width: buttonWidth,
          child: ScaleButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SpecialTestsScreen(kpssType: kpssType),
                ),
              );
            },
            child: const _SpecialTestsGlowButton(),
          ),
        ),
      ),
    );
  }
}

class _SpecialTestsGlowButton extends StatefulWidget {
  const _SpecialTestsGlowButton();

  @override
  State<_SpecialTestsGlowButton> createState() => _SpecialTestsGlowButtonState();
}

class _SpecialTestsGlowButtonState extends State<_SpecialTestsGlowButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const radius = 16.0;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value;
        final pulse = 0.55 + 0.45 * math.sin(t * math.pi * 2);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: AppTheme.neonEdge.withValues(alpha: 0.18 + 0.22 * pulse),
                blurRadius: 12 + 12 * pulse,
                spreadRadius: 0.5 * pulse,
              ),
              BoxShadow(
                color: AppTheme.champagne.withValues(alpha: 0.14 + 0.18 * pulse),
                blurRadius: 18 + 10 * pulse,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: CustomPaint(
            painter: PremiumShimmerBorderPainter(
              progress: t,
              borderRadius: radius,
              strokeWidth: 2,
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: child,
            ),
          ),
        );
      },
      child: const _SpecialTestsPremiumFace(),
    );
  }
}

class _SpecialTestsPremiumFace extends StatelessWidget {
  const _SpecialTestsPremiumFace();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFF4D8),
            Color(0xFFE4C078),
            Color(0xFFB8893A),
          ],
          stops: [0.0, 0.42, 1.0],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(2, 2, 2, 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFFBEA),
              Color(0xFFF0D392),
              Color(0xFFC9A24A),
            ],
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        alignment: Alignment.center,
        child: Text(
          'ÖZEL TESTLER',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.playfairDisplay(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
            height: 1.15,
            color: AppTheme.ink,
          ),
        ),
      ),
    );
  }
}
