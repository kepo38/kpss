import 'package:flutter/material.dart';

import '../services/question_error_report_service.dart';
import '../theme/app_theme.dart';

/// AppBar aksiyonu — soruda hata bildir.
class QuestionErrorReportAction extends StatelessWidget {
  final VoidCallback? onTap;
  final bool reported;
  final bool loading;

  const QuestionErrorReportAction({
    super.key,
    required this.onTap,
    this.reported = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white54,
            ),
          ),
        ),
      );
    }

    return IconButton(
      tooltip: reported ? 'Bildirildi' : 'Soruda hata bildir',
      onPressed: onTap,
      icon: Icon(
        reported ? Icons.flag : Icons.flag_outlined,
        color: reported ? AppTheme.champagne : Colors.white70,
      ),
    );
  }
}

Future<void> showQuestionErrorReportSheet({
  required BuildContext context,
  required Future<void> Function(String category, String note) onSubmit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.inkSoft,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (sheetContext) {
      return _QuestionErrorReportSheetBody(onSubmit: onSubmit);
    },
  );
}

class _QuestionErrorReportSheetBody extends StatefulWidget {
  final Future<void> Function(String category, String note) onSubmit;

  const _QuestionErrorReportSheetBody({required this.onSubmit});

  @override
  State<_QuestionErrorReportSheetBody> createState() =>
      _QuestionErrorReportSheetBodyState();
}

class _QuestionErrorReportSheetBodyState
    extends State<_QuestionErrorReportSheetBody> {
  String _category = 'wrong_answer';
  final _noteController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(_category, _noteController.text);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + safeBottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Hata bildir',
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Bildiriminiz incelenecek sorular havuzuna düşer. '
              'Günde en fazla 1 bildirim gönderebilirsiniz.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.62),
              ),
            ),
            const SizedBox(height: 16),
            ...QuestionErrorReportService.reportCategories.map((entry) {
              final selected = _category == entry.$1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: selected
                      ? AppTheme.champagne.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: _submitting
                        ? null
                        : () => setState(() => _category = entry.$1),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? AppTheme.champagne.withValues(alpha: 0.45)
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            size: 18,
                            color: selected
                                ? AppTheme.champagneLight
                                : Colors.white38,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              entry.$2,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: Colors.white.withValues(
                                  alpha: selected ? 0.95 : 0.78,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 4),
            TextField(
              controller: _noteController,
              enabled: !_submitting,
              maxLines: 3,
              maxLength: 500,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Ek not (isteğe bağlı)',
                labelStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.champagne.withValues(alpha: 0.45),
                  ),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.champagne,
                foregroundColor: AppTheme.ink,
                minimumSize: const Size.fromHeight(48),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.ink,
                      ),
                    )
                  : const Text(
                      'Bildir',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
