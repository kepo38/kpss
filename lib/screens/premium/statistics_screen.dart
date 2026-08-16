import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/practice_exam_model.dart';
import '../../services/content_bank_service.dart';
import '../../services/notification_service.dart';
import '../../services/practice_exam_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/net_line_chart.dart';
import 'add_exam_sheet.dart';

/// Premium deneme analiz merkezi — GK/GY, yayın evi, grafikler, haftalık özet.
class StatisticsScreen extends StatefulWidget {
  final bool embedded;

  const StatisticsScreen({super.key, this.embedded = false});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openAddExam() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AddExamSheet(),
    );
    if (saved == true) {
      setState(() {});
      NotificationService.instance.refreshWeeklySummaryContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final embedded = widget.embedded;

    return Scaffold(
      backgroundColor: embedded ? AppTheme.page(context) : null,
      appBar: AppBar(
        backgroundColor: embedded ? AppTheme.page(context) : null,
        foregroundColor: embedded ? AppTheme.ink : null,
        leading: embedded ? null : const AppBackButton(),
        automaticallyImplyLeading: !embedded,
        title: Text(
          embedded ? 'Deneme' : 'Deneme Analizi',
          style: embedded
              ? const TextStyle(
                  fontFamily: 'serif',
                  fontWeight: FontWeight.w600,
                  fontSize: 24,
                  color: AppTheme.ink,
                )
              : null,
        ),
        toolbarHeight: embedded ? 56 : null,
        bottom: TabBar(
          controller: _tabController,
          labelColor: embedded ? AppTheme.ink : null,
          unselectedLabelColor:
              embedded ? AppTheme.slate.withValues(alpha: 0.55) : null,
          indicatorColor: embedded ? AppTheme.champagne : null,
          tabs: const [
            Tab(text: 'Genel Bakış'),
            Tab(text: 'Yayın Evleri'),
            Tab(text: 'Denemeler'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Deneme ekle',
            onPressed: _openAddExam,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(onRefresh: () => setState(() {})),
          _PublisherTab(onFilter: () => setState(() {})),
          _ExamsTab(onRefresh: () => setState(() {})),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddExam,
        backgroundColor: embedded ? AppTheme.champagne : null,
        foregroundColor: embedded ? AppTheme.ink : null,
        icon: const Icon(Icons.add),
        label: const Text('Deneme Ekle'),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final VoidCallback onRefresh;

  const _OverviewTab({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final service = PracticeExamService.instance;
    final summary = service.weeklySummary;
    final dueCount = ContentBankService.instance.wrongQuestionCount;
    final labels = service.netTrendLabels;
    final netTrend = service.netTrend;
    final gyTrend = service.gyTrend;
    final gkTrend = service.gkTrend;
    final bySubject = service.aggregateBySubject;

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _WeeklySummaryCard(summary: summary, dueCount: dueCount),
          const SizedBox(height: 20),
          Text(
            'Net Gelişim Grafiği',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: AppTheme.lightPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: NetLineChart(
                labels: labels,
                primaryValues: netTrend,
                secondaryValues: gyTrend,
                tertiaryValues: gkTrend,
                primaryLabel: 'Toplam',
                secondaryLabel: 'GY',
                tertiaryLabel: 'GK',
                height: 220,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _GkGyCard(
                  title: 'Genel Yetenek',
                  net: gyTrend.isEmpty ? 0 : gyTrend.last,
                  icon: Icons.psychology_outlined,
                  color: AppTheme.lightPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GkGyCard(
                  title: 'Genel Kültür',
                  net: gkTrend.isEmpty ? 0 : gkTrend.last,
                  icon: Icons.public_outlined,
                  color: AppTheme.lightAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Ders Bazlı Performans',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: AppTheme.lightPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...bySubject.entries.map(
            (e) => _SubjectBar(ders: e.key, sonuc: e.value),
          ),
        ],
      ),
    );
  }
}

class _WeeklySummaryCard extends StatelessWidget {
  final WeeklyPerformanceSummary summary;
  final int dueCount;

  const _WeeklySummaryCard({required this.summary, required this.dueCount});

  @override
  Widget build(BuildContext context) {
    final degisim = summary.netDegisim;
    final degisimText =
        '${degisim >= 0 ? '+' : ''}${degisim.toStringAsFixed(1)}';
    final degisimColor = degisim >= 0 ? Colors.green : Colors.red;

    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          gradient: LinearGradient(
            colors: [
              AppTheme.lightPrimary,
              AppTheme.lightPrimary.withValues(alpha: 0.85),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: AppTheme.lightAccent),
                const SizedBox(width: 8),
                Text(
                  'Haftalık Özet',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Icon(Icons.notifications_outlined,
                    color: Colors.white.withValues(alpha: 0.7), size: 18),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _SummaryStat(
                  value: '${summary.denemeSayisi}',
                  label: 'Deneme',
                ),
                _SummaryStat(
                  value: summary.ortalamaNet.toStringAsFixed(1),
                  label: 'Ort. Net',
                ),
                _SummaryStat(
                  value: degisimText,
                  label: 'Değişim',
                  valueColor: degisimColor,
                ),
                _SummaryStat(
                  value: '$dueCount',
                  label: 'Yanlış',
                ),
              ],
            ),
            if (summary.enGucluDers != '-') ...[
              const SizedBox(height: 12),
              Text(
                'Güçlü: ${summary.enGucluDers} · Geliştir: ${summary.gelistirilmesiGerekenDers}',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;

  const _SummaryStat({
    required this.value,
    required this.label,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              color: valueColor ?? Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              color: AppTheme.lightAccent,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _GkGyCard extends StatelessWidget {
  final String title;
  final double net;
  final IconData icon;
  final Color color;

  const _GkGyCard({
    required this.title,
    required this.net,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(title, style: GoogleFonts.inter(fontSize: 12)),
            Text(
              net.toStringAsFixed(1),
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text('net', style: GoogleFonts.inter(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _SubjectBar extends StatelessWidget {
  final String ders;
  final DersSonuc sonuc;

  const _SubjectBar({required this.ders, required this.sonuc});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(ders, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                Text(
                  '${sonuc.net.toStringAsFixed(1)} net',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.lightPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (sonuc.net / 30).clamp(0.0, 1.0),
                backgroundColor: AppTheme.lightAccent.withValues(alpha: 0.2),
                color: AppTheme.lightPrimary,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'D:${sonuc.dogru} Y:${sonuc.yanlis} B:${sonuc.bos}',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublisherTab extends StatelessWidget {
  final VoidCallback onFilter;

  const _PublisherTab({required this.onFilter});

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
          (s) => _PublisherCard(
            stats: s,
            isFiltered: activeFilter == s.yayinEvi,
            onTap: () {
              service.setPublisherFilter(
                activeFilter == s.yayinEvi ? null : s.yayinEvi,
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

class _ExamsTab extends StatelessWidget {
  final VoidCallback onRefresh;

  const _ExamsTab({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final exams = PracticeExamService.instance.allExams;

    if (exams.isEmpty) {
      return const Center(child: Text('Henüz deneme kaydı yok'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: exams.length,
      itemBuilder: (context, i) {
        final exam = exams[i];
        return _ExamDetailCard(
          exam: exam,
          onDelete: () {
            PracticeExamService.instance.deleteExam(exam.id);
            onRefresh();
          },
        );
      },
    );
  }
}

class _ExamDetailCard extends StatelessWidget {
  final PracticeExamModel exam;
  final VoidCallback onDelete;

  const _ExamDetailCard({required this.exam, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        title: Text(exam.denemeAdi,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${exam.yayinEvi} · ${DateFormat('d MMM yyyy', 'tr').format(exam.tarih)}',
        ),
        trailing: Text(
          '${exam.toplamNet.toStringAsFixed(1)} net',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: AppTheme.lightAccent,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _GkGyCard(
                      title: 'GY',
                      net: exam.genelYetenekNet,
                      icon: Icons.psychology_outlined,
                      color: AppTheme.lightPrimary,
                    ),
                    _GkGyCard(
                      title: 'GK',
                      net: exam.genelKulturNet,
                      icon: Icons.public_outlined,
                      color: AppTheme.lightAccent,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...exam.dersSonuclari.entries.map(
                  (e) => ListTile(
                    dense: true,
                    title: Text(e.key),
                    trailing: Text(
                      '${e.value.net.toStringAsFixed(1)} net '
                      '(D${e.value.dogru} Y${e.value.yanlis} B${e.value.bos})',
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                  ),
                ),
                if (exam.notlar != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Not: ${exam.notlar}',
                        style: GoogleFonts.inter(fontSize: 12)),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Sil'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
