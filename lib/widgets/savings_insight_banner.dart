import 'package:flutter/material.dart';

import '../services/content_bank_service.dart';
import '../services/premium_service.dart';
import '../services/user_savings_insight_service.dart';
import '../theme/app_theme.dart';

/// Ana ekranda tahmini kazanç bilgisi — tıklanınca paywall.
class SavingsInsightBanner extends StatelessWidget {
  final VoidCallback? onPremiumTap;
  final bool isPremium;

  const SavingsInsightBanner({
    super.key,
    required this.isPremium,
    this.onPremiumTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        UserSavingsInsightService.instance,
        ContentBankService.instance,
      ]),
      builder: (context, _) {
        final premium = PremiumService.instance.isPremium || isPremium;
        final message = UserSavingsInsightService.instance.homeBannerMessage(
          isPremium: premium,
        );
        if (message == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPremiumTap,
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.champagne.withValues(alpha: 0.18),
                      AppTheme.neonEdge.withValues(alpha: 0.08),
                    ],
                  ),
                  border: Border.all(
                    color: AppTheme.champagne.withValues(alpha: 0.45),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.savings_outlined,
                        size: 20,
                        color: AppTheme.champagne.withValues(alpha: 0.95),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          message,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onPage(context),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: AppTheme.mutedOnPage(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
