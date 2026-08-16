import 'package:flutter/material.dart';

import '../constants/brand_constants.dart';
import '../theme/app_theme.dart';
import 'osym_badge.dart';
/// Ortak marka işareti — cream ve koyu quiz yüzeylerinde aynı dil.
class BrandMark extends StatelessWidget {
  final bool dark;
  final double logoSize;
  final bool showLogo;
  final bool compact;
  final CrossAxisAlignment alignment;

  const BrandMark({
    super.key,
    this.dark = false,
    this.logoSize = 28,
    this.showLogo = true,
    this.compact = false,
    this.alignment = CrossAxisAlignment.start,
  });

  /// Üst bar — ortalanmış iki satır marka.
  const BrandMark.topBar({super.key})
      : dark = false,
        logoSize = 28,
        showLogo = false,
        compact = false,
        alignment = CrossAxisAlignment.center;

  @override
  Widget build(BuildContext context) {
    final titleColor = dark ? Colors.white : AppTheme.onPage(context);
    final accentColor = dark ? AppTheme.champagneLight : AppTheme.champagne;
    final line1Size = compact ? 13.0 : (alignment == CrossAxisAlignment.center ? 22.0 : 15.0);
    final line2Size = compact ? 8.0 : (alignment == CrossAxisAlignment.center ? 12.0 : 9.0);
    final line2Spacing = alignment == CrossAxisAlignment.center ? 4.5 : (compact ? 2.8 : 3.2);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLogo) ...[
          Image.asset(
            BrandConstants.logoAsset,
            width: logoSize,
            height: logoSize,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => Icon(
              Icons.track_changes_rounded,
              size: logoSize * 0.85,
              color: accentColor,
            ),
          ),
          SizedBox(width: compact ? 6 : 8),
        ],
        Column(
          crossAxisAlignment: alignment,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              BrandConstants.brandLine1,
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: line1Size,
                fontWeight: FontWeight.w700,
                height: 1,
                letterSpacing: alignment == CrossAxisAlignment.center ? -0.5 : -0.3,
                color: titleColor,
              ),
            ),
            SizedBox(height: alignment == CrossAxisAlignment.center ? 2 : 1),
            Text(
              BrandConstants.brandLine2,
              style: TextStyle(
                fontFamily: 'sans-serif',
                fontSize: line2Size,
                fontWeight: FontWeight.w900,
                letterSpacing: line2Spacing,
                color: accentColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Quiz üst şeridi — süre/soru sayacı ve ÖSYM rozeti çizginin üstünde,
/// gradient çizgi en altta.
class QuizHeaderStrip extends StatelessWidget {
  final bool osymSordu;
  final String durationText;
  final bool isCountdown;
  final bool urgent;
  final String questionLabel;

  const QuizHeaderStrip({
    super.key,
    this.osymSordu = false,
    required this.durationText,
    required this.isCountdown,
    required this.urgent,
    required this.questionLabel,
  });

  static const _lineHeight = 2.5;

  Widget _metaLeft({
    required bool isCountdown,
    required Color iconColor,
    required String durationText,
    required Color timeColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isCountdown ? Icons.timer_outlined : Icons.timelapse,
          size: 16,
          color: iconColor,
        ),
        const SizedBox(width: 6),
        Text(
          durationText,
          style: TextStyle(
            fontFeatures: const [FontFeature.tabularFigures()],
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: timeColor,
          ),
        ),
      ],
    );
  }

  Widget _metaRight(String questionLabel) {
    return Text(
      questionLabel,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.white.withValues(alpha: 0.88),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;
    final badgeHeight = compact ? 52.0 : 60.0;

    final timeColor = urgent ? Colors.redAccent : Colors.white;
    final iconColor = urgent ? Colors.redAccent : AppTheme.champagne;

    if (osymSordu) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            child: SizedBox(
              height: badgeHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _metaLeft(
                          isCountdown: isCountdown,
                          iconColor: iconColor,
                          durationText: durationText,
                          timeColor: timeColor,
                        ),
                      ),
                    ),
                  ),
                  OsymBadge(
                    height: badgeHeight,
                    variant: OsymBadgeVariant.premium,
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _metaRight(questionLabel),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          const _AccentLine(height: _lineHeight),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _metaLeft(
                isCountdown: isCountdown,
                iconColor: iconColor,
                durationText: durationText,
                timeColor: timeColor,
              ),
              const Spacer(),
              _metaRight(questionLabel),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const _AccentLine(height: _lineHeight),
      ],
    );
  }
}

/// Geriye uyumluluk.
class QuizBrandBridge extends StatelessWidget {
  final bool osymSordu;

  const QuizBrandBridge({super.key, this.osymSordu = false});

  @override
  Widget build(BuildContext context) {
    return QuizHeaderStrip(
      osymSordu: osymSordu,
      durationText: '00:00',
      isCountdown: false,
      urgent: false,
      questionLabel: '',
    );
  }
}

class _AccentLine extends StatelessWidget {
  final double height;

  const _AccentLine({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.champagne,
            AppTheme.neonEdge,
            AppTheme.champagneLight,
          ],
        ),
      ),
    );
  }
}
