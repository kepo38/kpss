class DailyMiniLeaderRow {
  final int rank;
  final String userId;
  final String emailPrefix;
  final String emailRest;
  final int correct;
  final int wrong;
  final int blank;

  const DailyMiniLeaderRow({
    required this.rank,
    required this.userId,
    required this.emailPrefix,
    required this.emailRest,
    required this.correct,
    this.wrong = 0,
    this.blank = 0,
  });

  factory DailyMiniLeaderRow.fromJson(Map<String, dynamic> json) {
    return DailyMiniLeaderRow(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      userId: '${json['userId'] ?? ''}',
      emailPrefix: '${json['emailPrefix'] ?? ''}',
      emailRest: '${json['emailRest'] ?? ''}',
      correct: (json['correct'] as num?)?.toInt() ?? 0,
      wrong: (json['wrong'] as num?)?.toInt() ?? 0,
      blank: (json['blank'] as num?)?.toInt() ?? 0,
    );
  }
}

class DailyMiniAttempt {
  final int correct;
  final int wrong;
  final int blank;
  final int total;
  final int durationSeconds;
  final List<String> wrongQuestionIds;
  final int? rank;

  const DailyMiniAttempt({
    required this.correct,
    required this.wrong,
    required this.blank,
    required this.total,
    required this.durationSeconds,
    this.wrongQuestionIds = const [],
    this.rank,
  });

  factory DailyMiniAttempt.fromJson(Map<String, dynamic> json) {
    return DailyMiniAttempt(
      correct: (json['correct'] as num?)?.toInt() ?? 0,
      wrong: (json['wrong'] as num?)?.toInt() ?? 0,
      blank: (json['blank'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 20,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      wrongQuestionIds: (json['wrongQuestionIds'] as List<dynamic>?)
              ?.map((e) => '$e')
              .toList() ??
          const [],
      rank: (json['rank'] as num?)?.toInt(),
    );
  }
}

class DailyMiniExamSnapshot {
  final String examDate;
  final String kpssType;
  final bool isOpen;
  final List<String> questionIds;
  final int participantCount;
  final DailyMiniAttempt? myAttempt;
  final List<DailyMiniLeaderRow> leaderboard;
  final int secondsRemaining;

  const DailyMiniExamSnapshot({
    required this.examDate,
    required this.kpssType,
    required this.isOpen,
    required this.questionIds,
    required this.participantCount,
    this.myAttempt,
    this.leaderboard = const [],
    this.secondsRemaining = 0,
  });

  factory DailyMiniExamSnapshot.fromJson(Map<String, dynamic> json) {
    return DailyMiniExamSnapshot(
      examDate: '${json['examDate'] ?? ''}',
      kpssType: '${json['kpssType'] ?? 'lisans'}',
      isOpen: json['isOpen'] as bool? ?? false,
      questionIds: (json['questionIds'] as List<dynamic>?)
              ?.map((e) => '$e')
              .toList() ??
          const [],
      participantCount: (json['participantCount'] as num?)?.toInt() ?? 0,
      myAttempt: json['myAttempt'] is Map
          ? DailyMiniAttempt.fromJson(
              Map<String, dynamic>.from(json['myAttempt'] as Map),
            )
          : null,
      leaderboard: (json['leaderboard'] as List<dynamic>?)
              ?.whereType<Map>()
              .map(
                (e) => DailyMiniLeaderRow.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList() ??
          const [],
      secondsRemaining: (json['secondsRemaining'] as num?)?.toInt() ?? 0,
    );
  }
}
