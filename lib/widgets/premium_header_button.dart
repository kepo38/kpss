import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'scale_button.dart';

/// Hero / üst bar premium CTA — sıcak altın pill, krem zeminle uyumlu.
class PremiumHeaderButton extends StatelessWidget {
  final bool isPremium;
  final VoidCallback? onTap;

  const PremiumHeaderButton({
    super.key,
    required this.isPremium,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isPremium) {
      return _ActiveBadge(onTap: onTap);
    }
    return ScaleButton(
      onPressed: onTap,
      child: const _ProPill(),
    );
  }
}

class _ProPill extends StatelessWidget {
  const _ProPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF8EE),
            Color(0xFFF5E6C8),
            Color(0xFFE8CF98),
          ],
          stops: [0.0, 0.45, 1.0],
        ),
        border: Border.all(
          color: const Color(0xFFD4AF6A),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.champagne.withValues(alpha: 0.4),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.85),
            blurRadius: 0,
            spreadRadius: 0.5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -12,
            child: IgnorePointer(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.55),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 6, 10, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF2A3548),
                        AppTheme.ink,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.ink.withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    size: 12,
                    color: AppTheme.champagneLight,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Pro Üyelik',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    height: 1,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 9,
                  color: AppTheme.champagne.withValues(alpha: 0.9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  final VoidCallback? onTap;

  const _ActiveBadge({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFF8EE),
              Color(0xFFF0E0BC),
            ],
          ),
          border: Border.all(
            color: const Color(0xFFD4AF6A),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.champagne.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified_rounded,
              size: 13,
              color: Color(0xFFB8924A),
            ),
            SizedBox(width: 4),
            Text(
              'Premium',
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
                color: AppTheme.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
