import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'scale_button.dart';

/// Üst bar premium CTA — kompakt pill (maskot yok).
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
        borderRadius: BorderRadius.circular(15),
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
            color: AppTheme.champagne.withValues(alpha: 0.38),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CrownDot(),
            SizedBox(width: 5),
            Text(
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
            SizedBox(width: 2),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 8,
              color: Color(0xE6C9A86C),
            ),
          ],
        ),
      ),
    );
  }
}

class _CrownDot extends StatelessWidget {
  const _CrownDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
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
            color: AppTheme.ink.withValues(alpha: 0.22),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: const Icon(
        Icons.workspace_premium_rounded,
        size: 11,
        color: AppTheme.champagneLight,
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
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
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
              blurRadius: 8,
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
