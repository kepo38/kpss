import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum OsymBadgeVariant { standard, premium }

/// ÖSYM kaynaklı soru damgası — resmi logo + "SORDU !" etiketi.
class OsymBadge extends StatelessWidget {
  static const _assetPath = 'assets/images/osym_sordu_badge.png';
  /// Kaynak PNG: 331×203 px
  static const aspectRatio = 331 / 203;

  final double height;
  final OsymBadgeVariant variant;

  const OsymBadge({
    super.key,
    required this.height,
    this.variant = OsymBadgeVariant.standard,
  });

  @override
  Widget build(BuildContext context) {
    final image = SizedBox(
      height: height,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Image.asset(
          _assetPath,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
        ),
      ),
    );

    final badge = switch (variant) {
      OsymBadgeVariant.premium => _PremiumBadgeFrame(height: height, child: image),
      OsymBadgeVariant.standard => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.32),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: image,
        ),
    };

    return Semantics(
      label: 'ÖSYM sordu',
      child: badge,
    );
  }
}

class _PremiumBadgeFrame extends StatelessWidget {
  final double height;
  final Widget child;

  const _PremiumBadgeFrame({
    required this.height,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.champagneLight,
            AppTheme.neonEdge,
            AppTheme.champagne,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.neonEdge.withValues(alpha: 0.28),
            blurRadius: 14,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.5),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: height * 0.06,
              vertical: height * 0.05,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Soru kökü sarmalayıcı (ÖSYM rozeti quiz üst çizgisinde gösterilir).
class QuestionStemPanel extends StatelessWidget {
  final Widget child;

  const QuestionStemPanel({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => child;
}
