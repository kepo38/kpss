import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class QuestionRatingBar extends StatelessWidget {
  final int? selectedStars;
  final double? averageRating;
  final int ratingCount;
  final bool loading;
  final bool saving;
  final Future<void> Function(int stars) onRate;

  const QuestionRatingBar({
    super.key,
    required this.onRate,
    this.selectedStars,
    this.averageRating,
    this.ratingCount = 0,
    this.loading = false,
    this.saving = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.champagne.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.champagne.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bu sorunun kalitesini değerlendir',
            style: TextStyle(
              color: AppTheme.champagneLight,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                ...List.generate(5, (index) {
                  final value = index + 1;
                  final selected = value <= (selectedStars ?? 0);
                  return Semantics(
                    label: '$value yıldız',
                    button: true,
                    enabled: !saving,
                    selected: selected,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(5),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: saving ? null : () => onRate(value),
                      icon: Icon(
                        selected
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: selected
                            ? AppTheme.champagne
                            : Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  );
                }),
              const Spacer(),
              if (saving)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (ratingCount > 0 && averageRating != null) ...[
            const SizedBox(height: 2),
            Text(
              '${averageRating!.toStringAsFixed(2)} · $ratingCount oy',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
