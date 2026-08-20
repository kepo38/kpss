import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/kpss_curriculum.dart';
import '../models/question_model.dart';
import '../widgets/countdown_widget.dart';
import 'content_bank_service.dart';
import 'question_fetch_service.dart';

/// Günlük spaced-repetition seti.
/// Öncelik: yanlış defteri (vadesi gelen önce) → %60 altı zayıf konular → SRS erteleme (oturum sonrası).
class SmartReviewService extends ChangeNotifier {
  SmartReviewService._();
  static final SmartReviewService instance = SmartReviewService._();

  static const storageKey = 'smart_review_state_v1';
  static const dailyTarget = 15;
  static const weakAccuracyThreshold = 0.6;

  final Map<String, ReviewSchedule> _schedules = {};
  String? _packDay;
  String? _packType;
  String? _packSubjectId;
  List<String> _packIds = [];
  bool _packCompleted = false;
  bool _initialized = false;

  bool get isInitialized => _initialized;
  bool get isTodayPackCompleted =>
      _packDay == SmartReviewLogic.dayKey(DateTime.now()) && _packCompleted;
  int get todayPackSize => _packIds.length;
  List<String> get todayPackIds => List.unmodifiable(_packIds);

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _load(prefs.getString(storageKey));
    _initialized = true;
    notifyListeners();
  }

  /// Bugünün setini üretir / önbellekten döner.
  /// [subjectId] null ise tüm dersler; aksi halde yalnızca o ders.
  Future<SmartReviewPack> ensureTodayPack(
    KpssType type, {
    String? subjectId,
  }) async {
    final now = DateTime.now();
    final day = SmartReviewLogic.dayKey(now);
    if (_packDay == day &&
        _packType == type.name &&
        _packSubjectId == subjectId &&
        _packIds.isNotEmpty) {
      return _currentPack(type, subjectId: subjectId);
    }

    final bank = ContentBankService.instance;
    var wrongIds = bank.wrongQuestionIds.toList();
    if (subjectId != null) {
      final subject = KpssCurriculum.findSubject(type, subjectId);
      if (subject != null) {
        final bodies = bank.questionsByIds(wrongIds);
        wrongIds = bodies
            .where((q) => q.dersAdi == subject.name)
            .map((q) => q.id)
            .toList();
      } else {
        wrongIds = [];
      }
    }

    final weakTopics = _weakTopics(type, bank, subjectId: subjectId);
    // Adımlar 1–2: yanlışlar (vade önce) → zayıf konular. Adım 3 (SRS) scheduleAfter*.
    final selected = SmartReviewLogic.selectQuestionIds(
      wrongQuestionIds: wrongIds,
      weakTopicQuestionIds: [
        for (final w in weakTopics) ...w.questionIds,
      ],
      schedules: Map.of(_schedules),
      now: now,
      target: dailyTarget,
      daySeed: day.hashCode ^ type.index ^ (subjectId?.hashCode ?? 0),
    );

    // Yalnızca yanlış defteri + zayıf konu havuzu; müfredattan doldurma yok.
    _packDay = day;
    _packType = type.name;
    _packSubjectId = subjectId;
    _packIds = selected;
    _packCompleted = false;
    await _persist();
    notifyListeners();
    return _currentPack(type, subjectId: subjectId);
  }

  Future<List<QuestionModel>> fetchQuestionsForTodayPack(KpssType type) {
    return QuestionFetchService.instance.fetchByIds(_packIds);
  }

  List<QuestionModel> questionsForTodayPack(KpssType type) {
    final bank = ContentBankService.instance;
    return bank.questionsByIds(_packIds);
  }

  String subtitleFor(KpssType type) {
    if (isTodayPackCompleted) {
      return 'Bugünkü tekrar tamamlandı';
    }
    final wrong = ContentBankService.instance.wrongQuestionCount;
    final weak = _weakTopics(type, ContentBankService.instance).length;
    if (_packIds.isNotEmpty &&
        _packDay == SmartReviewLogic.dayKey(DateTime.now()) &&
        _packType == type.name) {
      return '${_packIds.length} soru · yanlış + zayıf konular';
    }
    if (wrong == 0 && weak == 0) {
      return 'Önce konu testi çöz, sonra akıllı tekrar gelsin';
    }
    return 'Yanlış + düşük başarı · günlük $dailyTarget soru';
  }

  bool hasMaterial(KpssType type, {String? subjectId}) {
    final bank = ContentBankService.instance;
    var wrongIds = bank.wrongQuestionIds.toList();
    if (subjectId != null) {
      final subject = KpssCurriculum.findSubject(type, subjectId);
      if (subject == null) return false;
      final bodies = bank.questionsByIds(wrongIds);
      wrongIds = bodies
          .where((q) => q.dersAdi == subject.name)
          .map((q) => q.id)
          .toList();
    }
    if (wrongIds.isNotEmpty) return true;
    return _weakTopics(type, bank, subjectId: subjectId).isNotEmpty;
  }

  /// Oturum sonrası SRS aralıklarını güncelle + günlük paketi tamamla.
  Future<void> recordSessionOutcome({
    required List<String> correctIds,
    required List<String> wrongIds,
    DateTime? now,
  }) async {
    final clock = now ?? DateTime.now();
    for (final id in wrongIds) {
      _schedules[id] = SmartReviewLogic.scheduleAfterWrong(
        previous: _schedules[id],
        now: clock,
      );
    }
    for (final id in correctIds) {
      _schedules[id] = SmartReviewLogic.scheduleAfterCorrect(
        previous: _schedules[id],
        now: clock,
      );
    }

    if (_packDay == SmartReviewLogic.dayKey(clock)) {
      _packCompleted = true;
    }

    await ContentBankService.instance.updateAnswerOutcomes(
      wrongQuestionIds: wrongIds,
      correctQuestionIds: correctIds,
    );
    await _persist();
    notifyListeners();
  }

  SmartReviewPack _currentPack(KpssType type, {String? subjectId}) {
    final bank = ContentBankService.instance;
    var wrongIds = bank.wrongQuestionIds.toList();
    if (subjectId != null) {
      final subject = KpssCurriculum.findSubject(type, subjectId);
      if (subject != null) {
        final bodies = bank.questionsByIds(wrongIds);
        wrongIds = bodies
            .where((q) => q.dersAdi == subject.name)
            .map((q) => q.id)
            .toList();
      } else {
        wrongIds = [];
      }
    }
    final weak = _weakTopics(type, bank, subjectId: subjectId);
    return SmartReviewPack(
      dayKey: _packDay ?? SmartReviewLogic.dayKey(DateTime.now()),
      kpssType: type,
      subjectId: subjectId ?? _packSubjectId,
      questionIds: List.unmodifiable(_packIds),
      completed: _packCompleted,
      wrongCount: wrongIds.length,
      weakTopicCount: weak.length,
    );
  }

  List<_WeakTopic> _weakTopics(
    KpssType type,
    ContentBankService bank, {
    String? subjectId,
  }) {
    final subjects = <KpssSubject>[];
    if (subjectId != null) {
      final subject = KpssCurriculum.findSubject(type, subjectId);
      if (subject != null) subjects.add(subject);
    } else {
      subjects.addAll(KpssCurriculum.subjectsFor(type));
    }

    final out = <_WeakTopic>[];
    for (final subject in subjects) {
      for (final topic in subject.topics) {
        final stats = bank.topicStats(topic.id);
        if (stats.attemptCount <= 0) continue;
        if (stats.averageAccuracy >= weakAccuracyThreshold) continue;
        final qs = bank.questionsForTopic(type, topic.id);
        if (qs.isEmpty) continue;
        out.add(
          _WeakTopic(
            topicId: topic.id,
            accuracy: stats.averageAccuracy,
            questionIds: qs.map((q) => q.id).toList(),
          ),
        );
      }
    }
    out.sort((a, b) => a.accuracy.compareTo(b.accuracy));
    return out;
  }

  void _load(String? raw) {
    _schedules.clear();
    _packIds = [];
    _packDay = null;
    _packType = null;
    _packSubjectId = null;
    _packCompleted = false;
    if (raw == null || raw.isEmpty) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _packDay = map['packDay'] as String?;
      _packType = map['packType'] as String?;
      _packSubjectId = map['packSubjectId'] as String?;
      _packCompleted = map['packCompleted'] as bool? ?? false;
      _packIds = (map['packIds'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList();
      final schedules = map['schedules'] as Map<String, dynamic>? ?? const {};
      for (final entry in schedules.entries) {
        final value = entry.value as Map<String, dynamic>;
        _schedules[entry.key] = ReviewSchedule(
          dueAt: DateTime.tryParse(value['dueAt'] as String? ?? '') ??
              DateTime.now(),
          intervalDays: (value['intervalDays'] as num?)?.toInt() ?? 1,
        );
      }
    } catch (_) {
      _schedules.clear();
      _packIds = [];
      _packSubjectId = null;
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'packDay': _packDay,
      'packType': _packType,
      'packSubjectId': _packSubjectId,
      'packCompleted': _packCompleted,
      'packIds': _packIds,
      'schedules': {
        for (final e in _schedules.entries)
          e.key: {
            'dueAt': e.value.dueAt.toIso8601String(),
            'intervalDays': e.value.intervalDays,
          },
      },
    });
    await prefs.setString(storageKey, payload);
  }

  @visibleForTesting
  Future<void> resetForTesting() async {
    _schedules.clear();
    _packIds = [];
    _packDay = null;
    _packType = null;
    _packSubjectId = null;
    _packCompleted = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
    notifyListeners();
  }
}

