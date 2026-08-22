import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/practice_exam_model.dart';
import '../services/practice_exam_service.dart';
import '../theme/app_theme.dart';
import 'tg_exams_section.dart';

class StatisticsExamsTab extends StatelessWidget {
  final VoidCallback onRefresh;

  const StatisticsExamsTab({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final exams = PracticeExamService.instance.allExams;
    if (exams.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TgExamsSection(onRefresh: onRefresh),
          const SizedBox(height: 24),
          const Center(child: Text('Henüz deneme kaydı yok')),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: exams.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: TgExamsSection(onRefresh: onRefresh),
          );
        }
        final exam = exams[index - 1];
        return _ExamDetailCard(
          exam: exam,
          onDelete: () {
            unawaited(
              PracticeExamService.instance.deleteExam(exam.id).then((_) {
                onRefresh();
              }),
            );
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
        title: Text(
          exam.denemeAdi,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
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
                    _NetStat(
                      title: 'GY',
                      net: exam.genelYetenekNet,
                      icon: Icons.psychology_outlined,
                      color: AppTheme.lightPrimary,
                    ),
                    _NetStat(
                      title: 'GK',
                      net: exam.genelKulturNet,
                      icon: Icons.public_outlined,
                      color: AppTheme.lightAccent,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...exam.dersSonuclari.entries.map(
                  (entry) => ListTile(
                    dense: true,
                    title: Text(entry.key),
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
        ],
      ),
    );
  }
}

class _NetStat extends StatelessWidget {
  final String title;
  final double net;
  final IconData icon;
  final Color color;

  const _NetStat({
    required this.title,
    required this.net,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
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
    );
  }
}
