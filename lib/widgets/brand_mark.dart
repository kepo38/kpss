import 'dart:math' as math;

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
  final double? line1FontSize;
  final double? line2FontSize;

  const BrandMark({
    super.key,
    this.dark = false,
    this.logoSize = 28,
    this.showLogo = true,
    this.compact = false,
    this.alignment = CrossAxisAlignment.start,
    this.line1FontSize,
    this.line2FontSize,
  });

  /// Üst bar — ortalanmış iki satır marka.
  const BrandMark.topBar({super.key})
      : dark = false,
        logoSize = 28,
        showLogo = false,
        compact = false,
        alignment = CrossAxisAlignment.center,
        line1FontSize = null,
        line2FontSize = null;

  @override
  Widget build(BuildContext context) {
    final titleColor = dark ? Colors.white : AppTheme.onPage(context);
    final accentColor = dark ? AppTheme.champagneLight : AppTheme.champagne;
    final line1Size = line1FontSize ??
        (compact ? 13.0 : (alignment == CrossAxisAlignment.center ? 22.0 : 15.0));
    final line2Size = line2FontSize ??
        (compact ? 8.0 : (alignment == CrossAxisAlignment.center ? 12.0 : 9.0));
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

/// Quiz üst şeridi — süre | ÖSYM rozeti | soru sayacı; altında seviye + aday.
class QuizHeaderStrip extends StatelessWidget {
  final bool osymSordu;
  final String durationText;
  final bool isCountdown;
  final bool urgent;
  final String? questionLabel;
  /// Yeşil başarı oranı — eski Soru X/Y yerinde (ör. `Başarı: %49`).
  final String? successLabel;
  final String? difficultyLabel;
  final String? attemptLabel;
  final Widget? leading;
  final bool showTimer;
  final bool difficultyOnRight;

  const QuizHeaderStrip({
    super.key,
    this.osymSordu = false,
    required this.durationText,
    required this.isCountdown,
    required this.urgent,
    this.questionLabel,
    this.successLabel,
    this.difficultyLabel,
    this.attemptLabel,
    this.leading,
    this.showTimer = true,
    this.difficultyOnRight = false,
  });

  static const _lineHeight = 2.5;

  Widget _timerRow({
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

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;
    final badgeHeight = compact ? 44.0 : 52.0;
    final timeColor = urgent ? Colors.redAccent : Colors.white;
    final iconColor = urgent ? Colors.redAccent : AppTheme.champagne;

    final rightMeta = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (successLabel != null)
          Container(
            constraints: const BoxConstraints(maxWidth: 140),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF34D399).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color(0xFF34D399).withValues(alpha: 0.55),
              ),
            ),
            child: Text(
              successLabel!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.1,
                color: Color(0xFF6EE7B7),
              ),
            ),
          )
        else if (questionLabel != null)
          Text(
            questionLabel!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
        if (difficultyOnRight && difficultyLabel != null) ...[
          if (successLabel != null || questionLabel != null)
            const SizedBox(height: 6),
          _DifficultyBadge(label: difficultyLabel!),
        ],
        if (attemptLabel != null) ...[
          const SizedBox(height: 6),
          _AttemptChip(label: attemptLabel!),
        ],
      ],
    );

    final leftMeta = leading != null
        ? leading!
        : (showTimer
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _timerRow(
                    isCountdown: isCountdown,
                    iconColor: iconColor,
                    durationText: durationText,
                    timeColor: timeColor,
                  ),
                  if (!difficultyOnRight && difficultyLabel != null) ...[
                    const SizedBox(height: 6),
                    _DifficultyBadge(label: difficultyLabel!),
                  ],
                ],
              )
            : const SizedBox.shrink());

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SizedBox(
            height: math.max(badgeHeight, 58),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: leftMeta,
                      ),
                    ),
                    SizedBox(
                      width: osymSordu
                          ? badgeHeight * OsymBadge.aspectRatio + 8
                          : 0,
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: rightMeta,
                      ),
                    ),
                  ],
                ),
                // AppBar «Soru X/Y» ile aynı dikey eksen (ekran ortası).
                if (osymSordu)
                  OsymBadge(
                    height: badgeHeight,
                    variant: OsymBadgeVariant.premium,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const _AccentLine(height: _lineHeight),
      ],
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  final String label;

  const _DifficultyBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      'Kolay' => const Color(0xFF34D399),
      'Zor' => const Color(0xFFF87171),
      _ => AppTheme.champagne,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        'Seviye: $label',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.35,
        ),
      ),
    );
  }
}

class _AttemptChip extends StatelessWidget {
  final String label;

  const _AttemptChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 168),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.10),
            AppTheme.champagne.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppTheme.champagne.withValues(alpha: 0.34),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.15,
          color: Colors.white.withValues(alpha: 0.92),
        ),
      ),
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
