import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/practice_exam_model.dart';
import '../services/practice_exam_service.dart';
import '../theme/app_theme.dart';
import 'exam_premium_shell.dart';
import 'exam_section_header.dart';
import 'tg_exams_section.dart';

class StatisticsExamsTab extends StatelessWidget {
  final VoidCallback onRefresh;

  const StatisticsExamsTab({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final exams = PracticeExamService.instance.allExams;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      children: [
        TgExamsSection(onRefresh: onRefresh),
        const SizedBox(height: 28),
        const ExamSectionHeader(
          title: 'Yayınevi Denemelerim',
          subtitle:
              'Dışarıda çözdüğünüz denemeleri kaydedin — netler gelişim '
              'grafiğine otomatik yansır.',
        ),
        if (exams.isEmpty)
          ExamPremiumCardShell(
            accentBar: false,
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.champagne.withValues(alpha: 0.12),
                    border: Border.all(
                      color: AppTheme.champagne.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    size: 24,
                    color: AppTheme.champagne.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Henüz yayınevi denemesi yok',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppTheme.onPage(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sağ alttaki «Deneme Ekle» ile kayıt oluşturun.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.mutedOnPage(context),
                    height: 1.4,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          )
        else
          ...exams.map(
            (exam) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ExamDetailCard(
                exam: exam,
                onDelete: () {
                  unawaited(
                    PracticeExamService.instance.deleteExam(exam.id).then((_) {
                      onRefresh();
                    }),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _ExamDetailCard extends StatelessWidget {
  final PracticeExamModel exam;
  final VoidCallback onDelete;

  const _ExamDetailCard({required this.exam, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return ExamPremiumCardShell(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(18, 4, 12, 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.champagne.withValues(alpha: 0.14),
              border: Border.all(
                color: AppTheme.champagne.withValues(alpha: 0.35),
              ),
            ),
            child: Icon(
              Icons.menu_book_outlined,
              size: 20,
              color: AppTheme.champagne.withValues(alpha: 0.95),
            ),
          ),
          title: Text(
            exam.denemeAdi,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppTheme.onPage(context),
            ),
          ),
          subtitle: Text(
            '${exam.yayinEvi} · ${DateFormat('d MMM yyyy', 'tr').format(exam.tarih)}',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.mutedOnPage(context),
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.champagne.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppTheme.champagne.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              '${exam.toplamNet.toStringAsFixed(1)} net',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: AppTheme.champagne,
              ),
            ),
          ),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NetStat(
                  title: 'GY',
                  net: exam.genelYetenekNet,
                  icon: Icons.psychology_outlined,
                ),
                _NetStat(
                  title: 'GK',
                  net: exam.genelKulturNet,
                  icon: Icons.public_outlined,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...exam.dersSonuclari.entries.map(
              (entry) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  entry.key,
                  style: GoogleFonts.inter(fontSize: 13),
                ),
                trailing: Text(
                  '${entry.value.net.toStringAsFixed(1)} net '
                  '(D${entry.value.dogru} Y${entry.value.yanlis} '
                  'B${entry.value.bos})',
                  style: GoogleFonts.inter(fontSize: 12),
                ),
              ),
            ),
            if (exam.notlar != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Not: ${exam.notlar}',
                  style: GoogleFonts.inter(fontSize: 12),
                ),
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
    );
  }
}

class _NetStat extends StatelessWidget {
  final String title;
  final double net;
  final IconData icon;

  const _NetStat({
    required this.title,
    required this.net,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.champagne, size: 22),
        const SizedBox(height: 8),
        Text(title, style: GoogleFonts.inter(fontSize: 12)),
        Text(
          net.toStringAsFixed(1),
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.onPage(context),
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
    );
  }
}
