import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'pro_upsell_sheet.dart';

/// Pro kilit / upsell alt metni — iki satır.
const kProUpsellSubtitle = 'Pro Üyeliğe Geç\nHedefin Olan Kamuya Atan';

/// Pro özellik — bulanık + kilit overlay.
class ProFeatureLock extends StatelessWidget {
  final Widget child;
  final bool locked;
  final VoidCallback? onUnlock;
  final String upsellTitle;
  final String upsellSubtitle;

  const ProFeatureLock({
    super.key,
    required this.child,
    required this.locked,
    this.onUnlock,
    this.upsellTitle = 'PRO ÖZELLİK',
    this.upsellSubtitle = kProUpsellSubtitle,
  });

  Future<void> _handleTap(BuildContext context) async {
    if (onUnlock != null) {
      onUnlock!();
      return;
    }
    await ProUpsellSheet.show(
      context,
      title: upsellTitle,
      subtitle: upsellSubtitle,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!locked) return child;

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Opacity(opacity: 0.45, child: child),
          ),
        ),
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _handleTap(context),
              borderRadius: BorderRadius.circular(14),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.ink.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.champagne.withValues(alpha: 0.55),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.champagne.withValues(alpha: 0.12),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        color: AppTheme.champagne.withValues(alpha: 0.95),
                        size: 28,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        upsellSubtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'serif',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                          color: Color(0xFFF6E7C3),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pro ile aç',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.champagne.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
