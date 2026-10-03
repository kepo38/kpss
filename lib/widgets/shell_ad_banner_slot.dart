import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ad_manager.dart';
import '../theme/app_theme.dart';

/// Ana kabuk — alt menü üstünde küçük, sade AdMob banner.
class ShellAdBannerSlot extends StatelessWidget {
  const ShellAdBannerSlot({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AdManager.instance,
      builder: (context, _) {
        final bannerAd = AdManager.instance.shellBannerAd;
        if (bannerAd == null) return const SizedBox.shrink();

        final height = bannerAd.size.height.toDouble();
        return DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.barSurface(context).withValues(alpha: 0.96),
            border: Border(
              top: BorderSide(color: AppTheme.hairline(context)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 3, 12, 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: height,
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: AdWidget(ad: bannerAd),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
