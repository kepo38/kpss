import 'package:flutter/material.dart';

import '../constants/brand_constants.dart';
import '../theme/app_theme.dart';
import 'premium_header_button.dart';
import 'scale_button.dart';

/// Stüdyo hub hero — marka + kısa vaat + Pro CTA.
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
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -80,
          right: -50,
          child: IgnorePointer(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.champagne.withValues(alpha: 0.22),
                    AppTheme.champagne.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.42, 1],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 120,
          left: -70,
          child: IgnorePointer(
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF2A3A58).withValues(alpha: 0.55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(8, topPad + 2, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeTransition(
                opacity: fadeEarly,
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new,
                        size: 20,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      tooltip: 'Geri',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const Spacer(),
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
              const SizedBox(height: 18),
              FadeTransition(
                opacity: fadeEarly,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        BrandConstants.appName.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3.2,
                          color: AppTheme.champagne.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Stüdyo',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 40,
                          fontWeight: FontWeight.w700,
                          height: 1.02,
                          letterSpacing: -1.2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Çalışma araçları ve Premium özellikler tek yerde.',
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.4,
                          color: Colors.white.withValues(alpha: 0.58),
                        ),
                      ),
                      const SizedBox(height: 18),
                      ValueListenableBuilder<bool>(
                        valueListenable: isPremium,
                        builder: (context, premium, _) {
                          if (premium) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppTheme.champagne.withValues(alpha: 0.4),
                                ),
                                color: AppTheme.champagne.withValues(alpha: 0.1),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified_rounded,
                                    size: 16,
                                    color: AppTheme.champagneLight,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Premium aktif',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.champagneLight,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return ScaleButton(
                            onPressed: onPremiumTap,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFE8D5A8),
                                    AppTheme.champagne,
                                    Color(0xFFA88445),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.champagne.withValues(
                                      alpha: 0.35,
                                    ),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.workspace_premium_rounded,
                                    size: 18,
                                    color: AppTheme.ink,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Premium’u keşfet',
                                    style: TextStyle(
                                      fontFamily: 'serif',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              FadeTransition(
                opacity: fadeType,
                child: const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
