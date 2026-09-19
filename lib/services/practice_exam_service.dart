import 'dart:async';

import 'local_database.dart';
import '../models/practice_exam_model.dart';
import 'gamification_service.dart';

class PracticeExamService {
  PracticeExamService._();
  static final PracticeExamService instance = PracticeExamService._();

  final List<PracticeExamModel> _exams = [];
  String? _publisherFilter;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  static const Set<String> _legacyDemoExamIds = {'e1', 'e2', 'e3', 'e4'};

  Future<void> initialize() async {
    if (_initialized) return;

    await LocalDatabase.instance.initialize();
    _exams.clear();
    _exams.addAll(await LocalDatabase.instance.getAllExams());

    // Eski örnek seed'ler (e1–e4) gerçek deneme gibi görünüp Haftalık Özet'i
    // dolduruyordu — bir kez temizle, bir daha ekleme.
    await _pruneLegacyDemoExams();

    _exams.sort((a, b) => b.tarih.compareTo(a.tarih));
    _initialized = true;
  }

  Future<void> _pruneLegacyDemoExams() async {
    final stale = _exams
        .where((e) => _legacyDemoExamIds.contains(e.id))
        .map((e) => e.id)
        .toList();
    for (final id in stale) {
      await LocalDatabase.instance.deleteExam(id);
      _exams.removeWhere((e) => e.id == id);
    }
  }

  List<PracticeExamModel> get exams {
    if (_publisherFilter == null) return List.unmodifiable(_exams);
    return _exams.where((e) => e.yayinEvi == _publisherFilter).toList();
  }

  List<PracticeExamModel> get allExams => List.unmodifiable(_exams);

  String? get publisherFilter => _publisherFilter;

  void setPublisherFilter(String? publisher) => _publisherFilter = publisher;

  Future<void> addExam(PracticeExamModel exam) async {
    await initialize();
    _exams.insert(0, exam);
    await LocalDatabase.instance.insertExam(exam);
    unawaited(
      GamificationService.instance.onPracticeExamAdded(
        totalExams: _exams.length,
      ),
    );
  }

  Future<void> deleteExam(String id) async {
    await initialize();
    _exams.removeWhere((e) => e.id == id);
    await LocalDatabase.instance.deleteExam(id);
  }

  List<double> get netTrend {
    final sorted = List<PracticeExamModel>.from(exams)
      ..sort((a, b) => a.tarih.compareTo(b.tarih));
    return sorted.map((e) => e.toplamNet).toList();
  }

  List<double> get gyTrend {
    final sorted = List<PracticeExamModel>.from(exams)
      ..sort((a, b) => a.tarih.compareTo(b.tarih));
    return sorted.map((e) => e.genelYetenekNet).toList();
  }

  List<double> get gkTrend {
    final sorted = List<PracticeExamModel>.from(exams)
      ..sort((a, b) => a.tarih.compareTo(b.tarih));
    return sorted.map((e) => e.genelKulturNet).toList();
  }

  List<String> get netTrendLabels {
    final sorted = List<PracticeExamModel>.from(exams)
      ..sort((a, b) => a.tarih.compareTo(b.tarih));
    return sorted.map((e) => e.denemeAdi).toList();
  }

  /// Ders bazli ortalama D/Y/B (ve net) — toplam degil.
  /// Yalnizca o derste kaydi olan denemeler ortalamaya dahil edilir.
  /// avgD/Y/B = sum / examCount (yuvarlanmis); net = avgD - avgY/4.
  Map<String, DersSonuc> get aggregateBySubject {
    final sumDogru = <String, int>{};
    final sumYanlis = <String, int>{};
    final sumBos = <String, int>{};
    final counts = <String, int>{};

    for (final exam in exams) {
      exam.dersSonuclari.forEach((ders, sonuc) {
        sumDogru[ders] = (sumDogru[ders] ?? 0) + sonuc.dogru;
        sumYanlis[ders] = (sumYanlis[ders] ?? 0) + sonuc.yanlis;
        sumBos[ders] = (sumBos[ders] ?? 0) + sonuc.bos;
        counts[ders] = (counts[ders] ?? 0) + 1;
      });
    }

    return {
      for (final ders in counts.keys)
        ders: DersSonuc(
          dogru: (sumDogru[ders]! / counts[ders]!).round(),
          yanlis: (sumYanlis[ders]! / counts[ders]!).round(),
          bos: (sumBos[ders]! / counts[ders]!).round(),
        ),
    };
  }

  List<PublisherStats> get publisherStats {
    final grouped = <String, List<PracticeExamModel>>{};
    for (final exam in _exams) {
      grouped.putIfAbsent(exam.yayinEvi, () => []).add(exam);
    }

    return grouped.entries.map((entry) {
      final list = entry.value;
      final nets = list.map((e) => e.toplamNet).toList();
      final gy = list.map((e) => e.genelYetenekNet).toList();
      final gk = list.map((e) => e.genelKulturNet).toList();
      return PublisherStats(
        yayinEvi: entry.key,
        denemeSayisi: list.length,
        ortalamaNet: nets.reduce((a, b) => a + b) / nets.length,
        enYuksekNet: nets.reduce((a, b) => a > b ? a : b),
        ortalamaGy: gy.reduce((a, b) => a + b) / gy.length,
        ortalamaGk: gk.reduce((a, b) => a + b) / gk.length,
      );
    }).toList()
      ..sort((a, b) => b.ortalamaNet.compareTo(a.ortalamaNet));
  }

  WeeklyPerformanceSummary get weeklySummary {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final startDay = DateTime(weekStart.year, weekStart.month, weekStart.day);

    final thisWeek = _exams.where((e) => !e.tarih.isBefore(startDay)).toList();
    final lastWeekEnd = startDay.subtract(const Duration(days: 1));
    final lastWeekStart = lastWeekEnd.subtract(const Duration(days: 6));
    final lastWeek = _exams
        .where((e) =>
            !e.tarih.isBefore(lastWeekStart) && !e.tarih.isAfter(lastWeekEnd))
        .toList();

    final thisAvg = thisWeek.isEmpty
        ? 0.0
        : thisWeek.map((e) => e.toplamNet).reduce((a, b) => a + b) /
            thisWeek.length;
    final lastAvg = lastWeek.isEmpty
        ? 0.0
        : lastWeek.map((e) => e.toplamNet).reduce((a, b) => a + b) /
            lastWeek.length;

    final double? netDegisim =
        thisWeek.isNotEmpty && lastWeek.isNotEmpty ? thisAvg - lastAvg : null;

    final bySubject = aggregateBySubject;
    String strongest = '-';
    String weakest = '-';
    if (bySubject.isNotEmpty) {
      final sorted = bySubject.entries.toList()
        ..sort((a, b) => b.value.net.compareTo(a.value.net));
      strongest = sorted.first.key;
      weakest = sorted.last.key;
    }

    return WeeklyPerformanceSummary(
      denemeSayisi: thisWeek.length,
      ortalamaNet: thisAvg,
      netDegisim: netDegisim,
      tekrarBekleyenSoru: 0,
      enGucluDers: strongest,
      gelistirilmesiGerekenDers: weakest,
    );
  }
}
