import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/daily_mini_ranking_models.dart';
import '../models/leaderboard_model.dart';
import 'auth_service.dart';
import 'daily_mini_exam_service.dart';

class DailyMiniRankingService extends ChangeNotifier {
  DailyMiniRankingService._();
  static final DailyMiniRankingService instance = DailyMiniRankingService._();

  PeriodRankingSnapshot? _weekly;
  PeriodRankingSnapshot? _monthly;
  RewardHistorySnapshot? _history;
  bool _loading = false;
  String? _error;

  PeriodRankingSnapshot? snapshotFor(LeaderboardPeriod period) =>
      period == LeaderboardPeriod.haftalik ? _weekly : _monthly;

  RewardHistorySnapshot? get history => _history;
  bool get loading => _loading;
  String? get error => _error;

  String get _kpssType => DailyMiniExamService.instance.kpssType.name;

  Future<void> refresh({bool force = false}) async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final headers = AuthService.instance.authHeaders;
      final weeklyUri = ApiConfig.dailyMiniPeriodRankingUri(
        period: 'weekly',
        kpssType: _kpssType,
      );
      final monthlyUri = ApiConfig.dailyMiniPeriodRankingUri(
        period: 'monthly',
        kpssType: _kpssType,
      );
      final historyUri = ApiConfig.dailyMiniRewardHistoryUri(kpssType: _kpssType);

      final results = await Future.wait([
        http.get(weeklyUri, headers: headers).timeout(const Duration(seconds: 10)),
        http.get(monthlyUri, headers: headers).timeout(const Duration(seconds: 10)),
        http.get(historyUri, headers: headers).timeout(const Duration(seconds: 10)),
      ]);

      if (results[0].statusCode >= 200 && results[0].statusCode < 300) {
        final map = jsonDecode(results[0].body);
        if (map is Map) {
          _weekly = PeriodRankingSnapshot.fromJson(
            Map<String, dynamic>.from(map),
          );
        }
      }
      if (results[1].statusCode >= 200 && results[1].statusCode < 300) {
        final map = jsonDecode(results[1].body);
        if (map is Map) {
          _monthly = PeriodRankingSnapshot.fromJson(
            Map<String, dynamic>.from(map),
          );
        }
      }
      if (results[2].statusCode >= 200 && results[2].statusCode < 300) {
        final map = jsonDecode(results[2].body);
        if (map is Map) {
          _history = RewardHistorySnapshot.fromJson(
            Map<String, dynamic>.from(map),
          );
        }
      }
    } catch (e) {
      _error = 'Sıralama yüklenemedi';
      debugPrint('DailyMiniRankingService: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  List<LeaderboardEntryModel> entriesFor(LeaderboardPeriod period) {
    final snap = snapshotFor(period);
    if (snap == null) return const [];
    final me = AuthService.instance.user?.id;
    return snap.leaderboard
        .map(
          (row) => LeaderboardEntryModel(
            kullaniciId: row.userId,
            isim: row.displayName.isNotEmpty
                ? row.displayName
                : '${row.emailPrefix}${row.emailRest}',
            totalCorrect: row.totalCorrect,
            totalDurationSeconds: row.totalDurationSeconds,
            sira: row.rank,
            benMi: me != null && me == row.userId,
          ),
        )
        .toList();
  }

  bool get rewardsVisible => _history?.rewardsVisible ?? true;
}
