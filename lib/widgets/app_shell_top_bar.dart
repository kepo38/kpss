import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/brand_mark.dart';
import '../widgets/instagram_link_button.dart';
import '../widgets/premium_header_button.dart';

/// Sabit üst bar — Hedef Kamu + Pro Üyelik (tüm sekmeler).
class AppShellTopBar extends StatelessWidget {
  final double topPad;
  final ValueNotifier<bool> isPremium;
  final VoidCallback? onPremiumTap;
  final VoidCallback? onMoreTap;

  const AppShellTopBar({
    super.key,
    required this.topPad,
    required this.isPremium,
    this.onPremiumTap,
    this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.pageTop(context),
            AppTheme.page(context),
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, topPad + 8, 12, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: onMoreTap,
                      behavior: HitTestBehavior.opaque,
                      child: const Tooltip(
                        message: 'Ana sayfa',
                        child: BrandMark.topBar(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Tooltip(
                      message: '@hedefkamu.app',
                      child: InstagramLinkButton(size: 32),
                    ),
                  ],
                ),
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: isPremium,
              builder: (context, premium, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PremiumHeaderButton(
                      isPremium: premium,
                      onTap: premium ? null : onPremiumTap,
                    ),
                    IconButton(
                      tooltip: 'Daha fazla',
                      onPressed: onMoreTap,
                      icon: Icon(
                        Icons.apps_outlined,
                        color: AppTheme.mutedOnPage(context),
                        size: 22,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
