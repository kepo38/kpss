import 'package:flutter/material.dart';

import '../screens/premium/premium_paywall_screen.dart';
import '../services/play_billing_service.dart';
import '../services/premium_service.dart';
import '../theme/app_theme.dart';
import 'scale_button.dart';

/// Sınav geri sayımının altında Premium CTA — tıklanınca paywall açılır.
class PremiumUpgradeCard extends StatelessWidget {
  const PremiumUpgradeCard({super.key});

  Future<void> _openPaywall(BuildContext context) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const PremiumPaywallScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: PlayBillingService.instance.premiumNotifier,
      builder: (context, billingPremium, _) {
        if (billingPremium || PremiumService.instance.isPremium) {
          return const SizedBox.shrink();
        }

        return ScaleButton(
          onPressed: () => _openPaywall(context),
          child: Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFAF6EF),
                  Color(0xFFF0E6D4),
                  Color(0xFFE8D5B0),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
              border: Border.all(
                color: AppTheme.champagne.withValues(alpha: 0.65),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.champagne.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -18,
                  top: -22,
                  child: IgnorePointer(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.champagneLight.withValues(alpha: 0.45),
                            AppTheme.champagneLight.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 3.5,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.champagneLight,
                          AppTheme.champagne,
                          Color(0xFFB8924A),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 13, 12, 13),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.champagne.withValues(alpha: 0.28),
                              AppTheme.champagneLight.withValues(alpha: 0.45),
                            ],
                          ),
                          border: Border.all(
                            color: AppTheme.champagne.withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          size: 22,
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Premium\'a yükselt',
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                                height: 1.15,
                                color: AppTheme.ink,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Sınırsız test · reklamsız · tüm özellikler',
                              style: TextStyle(
                                fontSize: 11.5,
                                height: 1.25,
                                color: AppTheme.slate,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.ink,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Text(
                          'Keşfet',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                            color: AppTheme.champagneLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
