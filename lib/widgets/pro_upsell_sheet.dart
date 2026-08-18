import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../screens/premium/premium_paywall_screen.dart';
import '../theme/app_theme.dart';
import 'scale_button.dart';

/// Kilitli Pro özellik — altın paywall bottom sheet.
class ProUpsellSheet {
  ProUpsellSheet._();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => const _ProUpsellBody(),
    );
  }
}

class _ProUpsellBody extends StatefulWidget {
  const _ProUpsellBody();

  @override
  State<_ProUpsellBody> createState() => _ProUpsellBodyState();
}

class _ProUpsellBodyState extends State<_ProUpsellBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine;

  @override
  void initState() {
    super.initState();
    _shine = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  Future<void> _openPaywall() async {
    final nav = Navigator.of(context);
    nav.pop();
    await nav.push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const PremiumPaywallScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shine,
      builder: (context, child) {
        final t = _shine.value;
        final pulse = 0.55 + 0.45 * math.sin(t * math.pi * 2);
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.champagne.withValues(alpha: 0.22 + 0.2 * pulse),
                  blurRadius: 28 + 10 * pulse,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: CustomPaint(
                painter: _GoldShimmerBorderPainter(progress: t),
                child: Padding(
                  padding: const EdgeInsets.all(1.6),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
      child: Material(
        color: const Color(0xFF16110A),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2A2216),
                Color(0xFF16110A),
                Color(0xFF1C160E),
              ],
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      color: AppTheme.champagne.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text('👑', style: TextStyle(fontSize: 36, height: 1)),
                  const SizedBox(height: 10),
                  const Text(
                    'Pro ile benzer sorular',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF6E7C3),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Yanlış yaptığın soruların benzerlerini karşına getirelim. '
                    'Sınav öncesi eksik konu bırakma!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.45,
                      color: AppTheme.champagneLight.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ScaleButton(
                    onPressed: _openPaywall,
                    child: Container(
                      width: double.infinity,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFF8E7C0),
                            Color(0xFFE2C998),
                            Color(0xFFC9A86C),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.champagne.withValues(alpha: 0.4),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Pro Üyeliğe Geç',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                          color: Color(0xFF1A140C),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Şimdilik geç',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoldShimmerBorderPainter extends CustomPainter {
  final double progress;

  _GoldShimmerBorderPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(22));
    final shader = SweepGradient(
      startAngle: 0,
      endAngle: math.pi * 2,
      transform: GradientRotation(progress * math.pi * 2),
      colors: const [
        Color(0xFFF8E7C0),
        Color(0xFF8A6B32),
        Color(0xFFE2C998),
        Color(0xFFC9A86C),
        Color(0xFFF8E7C0),
      ],
    ).createShader(rect);
    final paint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawRRect(rrect.deflate(0.9), paint);
  }

  @override
  bool shouldRepaint(_GoldShimmerBorderPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// BENZER yanındaki parıltılı 👑 PRO rozeti.
class ProCrownBadge extends StatefulWidget {
  final VoidCallback onTap;

  const ProCrownBadge({super.key, required this.onTap});

  @override
  State<ProCrownBadge> createState() => _ProCrownBadgeState();
}

class _ProCrownBadgeState extends State<ProCrownBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          final pulse = 0.55 + 0.45 * math.sin(_ctrl.value * math.pi * 2);
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.champagne.withValues(alpha: 0.28 + 0.32 * pulse),
                  blurRadius: 6 + 4 * pulse,
                ),
              ],
            ),
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFF6E4),
                Color(0xFFE8CF98),
                Color(0xFFC9A86C),
              ],
            ),
            border: Border.all(color: const Color(0xFFD4AF6A), width: 0.6),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('👑', style: TextStyle(fontSize: 9, height: 1)),
              SizedBox(width: 3),
              Text(
                'PRO',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: Color(0xFF3A2A10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
