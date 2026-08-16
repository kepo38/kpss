import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/brand_constants.dart';
import '../services/store_rating_service.dart';
import '../theme/app_theme.dart';

/// Profil — Play Store 5 yıldız puan kartı.
class StoreRatingCard extends StatefulWidget {
  final Future<void> Function()? onOpenStore;
  final bool compact;

  const StoreRatingCard({super.key, this.onOpenStore, this.compact = false});

  @override
  State<StoreRatingCard> createState() => _StoreRatingCardState();
}

class _StoreRatingCardState extends State<StoreRatingCard> {
  int _selected = 0;

  Future<void> _rate(int stars) async {
    HapticFeedback.selectionClick();
    setState(() => _selected = stars);
    final open = widget.onOpenStore ?? StoreRatingService.openStoreListing;
    await open();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return Material(
        color: AppTheme.inkSoft,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _rate(5),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.champagne.withValues(alpha: 0.22),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFFF6E8),
                          AppTheme.champagne,
                          Color(0xFFB8904A),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: AppTheme.ink,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Uygulamayı değerlendir',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _selected > 0
                              ? 'Teşekkürler — Play Store açılıyor'
                              : 'Google Play\'de 5 yıldız ver',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 1; i <= 5; i++)
                        Icon(
                          i <= (_selected == 0 ? 5 : _selected)
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 18,
                          color: AppTheme.champagne.withValues(
                            alpha: i <= (_selected == 0 ? 5 : _selected) ? 0.95 : 0.35,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DEĞERLENDİR',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
            color: AppTheme.champagne.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Uygulamayı puanla',
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _rate(5),
            borderRadius: BorderRadius.circular(16),
            splashColor: AppTheme.champagne.withValues(alpha: 0.12),
            highlightColor: AppTheme.champagne.withValues(alpha: 0.06),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1E2C44),
                    AppTheme.inkSoft,
                    Color(0xFF101A2C),
                  ],
                ),
                border: Border.all(
                  color: AppTheme.champagne.withValues(alpha: 0.42),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.champagne.withValues(alpha: 0.14),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFFF6E8),
                            AppTheme.champagne,
                            Color(0xFFB8904A),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.champagne.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.star_rounded,
                        color: AppTheme.ink,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _selected > 0
                          ? 'Teşekkürler — Play Store’da puanını tamamla'
                          : '${BrandConstants.appName} seninle büyüyor',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _selected > 0
                          ? 'Google Play değerlendirme sayfası açılıyor.'
                          : 'Beş yıldız, daha çok adaya ulaşmamıza yardım eder.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Colors.white.withValues(alpha: 0.48),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 1; i <= 5; i++)
                          Semantics(
                            label: '$i yıldız',
                            button: true,
                            selected: i <= _selected,
                            child: IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              onPressed: () => _rate(i),
                              icon: Icon(
                                i <= _selected
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                size: 30,
                                color: i <= _selected
                                    ? AppTheme.champagneLight
                                    : AppTheme.champagne.withValues(alpha: 0.55),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Google Play’de puan ver',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.champagne.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
