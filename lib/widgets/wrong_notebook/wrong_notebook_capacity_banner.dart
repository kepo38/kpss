import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/wrong_notebook_constants.dart';
import '../../theme/app_theme.dart';
import '../../utils/wrong_notebook_capacity_upsell.dart';

/// Arşiv sınırı dolduğunda yanlış defteri üst uyarısı.
class WrongNotebookCapacityBanner extends StatelessWidget {
  final int currentCount;
  final int limit;

  const WrongNotebookCapacityBanner({
    super.key,
    required this.currentCount,
    required this.limit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => WrongNotebookCapacityUpsell.showAtLimit(context),
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: [
                  AppTheme.champagne.withValues(alpha: 0.16),
                  AppTheme.inkSoft.withValues(alpha: 0.35),
                ],
              ),
              border: Border.all(
                color: AppTheme.champagne.withValues(alpha: 0.45),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 20,
                    color: AppTheme.champagne.withValues(alpha: 0.92),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Arşiv sınırına ulaştın ($currentCount/$limit)',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.onPage(context),
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          WrongNotebookConstants.proUpsellSubtitle,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            height: 1.4,
                            color: AppTheme.mutedOnPage(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.lock_rounded,
                    size: 18,
                    color: AppTheme.champagne.withValues(alpha: 0.85),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
