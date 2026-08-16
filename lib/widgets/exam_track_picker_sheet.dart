import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../services/exam_catalog_service.dart';
import '../services/kpss_preference_service.dart';
import '../theme/app_theme.dart';
import '../theme/subject_neon_palette.dart';
import '../widgets/countdown_widget.dart';

/// Hedef sınav seçimi — anında açılan alt sayfa.
class ExamTrackPickerSheet extends StatefulWidget {
  const ExamTrackPickerSheet({super.key});

  static void show(BuildContext context) {
    // Sheet'i bir sonraki karede değil, hemen kuyruğa al.
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: AppTheme.smokeDeep,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const ExamTrackPickerSheet(),
    );
  }

  @override
  State<ExamTrackPickerSheet> createState() => _ExamTrackPickerSheetState();
}

class _ExamTrackPickerSheetState extends State<ExamTrackPickerSheet> {
  late List<ExamTrack> _tracks;
  late ExamTrack _selected;

  @override
  void initState() {
    super.initState();
    _tracks = List<ExamTrack>.from(ExamTrack.defaults);
    _selected = KpssPreferenceService.instance.examTrack;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final latest = ExamCatalogService.instance.items;
      if (latest.length != _tracks.length ||
          latest.any((t) => !_tracks.any((e) => e.id == t.id))) {
        setState(() => _tracks = latest);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        14,
        18,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.neonEdge.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sınav tipi',
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sayaç ve içerik bu seçime göre güncellenir.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 14),
          for (final track in _tracks)
            _TrackTile(
              track: track,
              selected: _selected.id == track.id,
              onTap: () {
                setState(() => _selected = track);
                KpssPreferenceService.instance.setExamTrack(track);
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }
}

class _TrackTile extends StatelessWidget {
  final ExamTrack track;
  final bool selected;
  final VoidCallback onTap;

  const _TrackTile({
    required this.track,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
    final date = track.nextExamDate();
    final dateLabel = track.hasUpcomingDate()
        ? '${date.day} ${months[date.month - 1]} ${date.year}'
        : 'Yeni tarih ÖSYM tarafından açıklanacak';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: SubjectNeonPalette.lightNeonModule(
              neon: selected ? AppTheme.neonEdge : AppTheme.champagne,
              accent: true,
              radius: 14,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Icon(
                    track.icon,
                    color: selected ? AppTheme.neonEdge : AppTheme.champagneLight,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.label,
                          style: const TextStyle(
                            fontFamily: 'serif',
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${track.description} · $dateLabel',
                          style: TextStyle(
                            fontSize: 12,
                            color: (selected
                                    ? AppTheme.neonEdge
                                    : Colors.white)
                                .withValues(alpha: 0.72),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppTheme.neonEdge,
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
