import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'scale_button.dart';

/// Stüdyo hub hero — renkli ışık + üstte Premium’u keşfet.
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
          top: -90,
          right: -40,
          child: IgnorePointer(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.champagne.withValues(alpha: 0.32),
                    const Color(0xFFE8A87C).withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 40,
          left: -90,
          child: IgnorePointer(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.neonEdge.withValues(alpha: 0.28),
                    AppTheme.neonEdge.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 160,
          right: 40,
          child: IgnorePointer(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFE879A9).withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(8, topPad + 2, 12, 22),
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
                        if (premium) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.champagne.withValues(alpha: 0.5),
                              ),
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.champagne.withValues(alpha: 0.22),
                                  AppTheme.champagne.withValues(alpha: 0.08),
                                ],
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_rounded,
                                  size: 15,
                                  color: AppTheme.champagneLight,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Premium',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
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
                              horizontal: 12,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFFFF4DE),
                                  Color(0xFFE8C878),
                                  AppTheme.champagne,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.champagne.withValues(
                                    alpha: 0.42,
                                  ),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.workspace_premium_rounded,
                                  size: 16,
                                  color: AppTheme.ink,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Premium’u keşfet',
                                  style: TextStyle(
                                    fontFamily: 'serif',
                                    fontSize: 12.5,
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
              const SizedBox(height: 22),
              FadeTransition(
                opacity: fadeEarly,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AppTheme.neonEdge.withValues(alpha: 0.45),
                            ),
                            color: AppTheme.neonEdge.withValues(alpha: 0.12),
                          ),
                          child: Text(
                            'STÜDYO',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.4,
                              color: AppTheme.neonEdge.withValues(alpha: 0.95),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Stüdyo',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 44,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                          letterSpacing: -1.4,
                          color: Colors.white,
                        ),
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
