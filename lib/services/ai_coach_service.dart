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

  const CoachInsight({
    required this.message,
    this.subject,
    this.topic,
  });
}

class AiCoachService {
  AiCoachService._();
  static final AiCoachService instance = AiCoachService._();

  static const _topicHints = <String, String>{
    'Coğrafya': 'Türkiye\'nin Coğrafi Bölgeleri',
    'Tarih': 'Atatürk İnkılapları',
    'Vatandaşlık': '1982 Anayasası Yargı Bölümü',
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
      final topic = weakest.topWeakTopics.isNotEmpty
          ? weakest.topWeakTopics.first.topicName
          : _topicHints[weakest.subjectName];
      return CoachInsight(
        message: _message(
          subject: weakest.subjectName,
          topic: topic,
          streak: 1,
        ),
        subject: weakest.subjectName,
        topic: topic,
      );
    }

    final lastThree = attempts.take(3).toList();
    final subjectWrong = <String, int>{};
    for (final a in lastThree) {
      final topic = KpssCurriculum.findTopic(type, a.topicId);
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
      final topic = weakest.topWeakTopics.firstOrNull?.topicName ??
          _topicHints[weakest.subjectName];
      return CoachInsight(
        message:
            'Genel gidişat iyi. Bir sonraki odak: ${weakest.subjectName}'
            '${topic != null ? ' · $topic' : ''}.',
        subject: weakest.subjectName,
        topic: topic,
      );
    }

    final sorted = subjectWrong.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final subjectName = sorted.first.key;
    final subjectPerf = active.firstWhere(
      (s) => s.subjectName == subjectName,
      orElse: () => active.first,
    );
    final topic = subjectPerf.topWeakTopics.firstOrNull?.topicName ??
        _topicHints[subjectName];

    return CoachInsight(
      message: _message(
        subject: subjectName,
        topic: topic,
        streak: lastThree.length.clamp(2, 3),
      ),
      subject: subjectName,
      topic: topic,
    );
  }

  /// Deneme trendinden — son 3 denemede düşen ders.
  CoachInsight? buildExamTrendInsight() {
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
          message: _message(
            subject: decline.$1,
            topic: decline.$2,
            streak: recent.length.clamp(2, 3),
          ),
          subject: decline.$1,
          topic: decline.$2,
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
            'Son denemende netin ${last.totalNet.toStringAsFixed(1)} — '
            'ivme korunuyor. Zayıf derslerde mini tekrar ekle.',
      );
    }

    return CoachInsight(
      message:
          'Son iki denemede toplam nette ${delta.abs().toStringAsFixed(1)} '
          'netlik düşüş var. Ders bazlı barları inceleyip zayıf alana odaklan.',
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

  String _message({
    required String subject,
    required String? topic,
    required int streak,
  }) {
    final streakText = streak >= 3 ? 'Son 3 testtir' : 'Son testlerde';
    final topicPart =
        topic != null ? ' çalışman gereken alt konu $topic\'tir' : ' tekrar yapmalısın';
    return '$streakText ${_locative(subject)} patlıyorsun,$topicPart.';
  }

  String _locative(String subject) {
    return switch (subject) {
      'Coğrafya' => 'coğrafyada',
      'Tarih' => 'tarihte',
      'Vatandaşlık' => 'vatandaşlıkta',
      'Türkçe' => 'türkçede',
      'Matematik' => 'matematikte',
      _ => '${subject.toLowerCase()}da',
    };
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
