import 'package:flutter/material.dart';

import '../services/exam_catalog_service.dart';
import '../services/kpss_preference_service.dart';
import '../theme/app_theme.dart';
import '../theme/subject_neon_palette.dart';
import 'countdown_widget.dart';

/// Profil — hedef sınav seçimi.
class KpssTypePreferencePicker extends StatelessWidget {
  final bool embedded;
  final bool neon;

  const KpssTypePreferencePicker({
    super.key,
    this.embedded = false,
    this.neon = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        KpssPreferenceService.instance,
        ExamCatalogService.instance,
      ]),
      builder: (context, _) {
        final service = KpssPreferenceService.instance;
        final selected = service.examTrack;
        final tracks = ExamCatalogService.instance.items;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!embedded) ...[
              Text(
                'HEDEF SINAV / SAYAÇ',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.champagne.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 10),
            ] else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
                child: Text(
                  'Hedef sınav & sayaç',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
            ...tracks.map((track) {
              final active = selected.id == track.id;
              final accent = neon ? AppTheme.neonEdge : AppTheme.champagne;
              final inactiveFill = neon && embedded
                  ? Colors.transparent
                  : embedded
                      ? Colors.white.withValues(alpha: 0.04)
                      : AppTheme.inkSoft;
              return Padding(
                padding: EdgeInsets.only(bottom: embedded ? 6 : 8),
                child: Material(
                  color: active
                      ? accent.withValues(alpha: neon ? 0.14 : 0.14)
                      : inactiveFill,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => service.setExamTrack(track),
                    borderRadius: BorderRadius.circular(12),
                    splashColor: accent.withValues(alpha: 0.12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: active
                              ? accent.withValues(alpha: neon ? 0.85 : 0.7)
                              : neon && embedded
                                  ? accent.withValues(alpha: 0.22)
                                  : Colors.white.withValues(alpha: 0.08),
                        ),
                        boxShadow: active && neon
                            ? SubjectNeonPalette.glow(accent, blur: 12)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            track.icon,
                            size: 22,
                            color: active
                                ? (neon ? accent : AppTheme.champagneLight)
                                : Colors.white.withValues(alpha: 0.55),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track.label,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: active
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.78),
                                  ),
                                ),
                                Text(
                                  '${track.description} · ${_dateLine(track)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: active && neon
                                        ? accent.withValues(alpha: 0.88)
                                        : Colors.white.withValues(alpha: 0.45),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (active)
                            Icon(
                              Icons.check_circle_rounded,
                              color: accent,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  String _dateLine(ExamTrack track) {
    if (!track.hasUpcomingDate()) {
      return 'Yeni tarih ÖSYM tarafından açıklanacak';
    }
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
    final d = track.nextExamDate();
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
