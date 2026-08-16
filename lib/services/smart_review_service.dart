import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/kpss_curriculum.dart';
import '../models/question_model.dart';
import '../widgets/countdown_widget.dart';
import 'content_bank_service.dart';
import 'question_fetch_service.dart';

/// Günlük 15 soruluk spaced-repetition seti.
/// Öncelik: yanlış defteri → vadesi gelen → düşük başarı konuları.
class SmartReviewService extends ChangeNotifier {
  SmartReviewService._();
  static final SmartReviewService instance = SmartReviewService._();

  static const storageKey = 'smart_review_state_v1';
  static const dailyTarget = 15;
  static const weakAccuracyThreshold = 0.6;

  final Map<String, ReviewSchedule> _schedules = {};
  String? _packDay;
  String? _packType;
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
  Future<SmartReviewPack> ensureTodayPack(KpssType type) async {
    final now = DateTime.now();
    final day = SmartReviewLogic.dayKey(now);
    if (_packDay == day &&
        _packType == type.name &&
        _packIds.isNotEmpty) {
      return _currentPack(type);
    }

    final bank = ContentBankService.instance;
    final weakTopics = _weakTopics(type, bank);
    final selected = SmartReviewLogic.selectQuestionIds(
      wrongQuestionIds: bank.wrongQuestionIds.toList(),
      weakTopicQuestionIds: [
        for (final w in weakTopics) ...w.questionIds,
      ],
      schedules: Map.of(_schedules),
      now: now,
      target: dailyTarget,
      daySeed: day.hashCode ^ type.index,
    );

    // Yalnızca yanlış / zayıf konu materyali varsa set oluştur;
    // eksik kalırsa aynı havuzdan doldur.
    final filled = selected.isEmpty
        ? const <String>[]
        : _fillFromBank(type, bank, selected);

    _packDay = day;
    _packType = type.name;
    _packIds = filled;
    _packCompleted = false;
    await _persist();
    notifyListeners();
    return _currentPack(type);
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

  bool hasMaterial(KpssType type) {
    final bank = ContentBankService.instance;
    if (bank.wrongQuestionCount > 0) return true;
    return _weakTopics(type, bank).isNotEmpty;
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

  SmartReviewPack _currentPack(KpssType type) {
    return SmartReviewPack(
      dayKey: _packDay ?? SmartReviewLogic.dayKey(DateTime.now()),
      kpssType: type,
      questionIds: List.unmodifiable(_packIds),
      completed: _packCompleted,
      wrongCount: ContentBankService.instance.wrongQuestionCount,
      weakTopicCount: _weakTopics(type, ContentBankService.instance).length,
    );
  }

  List<_WeakTopic> _weakTopics(KpssType type, ContentBankService bank) {
    final out = <_WeakTopic>[];
    for (final subject in KpssCurriculum.subjectsFor(type)) {
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

  List<String> _fillFromBank(
    KpssType type,
    ContentBankService bank,
    List<String> selected,
  ) {
    if (selected.length >= dailyTarget) {
      return selected.take(dailyTarget).toList();
    }
    final seen = selected.toSet();
    final extras = <String>[];
    if (bank.hasFullQuestionBank) {
      for (final subject in KpssCurriculum.subjectsFor(type)) {
        for (final topic in subject.topics) {
          for (final q in bank.questionsForTopic(type, topic.id)) {
            if (seen.add(q.id)) extras.add(q.id);
            if (selected.length + extras.length >= dailyTarget) break;
          }
          if (selected.length + extras.length >= dailyTarget) break;
        }
        if (selected.length + extras.length >= dailyTarget) break;
      }
    } else {
      for (final id in bank.catalogQuestionIds) {
        if (seen.add(id)) extras.add(id);
        if (selected.length + extras.length >= dailyTarget) break;
      }
    }
    return [...selected, ...extras].take(dailyTarget).toList();
  }

  void _load(String? raw) {
    _schedules.clear();
    _packIds = [];
    _packDay = null;
    _packType = null;
    _packCompleted = false;
    if (raw == null || raw.isEmpty) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _packDay = map['packDay'] as String?;
      _packType = map['packType'] as String?;
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
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'packDay': _packDay,
      'packType': _packType,
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
    _packCompleted = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
    notifyListeners();
  }
}

class SmartReviewPack {
  final String dayKey;
  final KpssType kpssType;
  final List<String> questionIds;
  final bool completed;
  final int wrongCount;
  final int weakTopicCount;

  const SmartReviewPack({
    required this.dayKey,
    required this.kpssType,
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
