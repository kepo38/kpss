import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/topic_progress_model.dart';
import '../../services/topic_progress_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/countdown_widget.dart';

class TopicTrackingScreen extends StatefulWidget {
  final KpssType kpssType;

  const TopicTrackingScreen({super.key, required this.kpssType});

  @override
  State<TopicTrackingScreen> createState() => _TopicTrackingScreenState();
}

class _TopicTrackingScreenState extends State<TopicTrackingScreen> {
  final _service = TopicProgressService.instance;

  @override
  Widget build(BuildContext context) {
    final topics = _service.getTopics(widget.kpssType);
    final progress = _service.progressPercent(widget.kpssType);
    final grouped = <String, List<TopicProgressModel>>{};
    for (final t in topics) {
      grouped.putIfAbsent(t.dersAdi, () => []).add(t);
    }

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Konu Takibi'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.kpssType.label,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.lightAccent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppTheme.lightAccent.withValues(alpha: 0.2),
                    color: AppTheme.lightPrimary,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '%${(progress * 100).toStringAsFixed(0)} tamamlandı',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...grouped.entries.map((entry) {
            return ExpansionTile(
              title: Text(
                entry.key,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${entry.value.where((t) => t.tamamlandi).length}/${entry.value.length} konu',
              ),
              children: entry.value.map((topic) {
                return CheckboxListTile(
                  value: topic.tamamlandi,
                  title: Text(topic.altKonuAdi),
                  activeColor: AppTheme.lightPrimary,
                  onChanged: (_) {
                    setState(() => _service.toggleTopic(topic.id));
                  },
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }
}
