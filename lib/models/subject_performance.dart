/// Ders bazlı performans özeti (yalnızca konu testleri).
class SubjectPerformance {
  final String subjectId;
  final String subjectName;
  final int solved;
  final int correct;
  final int wrong;
  final int blank;
  final List<WeakTopicStat> topWeakTopics;

  const SubjectPerformance({
    required this.subjectId,
    required this.subjectName,
    required this.solved,
    required this.correct,
    required this.wrong,
    required this.blank,
    this.topWeakTopics = const [],
  });

  /// Doğru / çözülen (boş dahil).
  double get successRate => solved == 0 ? 0 : correct / solved;

  bool get hasActivity => solved > 0;
}

class WeakTopicStat {
  final String topicName;
  final int wrongCount;

  const WeakTopicStat({
    required this.topicName,
    required this.wrongCount,
  });
}

class OverallPerformance {
  final int solved;
  final int correct;
  final int wrong;
  final int blank;
  final int totalQuestions;

  const OverallPerformance({
    required this.solved,
    required this.correct,
    required this.wrong,
    required this.blank,
    required this.totalQuestions,
  });

  double get successRate => solved == 0 ? 0 : correct / solved;
}

/// Tek test oturumu — detay ekranı satırı.
class AttemptDetail {
  final String testTitle;
  final String topicName;
  final int correct;
  final int wrong;
  final int blank;
  final int total;
  final DateTime completedAt;
  final Duration duration;

  const AttemptDetail({
    required this.testTitle,
    required this.topicName,
    required this.correct,
    required this.wrong,
    required this.blank,
    required this.total,
    required this.completedAt,
    required this.duration,
  });

  double get successRate => total == 0 ? 0 : correct / total;
}

/// Konu bazlı test geçmişi grubu.
class TopicAttemptGroup {
  final String topicId;
  final String topicName;
  final List<AttemptDetail> attempts;

  const TopicAttemptGroup({
    required this.topicId,
    required this.topicName,
    required this.attempts,
  });

  int get attemptCount => attempts.length;

  DateTime? get lastAttemptAt =>
      attempts.isEmpty ? null : attempts.first.completedAt;
}

/// Ders bazlı tam test geçmişi.
class SubjectAttemptHistory {
  final String subjectId;
  final String subjectName;
  final List<TopicAttemptGroup> topics;

  const SubjectAttemptHistory({
    required this.subjectId,
    required this.subjectName,
    required this.topics,
  });

  int get totalAttempts =>
      topics.fold(0, (sum, g) => sum + g.attemptCount);

  bool get hasActivity => totalAttempts > 0;
}
