import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/manual_question_model.dart';
import '../services/ad_service.dart';
import '../services/kpss_preference_service.dart';
import '../services/manual_question_service.dart';
import '../services/premium_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';
import '../widgets/wrong_notebook/manual_question_annotate_viewer.dart';
import '../widgets/wrong_notebook/wrong_notebook_header.dart';
import '../widgets/wrong_notebook/wrong_notebook_manual_card.dart';
import '../widgets/wrong_notebook/wrong_notebook_manual_meta_sheet.dart';
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
  bool _adding = false;

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
    return items.where((item) => item.subjectLabel == _subjectFilter).toList();
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

  Future<void> _addManualQuestion() async {
    if (_adding) return;
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          final surface = AppTheme.surfaceCard(sheetContext);
          final on = AppTheme.onPage(sheetContext);
          final muted = AppTheme.mutedOnPage(sheetContext);
          return Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(color: AppTheme.hairline(sheetContext)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                    child: Text(
                      'Manuel soru ekle',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: on,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.photo_camera_rounded,
                      color: AppTheme.champagne,
                    ),
                    title: Text(
                      'Kameradan çek',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: on,
                      ),
                    ),
                    subtitle: Text(
                      'Sorunun fotoğrafını çek',
                      style: TextStyle(color: muted, fontSize: 12.5),
                    ),
                    onTap: () =>
                        Navigator.of(sheetContext).pop(ImageSource.camera),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.photo_library_rounded,
                      color: AppTheme.champagne,
                    ),
                    title: Text(
                      'Galeriden seç',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: on,
                      ),
                    ),
                    subtitle: Text(
                      'Galerideki bir görseli kullan',
                      style: TextStyle(color: muted, fontSize: 12.5),
                    ),
                    onTap: () =>
                        Navigator.of(sheetContext).pop(ImageSource.gallery),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      );
      if (source == null || !mounted) return;

      // İlk foto ücretsiz; 2. ve sonrası (Pro değilse) ödüllü reklam.
      await ManualQuestionService.instance.initialize();
      final existingCount = ManualQuestionService.instance.items.length;
      if (!PremiumService.instance.isPremium && existingCount >= 1) {
        final earned = await _watchAdForExtraPhoto();
        if (!earned || !mounted) return;
      }

      setState(() => _adding = true);
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 86,
        maxWidth: 1800,
      );
      if (picked == null || !mounted) return;

      final form = await WrongNotebookManualMetaSheet.show(
        context,
        kpssType: KpssPreferenceService.instance.kpssType,
      );
      if (form == null || !mounted) return;

      final saved = await ManualQuestionService.instance.addFromImage(
        sourceFile: File(picked.path),
        subject: form.$1,
        topic: form.$2,
        note: form.$3,
      );
      if (!mounted) return;
      if (saved == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fotoğraf eklenemedi. Tekrar deneyin.')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Manuel soru deftere eklendi.')),
      );
    } on Exception catch (e) {
      debugPrint('Manual question add failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('İzin verilmedi veya işlem iptal edildi.'),
        ),
      );
    } finally {
      if (mounted && _adding) setState(() => _adding = false);
    }
  }

  /// 2. foto ve sonrası için ödüllü reklam (Pro ücretsiz).
  Future<bool> _watchAdForExtraPhoto() async {
    final dialogNavigator = Navigator.of(context, rootNavigator: true);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (_) => const PopScope(
          canPop: false,
          child: Center(
            child: Card(
              color: Color(0xFF152238),
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppTheme.champagne),
                    SizedBox(height: 16),
                    Text(
                      'Ek foto için reklam…',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final earned = await AdService.showRewardedAd(
      kind: AdRewardKind.dailyTestBonus,
    );
    if (dialogNavigator.mounted && dialogNavigator.canPop()) {
      dialogNavigator.pop();
    }

    if (!earned && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'İlk foto ücretsiz. Sonrakiler için reklamı sonuna kadar izleyin.',
          ),
        ),
      );
    }
    return earned;
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

  void _openImage(ManualQuestionModel item) {
    unawaited(ManualQuestionAnnotateViewer.open(context, item));
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WrongNotebookAddQuestionAction(
                  expanded: true,
                  loading: _adding,
                  onTap: _addManualQuestion,
                ),
                if (all.isEmpty)
                  const Expanded(child: _EmptyState())
                else ...[
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
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
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
                                    onTapImage: () => _openImage(item),
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
              ],
            ),
          ),
        );
      },
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
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              subject,
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.onPage(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                height: 1,
                color: accent,
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
                color:
                    WrongNotebookManualScreen.pinkLight.withValues(alpha: 0.45),
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
              'Yanlış Sorularını Takip Et!',
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
              'Üstteki SORU EKLE ile fotoğraf çekip burada toplayabilirsin.',
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
