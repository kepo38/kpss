import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/manual_question_model.dart';
import '../services/manual_question_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';
import '../widgets/wrong_notebook/wrong_notebook_manual_card.dart';
import '../widgets/wrong_notebook/wrong_notebook_subject_filter.dart';
import '../widgets/wrong_notebook/wrong_notebook_utils.dart';

/// Kitaptan foto ile eklenen manuel yanlış sorular.
class WrongNotebookManualScreen extends StatefulWidget {
  const WrongNotebookManualScreen({super.key});

  static const pink = Color(0xFFE879A9);
  static const pinkDeep = Color(0xFFDB4F86);
  static const pinkLight = Color(0xFFFBCFE8);

  @override
  State<WrongNotebookManualScreen> createState() =>
      _WrongNotebookManualScreenState();
}

class _WrongNotebookManualScreenState extends State<WrongNotebookManualScreen> {
  String? _subjectFilter;

  List<(String subject, int count)> _subjectSummary(
    List<ManualQuestionModel> items,
  ) {
    final counts = <String, int>{};
    for (final item in items) {
      final label = item.subjectLabel;
      counts[label] = (counts[label] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => (e.key, e.value)).toList();
  }

  List<ManualQuestionModel> _filtered(
    List<ManualQuestionModel> items,
  ) {
    if (_subjectFilter == null) return items;
    return items
        .where((item) => item.subjectLabel == _subjectFilter)
        .toList();
  }

  Map<String, List<ManualQuestionModel>> _groupBySubject(
    List<ManualQuestionModel> items,
  ) {
    final grouped = <String, List<ManualQuestionModel>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.subjectLabel, () => []).add(item);
    }
    final keys = grouped.keys.toList()..sort();
    return {for (final k in keys) k: grouped[k]!};
  }

  Future<void> _confirmRemove(ManualQuestionModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceCard(context),
          title: const Text(
            'Soruyu kaldır?',
            style: TextStyle(
              fontFamily: 'serif',
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Fotoğraf ve kart cihazından silinecek.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppTheme.mutedOnPage(context),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: WrongNotebookManualScreen.pinkDeep,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Kaldır',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await ManualQuestionService.instance.remove(item.id);
  }

  void _openImage(String imagePath) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog.fullscreen(
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Image.file(File(imagePath)),
                ),
              ),
              Positioned(
                top: 28,
                left: 16,
                child: IconButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ManualQuestionService.instance,
      builder: (context, _) {
        final all = ManualQuestionService.instance.items;
        final subjects = _subjectSummary(all);
        final filtered = _filtered(all);
        final grouped = _groupBySubject(filtered);

        if (_subjectFilter != null &&
            !subjects.any((s) => s.$1 == _subjectFilter)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _subjectFilter = null);
          });
        }

        return Scaffold(
          backgroundColor: AppTheme.page(context),
          appBar: AppBar(
            backgroundColor: AppTheme.page(context),
            foregroundColor: AppTheme.onPage(context),
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: const AppBackButton(),
            title: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  WrongNotebookManualScreen.pinkDeep,
                  WrongNotebookManualScreen.pink,
                  Color(0xFFC73672),
                ],
              ).createShader(bounds),
              child: const Text(
                'Kitaptaki Yanlışlarım',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: Colors.white,
                ),
              ),
            ),
            centerTitle: true,
          ),
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  WrongNotebookManualScreen.pinkLight.withValues(alpha: 0.18),
                  AppTheme.page(context),
                  AppTheme.pageDeep(context),
                ],
              ),
            ),
            child: all.isEmpty
                ? _EmptyState()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeroStrip(count: all.length, subjectCount: subjects.length),
                      WrongNotebookSubjectFilter(
                        subjects: subjects,
                        totalCount: all.length,
                        selectedSubject: _subjectFilter,
                        minSubjectsToShow: 1,
                        defaultAccent: WrongNotebookManualScreen.pinkDeep,
                        onChanged: (value) =>
                            setState(() => _subjectFilter = value),
                      ),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(28),
                                  child: Text(
                                    'Bu derste kitap sorusu yok.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppTheme.mutedOnPage(context),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              )
                            : ListView(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 4, 16, 20),
                                children: [
                                  for (final entry in grouped.entries) ...[
                                    _SubjectHeader(
                                      subject: entry.key,
                                      count: entry.value.length,
                                      accent: wrongNotebookSubjectAccent(
                                        entry.key,
                                      ),
                                    ),
                                    for (final item in entry.value)
                                      WrongNotebookManualCard(
                                        item: item,
                                        onTapImage: () =>
                                            _openImage(item.imagePath),
                                        onRemove: () => _confirmRemove(item),
                                        onStatusChanged: (status) {
                                          unawaited(
                                            ManualQuestionService.instance
                                                .markStatus(item.id, status),
                                          );
                                        },
                                      ),
                                  ],
                                ],
                              ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _HeroStrip extends StatelessWidget {
  final int count;
  final int subjectCount;

  const _HeroStrip({
    required this.count,
    required this.subjectCount,
  });

  @override
  Widget build(BuildContext context) {
    final on = AppTheme.onPage(context);
    final muted = AppTheme.mutedOnPage(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              WrongNotebookManualScreen.pinkLight.withValues(alpha: 0.42),
              Colors.white.withValues(alpha: 0.88),
            ],
          ),
          border: Border.all(
            color: WrongNotebookManualScreen.pink.withValues(alpha: 0.38),
          ),
          boxShadow: [
            BoxShadow(
              color: WrongNotebookManualScreen.pinkDeep.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: WrongNotebookManualScreen.pinkDeep.withValues(alpha: 0.12),
                border: Border.all(
                  color: WrongNotebookManualScreen.pink.withValues(alpha: 0.35),
                ),
              ),
              child: const Icon(
                Icons.photo_library_rounded,
                color: WrongNotebookManualScreen.pinkDeep,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count soru kayıtlı',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: on,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$subjectCount derste dağılıyor',
                    style: TextStyle(
                      fontSize: 12,
                      color: muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectHeader extends StatelessWidget {
  final String subject;
  final int count;
  final Color accent;

  const _SubjectHeader({
    required this.subject,
    required this.count,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              color: accent,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              subject,
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.onPage(context),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              color: WrongNotebookManualScreen.pinkDeep.withValues(alpha: 0.12),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: WrongNotebookManualScreen.pinkDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.mutedOnPage(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: WrongNotebookManualScreen.pinkLight.withValues(alpha: 0.45),
                border: Border.all(
                  color: WrongNotebookManualScreen.pink.withValues(alpha: 0.35),
                ),
              ),
              child: const Icon(
                Icons.menu_book_outlined,
                size: 28,
                color: WrongNotebookManualScreen.pinkDeep,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz kitap sorusu eklemedin',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.onPage(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Yanlış Defterim ekranındaki SORU EKLE ile '
              'fotoğraf çekip burada toplayabilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
