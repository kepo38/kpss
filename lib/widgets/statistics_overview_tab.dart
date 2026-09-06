import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/practice_exam_model.dart';
import '../services/content_bank_service.dart';
import '../services/exam_trend_service.dart';
import '../services/notification_service.dart';
import '../services/play_billing_service.dart';
import '../services/practice_exam_service.dart';
import '../services/premium_service.dart';
import '../services/tg_exam_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pro_feature_lock.dart';
import 'exam_premium_shell.dart';
import 'net_development_chart.dart';

class StatisticsOverviewTab extends StatelessWidget {
  final VoidCallback onRefresh;

  const StatisticsOverviewTab({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final service = PracticeExamService.instance;
    final summary = service.weeklySummary;

    return ListenableBuilder(
      listenable: Listenable.merge([
        TgExamService.instance,
        PlayBillingService.instance.premiumNotifier,
      ]),
      builder: (context, _) {
        final isPremium = PremiumService.instance.isPremium;
        final livePoints = ExamTrendService.instance.buildUnifiedTrend();
        final gyValues =
            livePoints.map((p) => p.gyNet).whereType<double>().toList();
        final gkValues =
            livePoints.map((p) => p.gkNet).whereType<double>().toList();

        return RefreshIndicator(
          onRefresh: () async => onRefresh(),
          color: AppTheme.champagne,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            children: [
              const ExamPremiumSectionLabel(
                label: 'Genel Bakış',
                subtitle: 'TG ve yayınevi denemelerinizin özeti',
              ),
              const SizedBox(height: 16),
              _WeeklySummaryCard(
                summary: summary,
                dueCount: ContentBankService.instance.wrongQuestionCount,
              ),
              const SizedBox(height: 22),
              const ExamPremiumSectionLabel(
                label: 'Genel Başarı Çizgisi',
                subtitle: 'TG denemeleri ve yayınevi kayıtlarınız birlikte',
              ),
              const SizedBox(height: 12),
              ProFeatureLock(
                locked: !isPremium,
                upsellTitle: 'TREND ANALİZİ',
                upsellSubtitle: kProUpsellSubtitle,
                child: ExamPremiumCardShell(
                  accentBar: false,
                  padding: const EdgeInsets.all(14),
                  child: NetDevelopmentChart(points: livePoints),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _GkGyCard(
                      title: 'Genel Yetenek',
                      net: gyValues.isEmpty ? 0 : gyValues.last,
                      icon: Icons.psychology_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _GkGyCard(
                      title: 'Genel Kültür',
                      net: gkValues.isEmpty ? 0 : gkValues.last,
                      icon: Icons.public_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const ExamPremiumSectionLabel(label: 'Ders Bazlı Performans'),
              const SizedBox(height: 12),
              ...service.aggregateBySubject.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SubjectBar(ders: entry.key, sonuc: entry.value),
                ),
              ),
            ],
          ),
        );
      },
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
    final changeText = change == null
        ? '—'
        : '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}';
    final changeColor = change == null
        ? Colors.white.withValues(alpha: 0.55)
        : change >= 0
            ? const Color(0xFF6EE7A8)
            : const Color(0xFFFF9B9B);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.champagne.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.champagne.withValues(alpha: 0.42),
            ),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF18263C),
                AppTheme.inkSoft,
                AppTheme.ink,
              ],
              stops: [0, 0.45, 1],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 3,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppTheme.champagneLight,
                        AppTheme.champagne,
                        Color(0xFFB8924A),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.insights_outlined,
                          color: AppTheme.champagne,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Haftalık Özet',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
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
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
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
              color: AppTheme.champagne.withValues(alpha: 0.9),
              fontSize: 11,
              fontWeight: FontWeight.w600,
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

  const _GkGyCard({
    required this.title,
    required this.net,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ExamPremiumCardShell(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.champagne, size: 22),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.mutedOnPage(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            net.toStringAsFixed(1),
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppTheme.onPage(context),
              letterSpacing: -0.5,
            ),
          ),
          Text(
            'net',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppTheme.champagne.withValues(alpha: 0.85),
            ),
          ),
        ],
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
    final maxQ = PracticeExamModel.soruSayisi(ders);
    final maxNet = maxQ > 0 ? maxQ.toDouble() : 30.0;
    final avgNet = sonuc.net.clamp(0.0, maxNet);
    final fill = (avgNet / maxNet).clamp(0.0, 1.0);
    // Yuksek net -> yesil; orta/dusuk -> champagne gold; track acik gri.
    final fillColor = fill >= 0.7
        ? const Color(0xFF2F9E6A)
        : AppTheme.champagne;

    return ExamPremiumCardShell(
      accentBar: false,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ders,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onPage(context),
                ),
              ),
              Text(
                '${avgNet.toStringAsFixed(1)} net',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.champagne,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fill,
              backgroundColor: AppTheme.hairline(context),
              color: fillColor,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'D:${sonuc.dogru} Y:${sonuc.yanlis} B:${sonuc.bos}',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppTheme.mutedOnPage(context),
            ),
          ),
        ],
      ),
    );
  }
}
