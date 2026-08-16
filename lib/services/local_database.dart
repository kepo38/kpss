import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/practice_exam_model.dart';
import '../models/wrong_notebook_model.dart';
import 'storage_constants.dart';

/// Deneme ve yanlış defteri verileri için SQLite katmanı.
/// Web önizlemesinde SharedPreferences kullanılır.
/// 365 günden eski kayıtlar otomatik temizlenir.
class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  Database? _db;
  SharedPreferences? _prefs;

  Future<void> initialize() async {
    if (_db != null || _prefs != null) return;

    if (kIsWeb) {
      _prefs = await SharedPreferences.getInstance();
      await purgeExpired();
      return;
    }

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, StorageConstants.dbName);

    _db = await openDatabase(
      path,
      version: StorageConstants.dbVersion,
      onCreate: _onCreate,
    );

    await purgeExpired();
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ${StorageConstants.tablePracticeExams} (
        id TEXT PRIMARY KEY,
        deneme_adi TEXT NOT NULL,
        yayin_evi TEXT NOT NULL,
        tarih TEXT NOT NULL,
        ders_sonuclari TEXT NOT NULL,
        notlar TEXT,
        kayit_tarihi TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${StorageConstants.tableWrongNotebook} (
        id TEXT PRIMARY KEY,
        ders_adi TEXT NOT NULL,
        konu_adi TEXT NOT NULL,
        soru_notu TEXT NOT NULL,
        cozum_notu TEXT NOT NULL,
        yayin_evi TEXT,
        deneme_adi TEXT,
        tekrar_periyodu TEXT NOT NULL,
        sonraki_tekrar TEXT NOT NULL,
        hatirlatma_saati INTEGER NOT NULL,
        hatirlatma_dakikasi INTEGER NOT NULL,
        olusturma_tarihi TEXT NOT NULL,
        tekrar_sayisi INTEGER NOT NULL DEFAULT 0,
        arsivlendi INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_exams_tarih ON ${StorageConstants.tablePracticeExams}(tarih)',
    );
    await db.execute(
      'CREATE INDEX idx_notebook_olusturma ON ${StorageConstants.tableWrongNotebook}(olusturma_tarihi)',
    );
  }

  DateTime get _retentionCutoff => DateTime.now().subtract(
        const Duration(days: StorageConstants.retentionDays),
      );

  /// 1 yıldan eski kayıtları siler.
  Future<int> purgeExpired() async {
    if (kIsWeb) {
      final cutoff = _retentionCutoff;
      final exams = await _readWebExams();
      final notebook = await _readWebNotebook();
      final keptExams =
          exams.where((e) => !e.tarih.isBefore(cutoff)).toList();
      final keptNotebook = notebook
          .where((e) => !e.olusturmaTarihi.isBefore(cutoff))
          .toList();
      final deleted =
          (exams.length - keptExams.length) + (notebook.length - keptNotebook.length);
      if (deleted > 0) {
        await _writeWebExams(keptExams);
        await _writeWebNotebook(keptNotebook);
      }
      return deleted;
    }

    final db = _db;
    if (db == null) return 0;

    final cutoff = _retentionCutoff.toIso8601String();

    final examsDeleted = await db.delete(
      StorageConstants.tablePracticeExams,
      where: 'tarih < ?',
      whereArgs: [cutoff],
    );

    final notebookDeleted = await db.delete(
      StorageConstants.tableWrongNotebook,
      where: 'olusturma_tarihi < ?',
      whereArgs: [cutoff],
    );

    return examsDeleted + notebookDeleted;
  }

  // ── Deneme sınavları ──────────────────────────────────────────────

  Future<List<PracticeExamModel>> getAllExams() async {
    if (kIsWeb) {
      final exams = await _readWebExams();
      exams.sort((a, b) => b.tarih.compareTo(a.tarih));
      return exams;
    }

    final db = _db!;
    final rows = await db.query(
      StorageConstants.tablePracticeExams,
      orderBy: 'tarih DESC',
    );
    return rows.map(_examFromRow).toList();
  }

  Future<void> insertExam(PracticeExamModel exam) async {
    if (kIsWeb) {
      final exams = await _readWebExams();
      exams.removeWhere((e) => e.id == exam.id);
      exams.add(exam);
      await _writeWebExams(exams);
      return;
    }

    final db = _db!;
    await db.insert(
      StorageConstants.tablePracticeExams,
      _examToRow(exam),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteExam(String id) async {
    if (kIsWeb) {
      final exams = await _readWebExams();
      exams.removeWhere((e) => e.id == id);
      await _writeWebExams(exams);
      return;
    }

    final db = _db!;
    await db.delete(
      StorageConstants.tablePracticeExams,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<bool> isExamTableEmpty() async {
    if (kIsWeb) {
      return (await _readWebExams()).isEmpty;
    }

    final db = _db!;
    final count = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM ${StorageConstants.tablePracticeExams}',
      ),
    );
    return (count ?? 0) == 0;
  }

  Map<String, Object?> _examToRow(PracticeExamModel exam) => {
        'id': exam.id,
        'deneme_adi': exam.denemeAdi,
        'yayin_evi': exam.yayinEvi,
        'tarih': exam.tarih.toIso8601String(),
        'ders_sonuclari': jsonEncode(
          exam.dersSonuclari.map((k, v) => MapEntry(k, v.toJson())),
        ),
        'notlar': exam.notlar,
        'kayit_tarihi': DateTime.now().toIso8601String(),
      };

  PracticeExamModel _examFromRow(Map<String, Object?> row) {
    final dersJson =
        jsonDecode(row['ders_sonuclari']! as String) as Map<String, dynamic>;
    return PracticeExamModel(
      id: row['id']! as String,
      denemeAdi: row['deneme_adi']! as String,
      yayinEvi: row['yayin_evi']! as String,
      tarih: DateTime.parse(row['tarih']! as String),
      dersSonuclari: dersJson.map(
        (key, value) =>
            MapEntry(key, DersSonuc.fromJson(value as Map<String, dynamic>)),
      ),
      notlar: row['notlar'] as String?,
    );
  }

  // ── Yanlış defteri ────────────────────────────────────────────────

  Future<List<WrongNotebookEntry>> getAllNotebookEntries() async {
    if (kIsWeb) {
      final entries = await _readWebNotebook();
      entries.sort(
        (a, b) => a.sonrakiTekrarTarihi.compareTo(b.sonrakiTekrarTarihi),
      );
      return entries;
    }

    final db = _db!;
    final rows = await db.query(
      StorageConstants.tableWrongNotebook,
      orderBy: 'sonraki_tekrar ASC',
    );
    return rows.map(_notebookFromRow).toList();
  }

  Future<void> insertNotebookEntry(WrongNotebookEntry entry) async {
    if (kIsWeb) {
      final entries = await _readWebNotebook();
      entries.removeWhere((e) => e.id == entry.id);
      entries.add(entry);
      await _writeWebNotebook(entries);
      return;
    }

    final db = _db!;
    await db.insert(
      StorageConstants.tableWrongNotebook,
      _notebookToRow(entry),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateNotebookEntry(WrongNotebookEntry entry) async {
    if (kIsWeb) {
      final entries = await _readWebNotebook();
      final index = entries.indexWhere((e) => e.id == entry.id);
      if (index >= 0) {
        entries[index] = entry;
        await _writeWebNotebook(entries);
      }
      return;
    }

    final db = _db!;
    await db.update(
      StorageConstants.tableWrongNotebook,
      _notebookToRow(entry),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> deleteNotebookEntry(String id) async {
    if (kIsWeb) {
      final entries = await _readWebNotebook();
      entries.removeWhere((e) => e.id == id);
      await _writeWebNotebook(entries);
      return;
    }

    final db = _db!;
    await db.delete(
      StorageConstants.tableWrongNotebook,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<bool> isNotebookTableEmpty() async {
    if (kIsWeb) {
      return (await _readWebNotebook()).isEmpty;
    }

    final db = _db!;
    final count = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM ${StorageConstants.tableWrongNotebook}',
      ),
    );
    return (count ?? 0) == 0;
  }

  Future<List<PracticeExamModel>> _readWebExams() async {
    final raw = _prefs!.getString(StorageConstants.webExamsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((item) => PracticeExamModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }

  Future<void> _writeWebExams(List<PracticeExamModel> exams) async {
    final encoded = jsonEncode(exams.map((e) => e.toJson()).toList());
    await _prefs!.setString(StorageConstants.webExamsKey, encoded);
  }

  Future<List<WrongNotebookEntry>> _readWebNotebook() async {
    final raw = _prefs!.getString(StorageConstants.webNotebookKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((item) => WrongNotebookEntry.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }

  Future<void> _writeWebNotebook(List<WrongNotebookEntry> entries) async {
    final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
    await _prefs!.setString(StorageConstants.webNotebookKey, encoded);
  }

  Map<String, Object?> _notebookToRow(WrongNotebookEntry entry) => {
        'id': entry.id,
        'ders_adi': entry.dersAdi,
        'konu_adi': entry.konuAdi,
        'soru_notu': entry.soruNotu,
        'cozum_notu': entry.cozumNotu,
        'yayin_evi': entry.yayinEvi,
        'deneme_adi': entry.denemeAdi,
        'tekrar_periyodu': entry.tekrarPeriyodu.name,
        'sonraki_tekrar': entry.sonrakiTekrarTarihi.toIso8601String(),
        'hatirlatma_saati': entry.hatirlatmaSaati,
        'hatirlatma_dakikasi': entry.hatirlatmaDakikasi,
        'olusturma_tarihi': entry.olusturmaTarihi.toIso8601String(),
        'tekrar_sayisi': entry.tekrarSayisi,
        'arsivlendi': entry.arsivlendi ? 1 : 0,
      };

  WrongNotebookEntry _notebookFromRow(Map<String, Object?> row) {
    return WrongNotebookEntry(
      id: row['id']! as String,
      dersAdi: row['ders_adi']! as String,
      konuAdi: row['konu_adi']! as String,
      soruNotu: row['soru_notu']! as String,
      cozumNotu: row['cozum_notu']! as String,
      yayinEvi: row['yayin_evi'] as String?,
      denemeAdi: row['deneme_adi'] as String?,
      tekrarPeriyodu: RepetitionPeriod.values.byName(
        row['tekrar_periyodu']! as String,
      ),
      sonrakiTekrarTarihi:
          DateTime.parse(row['sonraki_tekrar']! as String),
      hatirlatmaSaati: row['hatirlatma_saati']! as int,
      hatirlatmaDakikasi: row['hatirlatma_dakikasi']! as int,
      olusturmaTarihi: DateTime.parse(row['olusturma_tarihi']! as String),
      tekrarSayisi: row['tekrar_sayisi']! as int,
      arsivlendi: (row['arsivlendi']! as int) == 1,
    );
  }
}
