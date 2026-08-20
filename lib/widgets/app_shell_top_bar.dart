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
        padding: EdgeInsets.fromLTRB(20, topPad + 6, 10, 8),
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
                        message: 'Stüdyo',
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onMoreTap,
                        borderRadius: BorderRadius.circular(10),
                        child: Tooltip(
                          message: 'Stüdyo · Araçlar',
                          child: Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppTheme.champagne.withValues(alpha: 0.55),
                              ),
                              color: AppTheme.champagne.withValues(alpha: 0.12),
                            ),
                            child: Icon(
                              Icons.apps_rounded,
                              color: AppTheme.isDark(context)
                                  ? AppTheme.champagneLight
                                  : const Color(0xFF8F6E32),
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    PremiumHeaderButton(
                      isPremium: premium,
                      onTap: premium ? null : onPremiumTap,
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
