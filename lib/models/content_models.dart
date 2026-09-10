import '../widgets/countdown_widget.dart';

/// Konu başına test ayarları (Django’dan sync).
class TopicTestConfig {
  final String topicId;
  final KpssType kpssType;
  final int questionsPerTest;
  final int timeLimitMinutes;
  final bool shuffleQuestions;
  final bool shuffleOptions;
  final bool showSolutionAfterEach;
  final bool enabled;

  const TopicTestConfig({
    required this.topicId,
    required this.kpssType,
    this.questionsPerTest = 20,
    this.timeLimitMinutes = 0,
    this.shuffleQuestions = true,
    this.shuffleOptions = true,
    this.showSolutionAfterEach = false,
    this.enabled = true,
  });

  TopicTestConfig copyWith({
    int? questionsPerTest,
    int? timeLimitMinutes,
    bool? shuffleQuestions,
    bool? shuffleOptions,
    bool? showSolutionAfterEach,
    bool? enabled,
  }) {
    return TopicTestConfig(
      topicId: topicId,
      kpssType: kpssType,
      questionsPerTest: questionsPerTest ?? this.questionsPerTest,
      timeLimitMinutes: timeLimitMinutes ?? this.timeLimitMinutes,
      shuffleQuestions: shuffleQuestions ?? this.shuffleQuestions,
      shuffleOptions: shuffleOptions ?? this.shuffleOptions,
      showSolutionAfterEach:
          showSolutionAfterEach ?? this.showSolutionAfterEach,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'topicId': topicId,
        'kpssType': kpssType.name,
        'questionsPerTest': questionsPerTest,
        'timeLimitMinutes': timeLimitMinutes,
        'shuffleQuestions': shuffleQuestions,
        'shuffleOptions': shuffleOptions,
        'showSolutionAfterEach': showSolutionAfterEach,
        'enabled': enabled,
      };

  factory TopicTestConfig.fromJson(Map<String, dynamic> json) {
    return TopicTestConfig(
      topicId: json['topicId'] as String,
      kpssType: KpssType.values.byName(json['kpssType'] as String),
      questionsPerTest: json['questionsPerTest'] as int? ?? 20,
      timeLimitMinutes: json['timeLimitMinutes'] as int? ?? 0,
      shuffleQuestions: json['shuffleQuestions'] as bool? ?? true,
      shuffleOptions: json['shuffleOptions'] as bool? ?? true,
      showSolutionAfterEach: json['showSolutionAfterEach'] as bool? ?? false,
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

/// Konuya bağlı yayınlanmış test (Django panelinden gelir).
class TopicTestModel {
  final String id;
  final String topicId;
  final KpssType kpssType;
  final String title;
  final String? description;
  final int questionCount;
  final int timeLimitMinutes;
  final List<String> questionIds;
  final DateTime createdAt;
  final bool published;

  const TopicTestModel({
    required this.id,
    required this.topicId,
    required this.kpssType,
    required this.title,
    this.description,
    required this.questionCount,
    this.timeLimitMinutes = 0,
    this.questionIds = const [],
    required this.createdAt,
    this.published = true,
  });

  bool get hasQuestions => questionCount > 0 || questionIds.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'topicId': topicId,
        'kpssType': kpssType.name,
        'title': title,
        'description': description,
        'questionCount': questionCount,
        'timeLimitMinutes': timeLimitMinutes,
        'questionIds': questionIds,
        'createdAt': createdAt.toIso8601String(),
        'published': published,
      };

  factory TopicTestModel.fromJson(Map<String, dynamic> json) {
    return TopicTestModel(
      id: json['id'] as String,
      topicId: json['topicId'] as String,
      kpssType: KpssType.values.byName(json['kpssType'] as String),
      title: json['title'] as String,
      description: json['description'] as String?,
      questionCount: json['questionCount'] as int,
      timeLimitMinutes: json['timeLimitMinutes'] as int? ?? 0,
      questionIds: (json['questionIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      published: json['published'] as bool? ?? true,
    );
  }
}

/// Tek bir test oturumu sonucu.
class TestAttemptModel {
  final String id;
  final String testId;
  final String topicId;
  final KpssType kpssType;
  final int correct;
  final int wrong;
  final int blank;
  final int total;
  final Duration duration;
  final DateTime completedAt;

  const TestAttemptModel({
    required this.id,
    required this.testId,
    required this.topicId,
    required this.kpssType,
    required this.correct,
    required this.wrong,
    required this.blank,
    required this.total,
    required this.duration,
    required this.completedAt,
  });

  double get accuracy => total == 0 ? 0 : correct / total;
  double get net => correct - (wrong / 4);

  Map<String, dynamic> toJson() => {
        'id': id,
        'testId': testId,
        'topicId': topicId,
        'kpssType': kpssType.name,
        'correct': correct,
        'wrong': wrong,
        'blank': blank,
        'total': total,
        'durationMs': duration.inMilliseconds,
        'completedAt': completedAt.toIso8601String(),
      };

  factory TestAttemptModel.fromJson(Map<String, dynamic> json) {
    return TestAttemptModel(
      id: json['id'] as String,
      testId: json['testId'] as String,
      topicId: json['topicId'] as String,
      kpssType: KpssType.values.byName(json['kpssType'] as String),
      correct: json['correct'] as int,
      wrong: json['wrong'] as int,
      blank: json['blank'] as int,
      total: json['total'] as int,
      duration: Duration(milliseconds: json['durationMs'] as int),
      completedAt: DateTime.parse(json['completedAt'] as String),
    );
  }
}

class TopicStatsSummary {
  final String topicId;
  final int attemptCount;
  final int totalCorrect;
  final int totalWrong;
  final int totalBlank;
  final double averageAccuracy;
  final double averageNet;
  final DateTime? lastAttemptAt;

  const TopicStatsSummary({
    required this.topicId,
    required this.attemptCount,
    required this.totalCorrect,
    required this.totalWrong,
    required this.totalBlank,
    required this.averageAccuracy,
    required this.averageNet,
    this.lastAttemptAt,
  });
}

class TestStatsSummary {
  final String testId;
  final int attemptCount;
  final double averageAccuracy;
  final double bestAccuracy;
  final double averageNet;
  final DateTime? lastAttemptAt;

  const TestStatsSummary({
    required this.testId,
    required this.attemptCount,
    required this.averageAccuracy,
    required this.bestAccuracy,
    required this.averageNet,
    this.lastAttemptAt,
  });
}

class GlobalStatsSummary {
  final int totalAttempts;
  final int totalQuestionsAnswered;
  final int totalCorrect;
  final double overallAccuracy;
  final double overallNet;
  final int topicsPracticed;
  final int studyMinutes;

  const GlobalStatsSummary({
    required this.totalAttempts,
    required this.totalQuestionsAnswered,
    required this.totalCorrect,
    required this.overallAccuracy,
    required this.overallNet,
    required this.topicsPracticed,
    required this.studyMinutes,
  });
}

/// Konuya bağlı bilgi / mikro öğrenme kartı.
class TopicLessonModel {
  final String id;
  final String topicId;
  final String title;
  final String body;
  final String? imageUrl;
  final int sortOrder;

  const TopicLessonModel({
    required this.id,
    required this.topicId,
    required this.title,
    required this.body,
    this.imageUrl,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'topicId': topicId,
        'title': title,
        'body': body,
        'imageUrl': imageUrl,
        'sortOrder': sortOrder,
      };

  factory TopicLessonModel.fromJson(Map<String, dynamic> json) {
    return TopicLessonModel(
      id: json['id'] as String,
      topicId: json['topicId'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      imageUrl: json['imageUrl'] as String?,
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }
}

/// Konu detayında kaydırılan kısa özet / formül kartı.
enum SummaryCardKind { formula, tip, osym }

class TopicSummaryCardModel {
  final String id;
  final String topicId;
  final String subjectId;
  final String subjectName;
  final String topicName;
  final SummaryCardKind kind;
  final String title;
  final String body;
  final String? imageUrl;
  final int sortOrder;

  const TopicSummaryCardModel({
    required this.id,
    required this.topicId,
    required this.subjectId,
    required this.subjectName,
    required this.topicName,
    required this.kind,
    required this.title,
    required this.body,
    this.imageUrl,
    this.sortOrder = 0,
  });

  String get kindLabel => switch (kind) {
        SummaryCardKind.formula => 'Formül',
        SummaryCardKind.tip => 'Püf nokta',
        SummaryCardKind.osym => 'ÖSYM buradan sorar',
      };

  bool get hasContent =>
      body.trim().isNotEmpty || (imageUrl?.trim().isNotEmpty ?? false);

  Map<String, dynamic> toJson() => {
        'id': id,
        'topicId': topicId,
        'subjectId': subjectId,
        'subjectName': subjectName,
        'topicName': topicName,
        'kind': kind.name,
        'title': title,
        'body': body,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'sortOrder': sortOrder,
      };

  factory TopicSummaryCardModel.fromJson(Map<String, dynamic> json) {
    final kindRaw = (json['kind'] as String? ?? 'tip').toLowerCase();
    final kind = SummaryCardKind.values.firstWhere(
      (k) => k.name == kindRaw,
      orElse: () => SummaryCardKind.tip,
    );
    return TopicSummaryCardModel(
      id: json['id'] as String,
      topicId: json['topicId'] as String,
      subjectId: json['subjectId'] as String? ?? '',
      subjectName: json['subjectName'] as String? ?? '',
      topicName: json['topicName'] as String? ?? '',
      kind: kind,
      title: json['title'] as String,
      body: json['body'] as String,
      imageUrl: json['imageUrl'] as String?,
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }
}
