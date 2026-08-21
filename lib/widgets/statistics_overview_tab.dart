import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/practice_exam_model.dart';
import '../services/content_bank_service.dart';
import '../services/notification_service.dart';
import '../services/practice_exam_service.dart';
import '../theme/app_theme.dart';
import 'net_development_chart.dart';

class StatisticsOverviewTab extends StatelessWidget {
  final VoidCallback onRefresh;

  const StatisticsOverviewTab({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final service = PracticeExamService.instance;
    final summary = service.weeklySummary;
    final gyTrend = service.gyTrend;
    final gkTrend = service.gkTrend;
    final points = List.generate(
      service.netTrend.length,
      (index) => NetDevelopmentPoint(
        label: index < service.netTrendLabels.length
            ? service.netTrendLabels[index]
            : '',
        totalNet: service.netTrend[index],
        gyNet: index < gyTrend.length ? gyTrend[index] : null,
        gkNet: index < gkTrend.length ? gkTrend[index] : null,
      ),
    );

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Deneme İstatistiklerim',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: AppTheme.lightPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Genel bakış',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.lightPrimary.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 16),
          _WeeklySummaryCard(
            summary: summary,
            dueCount: ContentBankService.instance.wrongQuestionCount,
          ),
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
              child: NetDevelopmentChart(points: points),
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
          ...service.aggregateBySubject.entries.map(
            (entry) => _SubjectBar(ders: entry.key, sonuc: entry.value),
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

  Future<void> _toggleExamReminder(BuildContext context) async {
    final service = NotificationService.instance;
    final enabled = await service.isExamReminderEnabled();
    if (!context.mounted) return;

    final wantEnable = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(enabled ? 'Deneme hatırlatıcısı' : 'Deneme hatırlatıcısı kur'),
        content: Text(
          enabled
              ? 'Pazar 10:00 deneme hatırlatıcısı açık. Kapatmak ister misin?'
              : 'Her Pazar saat 10:00’da “deneme çöz” hatırlatması göndereyim mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(enabled ? 'Açık kalsın' : 'Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(enabled ? 'Kapat' : 'Hatırlat'),
          ),
        ],
      ),
    );
    if (wantEnable != true || !context.mounted) return;

    final nowEnabled = await service.setExamReminderEnabled(!enabled);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nowEnabled
              ? 'Pazar 10:00 deneme hatırlatıcısı açıldı.'
              : 'Deneme hatırlatıcısı kapatıldı.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final change = summary.netDegisim;
    final changeText = '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}';
    final changeColor = change >= 0 ? Colors.green : Colors.red;
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
                const Icon(Icons.insights, color: AppTheme.lightAccent),
                const SizedBox(width: 8),
                Text(
                  'Haftalık Özet',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _toggleExamReminder(context),
                  tooltip: 'Pazar 10:00 deneme hatırlatıcısı',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  icon: Icon(
                    Icons.notifications_active_outlined,
                    color: Colors.white.withValues(alpha: 0.85),
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _SummaryStat(value: '${summary.denemeSayisi}', label: 'Deneme'),
                _SummaryStat(
                  value: summary.ortalamaNet.toStringAsFixed(1),
                  label: 'Ort. Net',
                ),
                _SummaryStat(
                  value: changeText,
                  label: 'Değişim',
                  valueColor: changeColor,
                ),
                _SummaryStat(value: '$dueCount', label: 'Yanlış'),
              ],
            ),
            if (summary.enGucluDers != '-') ...[
              const SizedBox(height: 12),
              Text(
                'Güçlü: ${summary.enGucluDers} · Geliştir: '
                '${summary.gelistirilmesiGerekenDers}',
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
