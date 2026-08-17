import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'brand_mark.dart';
import 'exam_focus_panel.dart';
import 'premium_header_button.dart';

/// Ana sayfa üst hero: marka + premium + sınav odak paneli.
class HomeHeroSection extends StatelessWidget {
  final double topPad;
  final ValueNotifier<bool> isPremium;
  final Animation<double> fadeEarly;
  final Animation<double> fadeType;
  final VoidCallback onPremiumTap;

  const HomeHeroSection({
    super.key,
    required this.topPad,
    required this.isPremium,
    required this.fadeEarly,
    required this.fadeType,
    required this.onPremiumTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFF9F5EE),
                  Color(0xFFF3F0EA),
                  Color(0xFFEEE8DF),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          top: -56,
          right: -40,
          child: SizedBox(
            width: 200,
            height: 200,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.champagne.withValues(alpha: 0.18),
                    AppTheme.champagne.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 80,
          left: -60,
          child: SizedBox(
            width: 180,
            height: 180,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.neonGold.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            height: 1.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppTheme.champagne.withValues(alpha: 0.45),
                  AppTheme.champagne.withValues(alpha: 0.65),
                  AppTheme.champagne.withValues(alpha: 0.35),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, topPad + 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: fadeEarly,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: BrandMark.topBar(),
                      ),
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: isPremium,
                      builder: (context, premium, _) {
                        return PremiumHeaderButton(
                          isPremium: premium,
                          onTap: premium ? null : onPremiumTap,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              FadeTransition(
                opacity: fadeType,
                child: const ExamFocusPanel(light: true),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