class SmartReviewPack {
  final String dayKey;
  final KpssType kpssType;
  final String? subjectId;
  final List<String> questionIds;
  final bool completed;
  final int wrongCount;
  final int weakTopicCount;

  const SmartReviewPack({
    required this.dayKey,
    required this.kpssType,
    this.subjectId,
    required this.questionIds,
    required this.completed,
    required this.wrongCount,
    required this.weakTopicCount,
  });

  int get size => questionIds.length;
  bool get isEmpty => questionIds.isEmpty;
}

class ReviewSchedule {
  final DateTime dueAt;
  final int intervalDays;

  const ReviewSchedule({
    required this.dueAt,
    required this.intervalDays,
  });
}

class _WeakTopic {
  final String topicId;
  final double accuracy;
  final List<String> questionIds;

  const _WeakTopic({
    required this.topicId,
    required this.accuracy,
    required this.questionIds,
  });
}

/// Saf seçim mantığı — unit test.
abstract final class SmartReviewLogic {
  static String dayKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static bool isDue(ReviewSchedule? schedule, DateTime now) {
    if (schedule == null) return true;
    return !now.isBefore(schedule.dueAt);
  }

  static ReviewSchedule scheduleAfterWrong({
    required ReviewSchedule? previous,
    required DateTime now,
  }) {
    return ReviewSchedule(
      dueAt: now.add(const Duration(days: 1)),
      intervalDays: 1,
    );
  }

