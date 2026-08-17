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

  Future<void> initialize() async {
    if (_initialized) return;

    _exams.clear();
    _exams.addAll(await LocalDatabase.instance.getAllExams());

    if (await LocalDatabase.instance.isExamTableEmpty()) {
      for (final exam in _demoExams()) {
        await LocalDatabase.instance.insertExam(exam);
        _exams.add(exam);
      }
    }

    _exams.sort((a, b) => b.tarih.compareTo(a.tarih));
    _initialized = true;
  }

  List<PracticeExamModel> get exams {
    if (_publisherFilter == null) return List.unmodifiable(_exams);
    return _exams.where((e) => e.yayinEvi == _publisherFilter).toList();
  }

  List<PracticeExamModel> get allExams => List.unmodifiable(_exams);

  String? get publisherFilter => _publisherFilter;

  void setPublisherFilter(String? publisher) => _publisherFilter = publisher;

  void addExam(PracticeExamModel exam) {
    _exams.insert(0, exam);
    LocalDatabase.instance.insertExam(exam);
    unawaited(
      GamificationService.instance.onPracticeExamAdded(
        totalExams: _exams.length,
      ),
    );
  }

  void deleteExam(String id) {
    _exams.removeWhere((e) => e.id == id);
    LocalDatabase.instance.deleteExam(id);
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

  Map<String, DersSonuc> get aggregateBySubject {
    final map = <String, DersSonuc>{};
    for (final exam in exams) {
      exam.dersSonuclari.forEach((ders, sonuc) {
        final existing = map[ders];
        if (existing == null) {
          map[ders] = sonuc;
        } else {
          map[ders] = DersSonuc(
            dogru: existing.dogru + sonuc.dogru,
            yanlis: existing.yanlis + sonuc.yanlis,
            bos: existing.bos + sonuc.bos,
          );
        }
      });
    }
    return map;
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
        ? thisAvg
        : lastWeek.map((e) => e.toplamNet).reduce((a, b) => a + b) /
            lastWeek.length;

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
      netDegisim: thisAvg - lastAvg,
      tekrarBekleyenSoru: 0,
      enGucluDers: strongest,
      gelistirilmesiGerekenDers: weakest,
    );
  }

  /// İlk kurulumda gösterilecek örnek denemeler (yalnızca DB boşken).
  static List<PracticeExamModel> _demoExams() {
    final now = DateTime.now();
    return [
      PracticeExamModel(
        id: 'e1',
        denemeAdi: 'Genel Deneme 1',
        yayinEvi: 'Palme',
        tarih: now.subtract(const Duration(days: 21)),
        dersSonuclari: const {
          'Türkçe': DersSonuc(dogru: 22, yanlis: 6, bos: 2),
          'Matematik': DersSonuc(dogru: 12, yanlis: 8, bos: 10),
          'Tarih': DersSonuc(dogru: 18, yanlis: 4, bos: 5),
          'Coğrafya': DersSonuc(dogru: 10, yanlis: 3, bos: 5),
          'Vatandaşlık': DersSonuc(dogru: 10, yanlis: 2, bos: 3),
        },
      ),
      PracticeExamModel(
        id: 'e2',
        denemeAdi: 'Genel Deneme 2',
        yayinEvi: 'Pegem',
        tarih: now.subtract(const Duration(days: 14)),
        dersSonuclari: const {
          'Türkçe': DersSonuc(dogru: 25, yanlis: 4, bos: 1),
          'Matematik': DersSonuc(dogru: 15, yanlis: 7, bos: 8),
          'Tarih': DersSonuc(dogru: 20, yanlis: 3, bos: 4),
          'Coğrafya': DersSonuc(dogru: 12, yanlis: 2, bos: 4),
          'Vatandaşlık': DersSonuc(dogru: 11, yanlis: 1, bos: 3),
        },
      ),
      PracticeExamModel(
        id: 'e3',
        denemeAdi: 'Genel Deneme 3',
        yayinEvi: 'Palme',
        tarih: now.subtract(const Duration(days: 7)),
        dersSonuclari: const {
          'Türkçe': DersSonuc(dogru: 27, yanlis: 2, bos: 1),
          'Matematik': DersSonuc(dogru: 18, yanlis: 5, bos: 7),
          'Tarih': DersSonuc(dogru: 22, yanlis: 2, bos: 3),
          'Coğrafya': DersSonuc(dogru: 13, yanlis: 1, bos: 4),
          'Vatandaşlık': DersSonuc(dogru: 12, yanlis: 1, bos: 2),
        },
      ),
      PracticeExamModel(
        id: 'e4',
        denemeAdi: 'İndeks Branş Denemesi',
        yayinEvi: 'İndeks Akademi',
        tarih: now.subtract(const Duration(days: 3)),
        dersSonuclari: const {
          'Türkçe': DersSonuc(dogru: 26, yanlis: 3, bos: 1),
          'Matematik': DersSonuc(dogru: 16, yanlis: 6, bos: 8),
          'Tarih': DersSonuc(dogru: 19, yanlis: 4, bos: 4),
          'Coğrafya': DersSonuc(dogru: 11, yanlis: 3, bos: 4),
          'Vatandaşlık': DersSonuc(dogru: 10, yanlis: 2, bos: 3),
        },
      ),
    ];
  }
}
