import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/practice_exam_model.dart';
import '../services/practice_exam_service.dart';
import '../theme/app_theme.dart';

class StatisticsPublishersTab extends StatelessWidget {
  final VoidCallback onFilter;

  const StatisticsPublishersTab({super.key, required this.onFilter});

  @override
  Widget build(BuildContext context) {
    final service = PracticeExamService.instance;
    final stats = service.publisherStats;
    final activeFilter = service.publisherFilter;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Yayın evine göre performansınızı karşılaştırın',
          style: GoogleFonts.inter(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),
        if (activeFilter != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InputChip(
              label: Text('Filtre: $activeFilter'),
              onDeleted: () {
                service.setPublisherFilter(null);
                onFilter();
              },
            ),
          ),
        ...stats.map(
          (item) => _PublisherCard(
            stats: item,
            isFiltered: activeFilter == item.yayinEvi,
            onTap: () {
              service.setPublisherFilter(
                activeFilter == item.yayinEvi ? null : item.yayinEvi,
              );
              onFilter();
            },
          ),
        ),
      ],
    );
  }
}

class _PublisherCard extends StatelessWidget {
  final PublisherStats stats;
  final bool isFiltered;
  final VoidCallback onTap;

  const _PublisherCard({
    required this.stats,
    required this.isFiltered,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isFiltered ? AppTheme.lightPrimary.withValues(alpha: 0.06) : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.lightAccent.withValues(alpha: 0.2),
                    child: Text(
                      stats.yayinEvi.substring(0, 1),
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stats.yayinEvi,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${stats.denemeSayisi} deneme',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        stats.ortalamaNet.toStringAsFixed(1),
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.lightPrimary,
                        ),
                      ),
                      Text('ort. net', style: GoogleFonts.inter(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _MiniStat(label: 'En yüksek', value: stats.enYuksekNet),
                  const SizedBox(width: 16),
                  _MiniStat(label: 'GY ort.', value: stats.ortalamaGy),
                  const SizedBox(width: 16),
                  _MiniStat(label: 'GK ort.', value: stats.ortalamaGk),
                ],
              ),
              if (isFiltered)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Filtre aktif — Genel Bakış sekmesinde bu yayınevi gösteriliyor',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.lightAccent,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final double value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
        Text(
          value.toStringAsFixed(1),
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
