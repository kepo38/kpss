import '../data/kpss_curriculum.dart';
import '../models/practice_exam_model.dart';
import '../models/subject_performance.dart';
import '../widgets/countdown_widget.dart';
import 'content_bank_service.dart';
import 'exam_trend_service.dart';
import 'performance_summary_service.dart';
import 'practice_exam_service.dart';
import 'tg_exam_service.dart';

/// Yapay zeka koç yorumu — kural tabanlı trend analizi.
class CoachInsight {
  final String message;
  final String? subject;
  final String? topic;
  final KpssType? kpssType;
  final String? subjectId;
  final String? topicId;

  const CoachInsight({
    required this.message,
    this.subject,
    this.topic,
    this.kpssType,
    this.subjectId,
    this.topicId,
  });

  bool get canOpenTopic =>
      kpssType != null && subjectId != null && topicId != null;
}

class AiCoachService {
  AiCoachService._();
  static final AiCoachService instance = AiCoachService._();

  static const _topicHints = <String, String>{
    'Coğrafya': 'Türkiye’nin Coğrafi Bölgeleri',
    'Tarih': 'Atatürk İnkılapları',
    'Vatandaşlık': 'Yargı',
    'Türkçe': 'Paragraf',
    'Matematik': 'Problemler',
  };

  /// Konu testlerinden — son oturumlarda zayıf ders/konu.
  CoachInsight? buildTopicTestInsight(KpssType type) {
    final subjects = PerformanceSummaryService.instance.subjectBreakdown(type);
    final active = subjects.where((s) => s.hasActivity).toList();
    if (active.isEmpty) return null;

    final attempts = ContentBankService.instance
        .attemptsForType(type)
        .where(ContentBankService.countsTowardDailyHomework)
        .toList()
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));

    if (attempts.length < 2) {
      final weakest = _weakestSubject(active);
      if (weakest == null) return null;
      final measuredTopic = weakest.topWeakTopics.firstOrNull?.topicName;
      final topic = measuredTopic ?? _topicHints[weakest.subjectName];
      return CoachInsight(
        message: composeMessage(
          subject: weakest.subjectName,
          topic: topic,
          streak: 1,
        ),
        subject: weakest.subjectName,
        topic: topic,
        kpssType: type,
        subjectId: weakest.subjectId,
        topicId: measuredTopic == null
            ? null
            : _topicIdForName(type, weakest.subjectId, measuredTopic),
      );
    }

    final lastThree = attempts.take(3).toList();
    final subjectWrong = <String, int>{};
    for (final a in lastThree) {
      final subjectId = KpssCurriculum.subjectIdForTopic(type, a.topicId);
      if (subjectId == null) continue;
      final subject = KpssCurriculum.findSubject(type, subjectId);
      if (subject == null) continue;
      if (a.wrong > 0) {
        subjectWrong[subject.name] = (subjectWrong[subject.name] ?? 0) + a.wrong;
      }
    }

    if (subjectWrong.isEmpty) {
      final weakest = _weakestSubject(active);
      if (weakest == null) return null;
      final measuredTopic = weakest.topWeakTopics.firstOrNull?.topicName;
      final topic = measuredTopic ?? _topicHints[weakest.subjectName];
      return CoachInsight(
        message:
            'Genel gidişatın olumlu. Bir sonraki çalışma odağın: ${weakest.subjectName}'
            '${topic != null ? ' · $topic' : ''}.',
        subject: weakest.subjectName,
        topic: topic,
        kpssType: type,
        subjectId: weakest.subjectId,
        topicId: measuredTopic == null
            ? null
            : _topicIdForName(type, weakest.subjectId, measuredTopic),
      );
    }

    final sorted = subjectWrong.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final subjectName = sorted.first.key;
    final subjectPerf = active
        .where((subject) => subject.subjectName == subjectName)
        .toList()
        .firstOrNull;
    final subjectId =
        subjectPerf?.subjectId ?? _subjectIdForName(type, subjectName);
    final measuredTopic = subjectPerf?.topWeakTopics.firstOrNull?.topicName;
    final topic = measuredTopic ?? _topicHints[subjectName];

    return CoachInsight(
      message: composeMessage(
        subject: subjectName,
        topic: topic,
        streak: lastThree.length.clamp(2, 3),
      ),
      subject: subjectName,
      topic: topic,
      kpssType: type,
      subjectId: subjectId,
      topicId: measuredTopic == null
          ? null
          : _topicIdForName(type, subjectId, measuredTopic),
    );
  }

  /// Deneme trendinden — son 3 denemede düşen ders.
  CoachInsight? buildExamTrendInsight(KpssType type) {
    final practice = PracticeExamService.instance.allExams
        .where((e) => !e.isInAppGenerated)
        .toList()
      ..sort((a, b) => b.tarih.compareTo(a.tarih));

    final tg = TgExamService.instance.exams
        .where((e) => e.myAttempt?.isSubmitted == true)
        .toList()
      ..sort((a, b) => b.endAt.compareTo(a.endAt));

    if (practice.isEmpty && tg.isEmpty) return null;

    if (practice.length >= 2) {
      final recent = practice.take(3).toList();
      final decline = _largestSubjectDeclineAcrossExams(recent);
      if (decline != null) {
        return CoachInsight(
          message: composeMessage(
            subject: decline.$1,
            topic: decline.$2,
            streak: recent.length.clamp(2, 3),
          ),
          subject: decline.$1,
          topic: decline.$2,
          kpssType: type,
          subjectId: _subjectIdForName(type, decline.$1),
          // Deneme trendi dersi saptar; statik konu önerisi ölçülmüş bir
          // zayıf-konu verisi olmadığı için bağlantı oluşturmaz.
          topicId: null,
        );
      }
    }

    final points = ExamTrendService.instance.buildUnifiedTrend();
    if (points.length < 2) return null;

    final last = points.last;
    final prev = points[points.length - 2];
    final delta = last.totalNet - prev.totalNet;
    if (delta >= 0) {
      return CoachInsight(
        message:
            'Son denemendeki net sayın ${_formatDecimal(last.totalNet)}. '
            '${delta > 0 ? 'Olumlu ivmeni koruyorsun' : 'Netini koruyorsun'}; '
            'gelişime açık derslere kısa tekrarlar ekleyebilirsin.',
      );
    }

    return CoachInsight(
      message:
          'Son iki denemede toplam netin ${_formatDecimal(delta.abs())} puan '
          'geriledi. Ders bazındaki sonuçlarını inceleyerek gelişime açık '
          'alana odaklanmanı öneriyorum.',
    );
  }

  SubjectPerformance? _weakestSubject(List<SubjectPerformance> list) {
    final withWrong = list.where((s) => s.wrong > 0).toList();
    if (withWrong.isEmpty) return null;
    withWrong.sort((a, b) {
      final rateA = a.successRate;
      final rateB = b.successRate;
      return rateA.compareTo(rateB);
    });
    return withWrong.first;
  }

  (String, String?)? _largestSubjectDeclineAcrossExams(
    List<PracticeExamModel> recent,
  ) {
    if (recent.length < 2) return null;
    final latest = recent.first;
    final baseline = recent.skip(1).take(2).toList();

    final avgBySubject = <String, double>{};
    final counts = <String, int>{};
    for (final exam in baseline) {
      exam.dersSonuclari.forEach((ders, sonuc) {
        avgBySubject[ders] = (avgBySubject[ders] ?? 0) + sonuc.net;
        counts[ders] = (counts[ders] ?? 0) + 1;
      });
    }
    for (final d in avgBySubject.keys.toList()) {
      avgBySubject[d] = avgBySubject[d]! / counts[d]!;
    }

    String? worstSubject;
    double worstDrop = 0;
    for (final entry in latest.dersSonuclari.entries) {
      final prev = avgBySubject[entry.key];
      if (prev == null) continue;
      final drop = prev - entry.value.net;
      if (drop > worstDrop) {
        worstDrop = drop;
        worstSubject = entry.key;
      }
    }

    if (worstSubject == null || worstDrop < 0.5) return null;
    return (worstSubject, _topicHints[worstSubject]);
  }

  static String composeMessage({
    required String subject,
    required String? topic,
    required int streak,
  }) {
    final period = switch (streak) {
      >= 3 => 'Son üç test sonucuna göre',
      2 => 'Son iki test sonucuna göre',
      _ => 'Son test sonucuna göre',
    };
    final opening =
        '$period $subject dersinde gelişime açık bir alan bulunuyor.';
    if (topic == null || topic.trim().isEmpty) {
      return '$opening Kısa bir konu tekrarı yaptıktan sonra yeni bir test '
          'çözmeni öneriyorum.';
    }
    return '$opening Öncelikle “$topic” konusuna odaklanmanı öneriyorum.';
  }

  static String _formatDecimal(double value) =>
      value.toStringAsFixed(1).replaceAll('.', ',');

  String? _subjectIdForName(KpssType type, String subjectName) {
    for (final subject in KpssCurriculum.subjectsFor(type)) {
      if (subject.name == subjectName) return subject.id;
    }
    return null;
  }

  String? _topicIdForName(
    KpssType type,
    String? subjectId,
    String? topicName,
  ) {
    if (subjectId == null || topicName == null) return null;
    final subject = KpssCurriculum.findSubject(type, subjectId);
    if (subject == null) return null;
    for (final topic in subject.topics) {
      if (topic.name == topicName || topic.subtopics.contains(topicName)) {
        return topic.id;
      }
    }
    return null;
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
