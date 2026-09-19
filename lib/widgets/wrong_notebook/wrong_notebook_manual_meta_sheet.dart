import 'package:flutter/material.dart';

import '../../data/kpss_curriculum.dart';
import '../../theme/app_theme.dart';
import '../countdown_widget.dart';

/// Manuel foto soru için ders / konu / not formu.
/// Ders ve konu zorunlu; konular seçilen derse göre gelir.
class WrongNotebookManualMetaSheet {
  WrongNotebookManualMetaSheet._();

  static Future<(String subject, String topic, String? note)?> show(
    BuildContext context, {
    required KpssType kpssType,
  }) {
    return showDialog<(String, String, String?)>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _ManualMetaDialog(
          kpssType: kpssType,
          onCancel: () => Navigator.of(dialogContext).pop(null),
          onSave: (subject, topic, note) {
            Navigator.of(dialogContext).pop((subject, topic, note));
          },
        );
      },
    );
  }
}

class _ManualMetaDialog extends StatefulWidget {
  final KpssType kpssType;
  final VoidCallback onCancel;
  final void Function(String subject, String topic, String? note) onSave;

  const _ManualMetaDialog({
    required this.kpssType,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<_ManualMetaDialog> createState() => _ManualMetaDialogState();
}

class _ManualMetaDialogState extends State<_ManualMetaDialog> {
  final _noteCtrl = TextEditingController();
  String? _subjectId;
  String? _topicId;
  String? _error;

  List<KpssSubject> get _subjects =>
      KpssCurriculum.subjectsFor(widget.kpssType);

  KpssSubject? get _selectedSubject {
    final id = _subjectId;
    if (id == null) return null;
    for (final s in _subjects) {
      if (s.id == id) return s;
    }
    return null;
  }

  List<KpssTopic> get _topics => _selectedSubject?.topics ?? const [];

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  void _onSubjectChanged(String? id) {
    setState(() {
      _subjectId = id;
      _topicId = null;
      _error = null;
    });
  }

  void _onTopicChanged(String? id) {
    setState(() {
      _topicId = id;
      _error = null;
    });
  }

  void _submit() {
    final subject = _selectedSubject;
    final topicId = _topicId;
    if (subject == null) {
      setState(() => _error = 'Ders seçmelisiniz.');
      return;
    }
    if (topicId == null || topicId.isEmpty) {
      setState(() => _error = 'Konu seçmelisiniz.');
      return;
    }
    KpssTopic? topic;
    for (final t in subject.topics) {
      if (t.id == topicId) {
        topic = t;
        break;
      }
    }
    if (topic == null) {
      setState(() => _error = 'Konu seçmelisiniz.');
      return;
    }
    final note = _noteCtrl.text.trim();
    widget.onSave(
      subject.name,
      topic.name,
      note.isEmpty ? null : note,
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    required bool enabled,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: enabled
          ? AppTheme.champagne.withValues(alpha: 0.05)
          : AppTheme.ink.withValues(alpha: 0.04),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: AppTheme.ink.withValues(alpha: 0.72),
      ),
      hintStyle: TextStyle(
        color: AppTheme.slate.withValues(alpha: 0.55),
        fontSize: 13,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AppTheme.champagne.withValues(alpha: 0.28),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.champagne, width: 1.4),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AppTheme.ink.withValues(alpha: 0.08),
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final on = AppTheme.onPage(context);
    final muted = AppTheme.mutedOnPage(context);
    final card = AppTheme.surfaceCard(context);
    final topicsEnabled = _selectedSubject != null && _topics.isNotEmpty;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: card,
          border: Border.all(
            color: AppTheme.champagne.withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.ink.withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.ink.withValues(alpha: 0.04),
                    AppTheme.champagne.withValues(alpha: 0.12),
                  ],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      color: AppTheme.champagne.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        AppTheme.champagneLight,
                        AppTheme.champagne,
                        Color(0xFFB8925A),
                      ],
                    ).createShader(bounds),
                    child: const Text(
                      'YANLIŞ SORULARIM',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ders ve konu seçimi zorunludur',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: muted,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _subjectId,
                      isExpanded: true,
                      dropdownColor: card,
                      icon: Icon(
                        Icons.expand_more_rounded,
                        color: AppTheme.champagne.withValues(alpha: 0.9),
                      ),
                      decoration: _fieldDecoration(
                        label: 'Ders *',
                        hint: 'Ders seçin',
                        enabled: true,
                      ),
                      items: _subjects
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(
                                s.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: on,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _onSubjectChanged,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey('topic_$_subjectId'),
                      initialValue: _topicId,
                      isExpanded: true,
                      dropdownColor: card,
                      icon: Icon(
                        Icons.expand_more_rounded,
                        color: topicsEnabled
                            ? AppTheme.champagne.withValues(alpha: 0.9)
                            : muted,
                      ),
                      decoration: _fieldDecoration(
                        label: 'Konu *',
                        hint: topicsEnabled
                            ? 'Konu seçin'
                            : 'Önce ders seçin',
                        enabled: topicsEnabled,
                      ),
                      items: _topics
                          .map(
                            (t) => DropdownMenuItem(
                              value: t.id,
                              child: Text(
                                t.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: on,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: topicsEnabled ? _onTopicChanged : null,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _noteCtrl,
                      minLines: 2,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(color: on, fontWeight: FontWeight.w500),
                      decoration: _fieldDecoration(
                        label: 'Not (opsiyonel)',
                        hint: 'Burada şu kuralı unuttum...',
                        enabled: true,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFE85D4C),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: widget.onCancel,
                      style: TextButton.styleFrom(
                        foregroundColor: muted,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Vazgeç',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.champagne,
                        foregroundColor: AppTheme.ink,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Kaydet',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
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
