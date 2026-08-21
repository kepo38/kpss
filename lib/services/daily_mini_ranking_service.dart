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
  /// Live admin flag. Null until first successful API read — UI treats as off.
  bool? _rewardsVisible;
  bool _loading = false;
  String? _error;

  PeriodRankingSnapshot? snapshotFor(LeaderboardPeriod period) =>
      period == LeaderboardPeriod.haftalik ? _weekly : _monthly;

  RewardHistorySnapshot? get history => _history;
  bool get loading => _loading;
  String? get error => _error;

  /// True only after a successful fetch that says rewards are on.
  /// Unknown / not yet loaded → false (hide ÖDÜL until confirmed).
  bool get rewardsVisible => _rewardsVisible == true;

  /// Alias for UI gates — same as [rewardsVisible].
  bool get odulActive => rewardsVisible;

  /// Whether the admin flag has been read from any startup endpoint.
  bool get rewardsVisibilityKnown => _rewardsVisible != null;

  String get _kpssType => DailyMiniExamService.instance.kpssType.name;

  /// Apply flag early from daily-mini status (or any payload that includes it).
  void applyRewardsVisible(bool? value) {
    if (value == null) return;
    if (_rewardsVisible == value) return;
    _rewardsVisible = value;
    notifyListeners();
  }

  void _absorbRewardsVisible(bool? value) {
    if (value == null) return;
    _rewardsVisible = value;
  }

  Future<void> refresh({bool force = false}) async {
    if (_loading && !force) return;
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

      bool? nextVisible;

      if (results[0].statusCode >= 200 && results[0].statusCode < 300) {
        final map = jsonDecode(results[0].body);
        if (map is Map) {
          _weekly = PeriodRankingSnapshot.fromJson(
            Map<String, dynamic>.from(map),
          );
          nextVisible ??= _weekly!.rewardsVisible;
        }
      }
      if (results[1].statusCode >= 200 && results[1].statusCode < 300) {
        final map = jsonDecode(results[1].body);
        if (map is Map) {
          _monthly = PeriodRankingSnapshot.fromJson(
            Map<String, dynamic>.from(map),
          );
          nextVisible ??= _monthly!.rewardsVisible;
        }
      }
      if (results[2].statusCode >= 200 && results[2].statusCode < 300) {
        final map = jsonDecode(results[2].body);
        if (map is Map) {
          _history = RewardHistorySnapshot.fromJson(
            Map<String, dynamic>.from(map),
          );
          // History is the canonical source when present.
          nextVisible = _history!.rewardsVisible;
        }
      }

      if (nextVisible != null) {
        _absorbRewardsVisible(nextVisible);
      } else if (_weekly == null && _monthly == null && _history == null) {
        // No successful payload — keep unknown as off for safety.
        _absorbRewardsVisible(false);
        _error = 'Sıralama yüklenemedi';
      }
    } catch (e) {
      _error = 'Sıralama yüklenemedi';
      debugPrint('DailyMiniRankingService: $e');
      // On failure keep last known flag if any; otherwise stay hidden.
      _rewardsVisible ??= false;
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
}
