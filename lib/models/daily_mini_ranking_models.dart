import 'daily_mini_exam_models.dart';

enum RankingPeriodKind { weekly, monthly }

extension RankingPeriodKindApi on RankingPeriodKind {
  String get apiValue => this == RankingPeriodKind.weekly ? 'weekly' : 'monthly';
}

class PeriodLeaderRow {
  final int rank;
  final String userId;
  final String displayName;
  final String emailPrefix;
  final String emailRest;
  final int totalCorrect;
  final int totalDurationSeconds;
  final int daysPlayed;

  const PeriodLeaderRow({
    required this.rank,
    required this.userId,
    this.displayName = '',
    required this.emailPrefix,
    required this.emailRest,
    required this.totalCorrect,
    required this.totalDurationSeconds,
    this.daysPlayed = 0,
  });

  factory PeriodLeaderRow.fromJson(Map<String, dynamic> json) {
    return PeriodLeaderRow(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      userId: '${json['userId'] ?? ''}',
      displayName: '${json['displayName'] ?? ''}'.trim(),
      emailPrefix: '${json['emailPrefix'] ?? ''}',
      emailRest: '${json['emailRest'] ?? ''}',
      totalCorrect: (json['totalCorrect'] as num?)?.toInt() ?? 0,
      totalDurationSeconds: (json['totalDurationSeconds'] as num?)?.toInt() ?? 0,
      daysPlayed: (json['daysPlayed'] as num?)?.toInt() ?? 0,
    );
  }

  DailyMiniLeaderRow toDailyRow() => DailyMiniLeaderRow(
        rank: rank,
        userId: userId,
        displayName: displayName,
        emailPrefix: emailPrefix,
        emailRest: emailRest,
        correct: totalCorrect,
        durationSeconds: totalDurationSeconds,
      );
}

class PeriodRankingSnapshot {
  final RankingPeriodKind period;
  final String periodStart;
  final String periodEnd;
  final int participantCount;
  final int? myRank;
  final int myTotalCorrect;
  final int myTotalDurationSeconds;
  final List<PeriodLeaderRow> leaderboard;
  final bool rewardsEnabled;
  final Map<int, int> rewardDays;

  const PeriodRankingSnapshot({
    required this.period,
    required this.periodStart,
    required this.periodEnd,
    required this.participantCount,
    required this.myRank,
    required this.myTotalCorrect,
    required this.myTotalDurationSeconds,
    required this.leaderboard,
    required this.rewardsEnabled,
    required this.rewardDays,
  });

  factory PeriodRankingSnapshot.fromJson(Map<String, dynamic> json) {
    final rawDays = json['rewardDays'];
    final days = <int, int>{};
    if (rawDays is Map) {
      rawDays.forEach((k, v) {
        final key = int.tryParse('$k');
        if (key != null) days[key] = (v as num?)?.toInt() ?? 0;
      });
    }
    final periodStr = '${json['period'] ?? 'weekly'}';
    return PeriodRankingSnapshot(
      period: periodStr == 'monthly'
          ? RankingPeriodKind.monthly
          : RankingPeriodKind.weekly,
      periodStart: '${json['periodStart'] ?? ''}',
      periodEnd: '${json['periodEnd'] ?? ''}',
      participantCount: (json['participantCount'] as num?)?.toInt() ?? 0,
      myRank: (json['myRank'] as num?)?.toInt(),
      myTotalCorrect: (json['myTotalCorrect'] as num?)?.toInt() ?? 0,
      myTotalDurationSeconds:
          (json['myTotalDurationSeconds'] as num?)?.toInt() ?? 0,
      leaderboard: (json['leaderboard'] as List<dynamic>?)
              ?.map(
                (e) => PeriodLeaderRow.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          const [],
      rewardsEnabled: json['rewardsEnabled'] == true,
      rewardDays: days.isNotEmpty ? days : const {1: 3, 2: 2, 3: 1},
    );
  }
}

class RewardHistoryWinner {
  final int rank;
  final String displayName;
  final String emailPrefix;
  final String emailRest;
  final int totalCorrect;
  final int totalDurationSeconds;
  final int premiumDays;

  const RewardHistoryWinner({
    required this.rank,
    required this.displayName,
    required this.emailPrefix,
    required this.emailRest,
    required this.totalCorrect,
    required this.totalDurationSeconds,
    required this.premiumDays,
  });

  factory RewardHistoryWinner.fromJson(Map<String, dynamic> json) {
    return RewardHistoryWinner(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      displayName: '${json['displayName'] ?? ''}'.trim(),
      emailPrefix: '${json['emailPrefix'] ?? ''}',
      emailRest: '${json['emailRest'] ?? ''}',
      totalCorrect: (json['totalCorrect'] as num?)?.toInt() ?? 0,
      totalDurationSeconds: (json['totalDurationSeconds'] as num?)?.toInt() ?? 0,
      premiumDays: (json['premiumDays'] as num?)?.toInt() ?? 0,
    );
  }
}

class RewardHistoryPeriod {
  final RankingPeriodKind periodKind;
  final String periodStart;
  final String periodEnd;
  final List<RewardHistoryWinner> winners;

  const RewardHistoryPeriod({
    required this.periodKind,
    required this.periodStart,
    required this.periodEnd,
    required this.winners,
  });

  factory RewardHistoryPeriod.fromJson(Map<String, dynamic> json) {
    final kind = '${json['periodKind'] ?? 'weekly'}';
    return RewardHistoryPeriod(
      periodKind: kind == 'monthly'
          ? RankingPeriodKind.monthly
          : RankingPeriodKind.weekly,
      periodStart: '${json['periodStart'] ?? ''}',
      periodEnd: '${json['periodEnd'] ?? ''}',
      winners: (json['winners'] as List<dynamic>?)
              ?.map(
                (e) => RewardHistoryWinner.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          const [],
    );
  }
}

class RewardHistorySnapshot {
  final bool rewardsVisible;
  final bool weeklyEnabled;
  final bool monthlyEnabled;
  final Map<int, int> rewardDays;
  final List<RewardHistoryPeriod> periods;

  const RewardHistorySnapshot({
    required this.rewardsVisible,
    required this.weeklyEnabled,
    required this.monthlyEnabled,
    required this.rewardDays,
    required this.periods,
  });

  factory RewardHistorySnapshot.fromJson(Map<String, dynamic> json) {
    final rawDays = json['rewardDays'];
    final days = <int, int>{};
    if (rawDays is Map) {
      rawDays.forEach((k, v) {
        final key = int.tryParse('$k');
        if (key != null) days[key] = (v as num?)?.toInt() ?? 0;
      });
    }
    return RewardHistorySnapshot(
      rewardsVisible: json['rewardsVisible'] != false,
      weeklyEnabled: json['weeklyEnabled'] != false,
      monthlyEnabled: json['monthlyEnabled'] != false,
      rewardDays: days.isNotEmpty ? days : const {1: 3, 2: 2, 3: 1},
      periods: (json['periods'] as List<dynamic>?)
              ?.map(
                (e) => RewardHistoryPeriod.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          const [],
    );
  }
}
