import 'package:flutter/material.dart';

import '../services/content_bank_service.dart';
import 'countdown_widget.dart';
import '../services/smart_review_service.dart';
import '../theme/app_theme.dart';
import '../theme/subject_neon_palette.dart';
import 'scale_button.dart';

/// Akıllı tekrar + müfredat kısayolları.
class HomeStudyShortcuts extends StatelessWidget {
  final KpssType kpssType;
  final VoidCallback onSmartReview;
  final VoidCallback onStudyHub;

  const HomeStudyShortcuts({
    super.key,
    required this.kpssType,
    required this.onSmartReview,
    required this.onStudyHub,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ScaleButton(
          onPressed: onSmartReview,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: SubjectNeonPalette.lightNeonModule(
              neon: AppTheme.neonEdge,
              accent: true,
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppTheme.neonEdge.withValues(alpha: 0.16),
                    border: Border.all(
                      color: AppTheme.neonEdge.withValues(alpha: 0.55),
                    ),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_outlined,
                    color: AppTheme.neonEdge,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Akıllı tekrar',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      ListenableBuilder(
                        listenable: Listenable.merge([
                          SmartReviewService.instance,
                          ContentBankService.instance,
                        ]),
                        builder: (context, _) {
                          return Text(
                            SmartReviewService.instance.subtitleFor(kpssType),
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xB8FFFFFF),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppTheme.neonEdge.withValues(alpha: 0.9),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        ScaleButton(
          onPressed: onStudyHub,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withValues(alpha: 0.88),
              border: Border.all(
                color: AppTheme.ink.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  color: AppTheme.champagne.withValues(alpha: 0.9),
                  size: 22,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Müfredata git · konu testi çöz',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.ink,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: AppTheme.slate.withValues(alpha: 0.45),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
