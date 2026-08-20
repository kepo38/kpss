import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/manual_question_model.dart';
import 'auth_service.dart';
import 'local_database.dart';

class ManualQuestionService extends ChangeNotifier {
  ManualQuestionService._();
  static final ManualQuestionService instance = ManualQuestionService._();

  final List<ManualQuestionModel> _items = [];
  bool _initialized = false;
  String? _activeUserId;

  List<ManualQuestionModel> get items => List.unmodifiable(_items);

  String get _userId => AuthService.instance.user?.id ?? 'unknown';

  Future<void> initialize() async {
    if (_initialized) return;
    await LocalDatabase.instance.initialize();
    await _loadForCurrentUser();
    _initialized = true;
    notifyListeners();
  }

  Future<void> onUserSessionChanged() async {
    if (!_initialized) {
      await initialize();
      return;
    }
    final previousUserId = _activeUserId;
    final userId = _userId;
    if (previousUserId == userId) return;
    if (_shouldMigrateGuestRows(previousUserId, userId)) {
      await LocalDatabase.instance.reassignManualWrongQuestionsUser(
        fromUserId: previousUserId!,
        toUserId: userId,
      );
    }
    await _loadForCurrentUser();
    notifyListeners();
  }

  Future<void> _loadForCurrentUser() async {
    final userId = _userId;
    final rows =
        await LocalDatabase.instance.getManualWrongQuestionsForUser(userId);
    _items
      ..clear()
      ..addAll(rows);
    _activeUserId = userId;
  }

  Future<ManualQuestionModel?> addFromImage({
    required File sourceFile,
    String? subject,
    String? topic,
    String? note,
  }) async {
    await initialize();
    if (kIsWeb) return null;
    if (!await sourceFile.exists()) return null;

    final now = DateTime.now();
    final id = 'manual_${now.microsecondsSinceEpoch}';
    final userId = _userId;
    final cleanSubject = _cleanText(subject);
    final cleanTopic = _cleanText(topic);
    final cleanNote = _cleanText(note);
    final copiedPath = await _copyToPrivateFolder(
      sourceFile,
      userId: userId,
      id: id,
    );
    final item = ManualQuestionModel(
      id: id,
      userId: userId,
      imagePath: copiedPath,
      subject: cleanSubject,
      topic: cleanTopic,
      note: cleanNote,
      status: ManualQuestionStatus.fresh,
      createdAt: now,
      updatedAt: now,
    );
    await LocalDatabase.instance.upsertManualWrongQuestion(item);
    _items.insert(0, item);
    notifyListeners();
    return item;
  }

  Future<void> markStatus(String id, ManualQuestionStatus status) async {
    await initialize();
    final current = _itemById(id);
    if (current == null) return;
    final updated = current.copyWith(
      status: status,
      updatedAt: DateTime.now(),
    );
    await LocalDatabase.instance.upsertManualWrongQuestion(updated);
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    _items[idx] = updated;
    notifyListeners();
  }

  Future<void> updateMeta({
    required String id,
    String? subject,
    String? topic,
    String? note,
  }) async {
    await initialize();
    final current = _itemById(id);
    if (current == null) return;
    final updated = current.copyWith(
      subject: _cleanText(subject),
      topic: _cleanText(topic),
      note: _cleanText(note),
      updatedAt: DateTime.now(),
    );
    await LocalDatabase.instance.upsertManualWrongQuestion(updated);
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    _items[idx] = updated;
    notifyListeners();
  }

  Future<void> updateAnnotations({
    required String id,
    String? annotationJson,
  }) async {
    await initialize();
    final current = _itemById(id);
    if (current == null) return;
    final cleaned = annotationJson?.trim();
    final updated = current.copyWith(
      annotationJson: cleaned,
      clearAnnotation: cleaned == null || cleaned.isEmpty || cleaned == '[]',
      updatedAt: DateTime.now(),
    );
    await LocalDatabase.instance.upsertManualWrongQuestion(updated);
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    _items[idx] = updated;
    notifyListeners();
  }

  Future<void> remove(String id) async {
    await initialize();
    final item = _itemById(id);
    if (item == null) return;
    await LocalDatabase.instance.deleteManualWrongQuestion(id);
    if (!kIsWeb) {
      final file = File(item.imagePath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {
          // Dosya silinemese de kayıt silinsin.
        }
      }
    }
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  String? _cleanText(String? raw) {
    final value = raw?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  Future<String> _copyToPrivateFolder(
    File source, {
    required String userId,
    required String id,
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(docsDir.path, 'manual_questions', userId));
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    final ext = p.extension(source.path).toLowerCase();
    final safeExt = (ext == '.png' || ext == '.webp') ? ext : '.jpg';
    final targetPath = p.join(folder.path, '$id$safeExt');
    final copied = await source.copy(targetPath);
    return copied.path;
  }

  bool _shouldMigrateGuestRows(String? fromUserId, String toUserId) {
    if (fromUserId == null || fromUserId == toUserId) return false;
    if (!AuthService.instance.hasPermanentAccount) return false;
    if (fromUserId == 'unknown' || fromUserId == 'guest-pending') return true;
    if (fromUserId.startsWith('guest-')) return true;
    // Firebase anonim → Google (id değişebilir)
    return true;
  }

  ManualQuestionModel? _itemById(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }
}
