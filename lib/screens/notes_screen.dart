import 'package:flutter/material.dart';

import '../data/kpss_curriculum.dart';
import '../models/study_note.dart';
import '../services/notes_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';
import '../widgets/countdown_widget.dart';

class NotesScreen extends StatefulWidget {
  final KpssType kpssType;

  const NotesScreen({super.key, required this.kpssType});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  String? _selectedSubjectId;

  @override
  void initState() {
    super.initState();
    NotesService.instance.initialize();
  }

  List<KpssSubject> get _subjects =>
      KpssCurriculum.subjectsFor(widget.kpssType);

  Future<void> _editNote([StudyNote? note]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _NoteEditorSheet(
        subjects: _subjects,
        note: note,
        initialSubjectId: _selectedSubjectId,
      ),
    );
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _deleteNote(StudyNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard(context),
        title: Text(
          'Not silinsin mi?',
          style: TextStyle(color: AppTheme.onPage(context)),
        ),
        content: Text(
          'Bu işlem geri alınamaz.',
          style: TextStyle(color: AppTheme.mutedOnPage(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed == true) await NotesService.instance.delete(note.id);
  }

  @override
  Widget build(BuildContext context) {
    final onPage = AppTheme.onPage(context);

    return ListenableBuilder(
      listenable: NotesService.instance,
      builder: (context, _) {
        final notes = NotesService.instance.forSubject(_selectedSubjectId);
        return Scaffold(
          backgroundColor: AppTheme.page(context),
          appBar: AppBar(
            leading: const AppBackButton(),
            backgroundColor: AppTheme.page(context),
            foregroundColor: onPage,
            title: Text(
              'Notlarım',
              style: TextStyle(
                fontFamily: 'serif',
                fontWeight: FontWeight.w700,
                color: onPage,
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _editNote(),
            backgroundColor: AppTheme.champagne,
            foregroundColor: AppTheme.ink,
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Yeni not'),
          ),
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.pageTop(context),
                  AppTheme.page(context),
                  AppTheme.pageDeep(context),
                ],
              ),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    children: [
                      _SubjectTab(
                        label: 'Tümü',
                        count: NotesService.instance.count,
                        selected: _selectedSubjectId == null,
                        onTap: () => setState(() => _selectedSubjectId = null),
                      ),
                      for (final subject in _subjects)
                        _SubjectTab(
                          label: subject.name,
                          count: NotesService.instance
                              .countForSubject(subject.id),
                          selected: _selectedSubjectId == subject.id,
                          onTap: () => setState(
                            () => _selectedSubjectId = subject.id,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: notes.isEmpty
                      ? _EmptyNotes(onCreate: () => _editNote())
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
                          itemCount: notes.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final note = notes[index];
                            return _NoteCard(
                              note: note,
                              onTap: () => _editNote(note),
                              onDelete: () => _deleteNote(note),
                            );
                          },
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

class _SubjectTab extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _SubjectTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onPage = AppTheme.onPage(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected
            ? AppTheme.champagne.withValues(alpha: 0.18)
            : AppTheme.surfaceCard(context),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? AppTheme.champagne
                    : AppTheme.hairline(context),
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Text(
              '$label ($count)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? AppTheme.champagne : onPage,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyNotes extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyNotes({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final onPage = AppTheme.onPage(context);
    final muted = AppTheme.mutedOnPage(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.note_alt_outlined,
              size: 72,
              color: muted.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz not eklenmemiş',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: onPage,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Konu çalışırken önemli bilgileri buraya kaydedin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('İlk notu ekle'),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.champagne.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.champagne.withValues(alpha: 0.40),
                ),
              ),
              child: Text(
                'Notlar cihazınızda saklanır; uygulama verisi silinirse kaybolur.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: onPage.withValues(alpha: 0.82),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final StudyNote note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final onPage = AppTheme.onPage(context);
    final muted = AppTheme.mutedOnPage(context);

    return Material(
      color: AppTheme.surfaceCard(context),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        onLongPress: onDelete,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.hairline(context)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.subjectName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.champagne,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: onPage,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      note.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: muted, height: 1.35),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) =>
                    value == 'delete' ? onDelete() : onTap(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                  PopupMenuItem(value: 'delete', child: Text('Sil')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteEditorSheet extends StatefulWidget {
  final List<KpssSubject> subjects;
  final StudyNote? note;
  final String? initialSubjectId;

  const _NoteEditorSheet({
    required this.subjects,
    this.note,
    this.initialSubjectId,
  });

  @override
  State<_NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<_NoteEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late String _subjectId;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.note?.title ?? '');
    _body = TextEditingController(text: widget.note?.body ?? '');
    _subjectId = widget.note?.subjectId ??
        widget.initialSubjectId ??
        widget.subjects.first.id;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) return;
    final subject = widget.subjects.firstWhere((item) => item.id == _subjectId);
    final now = DateTime.now();
    await NotesService.instance.save(
      StudyNote(
        id: widget.note?.id ?? 'note_${now.microsecondsSinceEpoch}',
        subjectId: subject.id,
        subjectName: subject.name,
        title: _title.text.trim(),
        body: _body.text.trim(),
        createdAt: widget.note?.createdAt ?? now,
        updatedAt: now,
      ),
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final onPage = AppTheme.onPage(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.note == null ? 'Yeni not' : 'Notu düzenle',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: onPage,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _subjectId,
            dropdownColor: AppTheme.surfaceCard(context),
            decoration: const InputDecoration(labelText: 'Ders'),
            items: widget.subjects
                .map(
                  (subject) => DropdownMenuItem(
                    value: subject.id,
                    child: Text(
                      subject.name,
                      style: TextStyle(color: onPage),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _subjectId = value!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(color: onPage),
            decoration: const InputDecoration(labelText: 'Başlık'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            minLines: 5,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(color: onPage),
            decoration: const InputDecoration(
              labelText: 'Notunuz',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.champagne,
              foregroundColor: AppTheme.ink,
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}
