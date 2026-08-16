import 'package:flutter/material.dart';

import '../services/exam_catalog_service.dart';
import '../services/kpss_preference_service.dart';
import '../theme/app_theme.dart';
import 'countdown_widget.dart';
import 'exam_track_picker_sheet.dart';

/// Yalnızca seçilen sınavın tarihi, adı ve kalan süresi.
class ExamFocusPanel extends StatelessWidget {
  final bool light;

  const ExamFocusPanel({
    super.key,
    this.light = true,
  });

  static String formatExamDate(DateTime date) {
    const months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        KpssPreferenceService.instance,
        ExamCatalogService.instance,
      ]),
      builder: (context, _) {
        final prefs = KpssPreferenceService.instance;
        final track = prefs.examTrack;
        final dark = light && AppTheme.isDark(context);
        final onCream = light && !dark;
        final hasUpcomingDate = track.hasUpcomingDate();
        final examDate = track.nextExamDate();
        final nameColor = light ? AppTheme.onPage(context) : Colors.white;
        final dateColor = onCream
            ? AppTheme.slate
            : Colors.white.withValues(alpha: 0.62);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => ExamTrackPickerSheet.show(context),
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.champagne.withValues(alpha: dark ? 0.45 : 0.38),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? [
                      AppTheme.inkSoft.withValues(alpha: 0.96),
                      AppTheme.champagne.withValues(alpha: 0.1),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.94),
                      AppTheme.champagne.withValues(alpha: 0.1),
                    ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.ink.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ShimmerCountdownLabel(
                compact: true,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 20,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                            color: nameColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.event_rounded,
                              size: 14,
                              color: AppTheme.champagne.withValues(alpha: 0.9),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                hasUpcomingDate
                                    ? formatExamDate(examDate)
                                    : 'Yeni tarih bekleniyor',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.15,
                                  color: dateColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.unfold_more_rounded,
                    size: 18,
                    color: AppTheme.champagne.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 4),
                  CountdownWidget(
                    examTrack: track,
                    light: light,
                    embedded: true,
                    showLabel: false,
                    trailing: true,
                  ),
                ],
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
