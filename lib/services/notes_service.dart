import 'package:flutter/foundation.dart';

import '../models/study_note.dart';
import 'local_database.dart';

class NotesService extends ChangeNotifier {
  NotesService._();
  static final NotesService instance = NotesService._();

  final List<StudyNote> _notes = [];
  bool _initialized = false;

  List<StudyNote> get notes => List.unmodifiable(_notes);
  int get count => _notes.length;

  Future<void> initialize() async {
    if (_initialized) return;
    _notes
      ..clear()
      ..addAll(await LocalDatabase.instance.getAllStudyNotes());
    _sort();
    _initialized = true;
    notifyListeners();
  }

  List<StudyNote> forSubject(String? subjectId) => subjectId == null
      ? notes
      : _notes.where((note) => note.subjectId == subjectId).toList();

  int countForSubject(String subjectId) =>
      _notes.where((note) => note.subjectId == subjectId).length;

  Future<void> save(StudyNote note) async {
    await initialize();
    final index = _notes.indexWhere((item) => item.id == note.id);
    if (index < 0) {
      _notes.add(note);
    } else {
      _notes[index] = note;
    }
    _sort();
    await LocalDatabase.instance.upsertStudyNote(note);
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await initialize();
    _notes.removeWhere((note) => note.id == id);
    await LocalDatabase.instance.deleteStudyNote(id);
    notifyListeners();
  }

  void _sort() => _notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
}