  static ReviewSchedule scheduleAfterCorrect({
    required ReviewSchedule? previous,
    required DateTime now,
  }) {
    final prev = previous?.intervalDays ?? 1;
    final next = (prev * 2).clamp(1, 30);
    return ReviewSchedule(
      dueAt: now.add(Duration(days: next)),
      intervalDays: next,
    );
  }

  /// Yanlışlar (vadesi gelen önce) → zayıf konu soruları → hedefe kadar.
  /// Adım 3 (SRS erteleme) [scheduleAfterWrong] / [scheduleAfterCorrect] ile oturum sonrası.
  static List<String> selectQuestionIds({
    required List<String> wrongQuestionIds,
    required List<String> weakTopicQuestionIds,
    required Map<String, ReviewSchedule> schedules,
    required DateTime now,
    required int target,
    required int daySeed,
  }) {
    final rng = Random(daySeed);
    final selected = <String>[];
    final seen = <String>{};

    void takeFrom(List<String> pool, {required bool dueOnly}) {
      final due = <String>[];
      final later = <String>[];
      for (final id in pool) {
        if (isDue(schedules[id], now)) {
          due.add(id);
        } else if (!dueOnly) {
          later.add(id);
        }
      }
      // Aynı öncelik bandında gün içi kararlı karışım
      due.shuffle(rng);
      later.shuffle(rng);
      for (final id in [...due, ...later]) {
        if (selected.length >= target) return;
        if (seen.add(id)) selected.add(id);
      }
    }

    takeFrom(wrongQuestionIds, dueOnly: false);
    takeFrom(weakTopicQuestionIds, dueOnly: true);
    if (selected.length < target) {
      takeFrom(weakTopicQuestionIds, dueOnly: false);
    }
    return selected.take(target).toList();
  }
}
