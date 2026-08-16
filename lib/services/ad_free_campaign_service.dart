import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 3 ödüllü reklam → 12 saat reklamsız mod kampanyası (yerel depolama).
///
/// Google politikası: reklamlar peş peşe değil, en az [minCooldownBetweenAds]
/// arayla; buton metni ne kazanılacağını açıkça belirtir.
class AdFreeCampaignService extends ChangeNotifier {
  AdFreeCampaignService._();
  static final AdFreeCampaignService instance = AdFreeCampaignService._();

  static const storageKey = 'ad_free_campaign_v1';
  static const requiredAds = 3;
  static const adFreeDuration = Duration(hours: 12);
  static const minCooldownBetweenAds = Duration(hours: 4);

  String? _campaignDay;
  int _adsWatchedToday = 0;
  DateTime? _lastRewardedAdAt;
  DateTime? _adFreeUntil;
  bool _initialized = false;

  bool get isInitialized => _initialized;
  int get adsWatchedToday => _adsWatchedToday;
  DateTime? get adFreeUntil => _adFreeUntil;
  DateTime? get lastRewardedAdAt => _lastRewardedAdAt;

  bool get isAdFreeActive =>
      AdFreeCampaignLogic.isAdFreeActive(_adFreeUntil, DateTime.now());

  double get progress => AdFreeCampaignLogic.progress(
        adsWatchedToday: _adsWatchedToday,
        adFreeActive: isAdFreeActive,
      );

  bool get canWatchNextAd => AdFreeCampaignLogic.canWatchNextAd(
        adsWatchedToday: _adsWatchedToday,
        lastRewardedAdAt: _lastRewardedAdAt,
        now: DateTime.now(),
        adFreeActive: isAdFreeActive,
      );

  Duration? get cooldownRemaining => AdFreeCampaignLogic.cooldownRemaining(
        lastRewardedAdAt: _lastRewardedAdAt,
        now: DateTime.now(),
        canWatch: canWatchNextAd,
      );

  Duration? get adFreeRemaining => AdFreeCampaignLogic.adFreeRemaining(
        adFreeUntil: _adFreeUntil,
        now: DateTime.now(),
      );

  String get ctaButtonLabel => AdFreeCampaignLogic.ctaButtonLabel(
        adsWatchedToday: _adsWatchedToday,
        adFreeActive: isAdFreeActive,
        adFreeRemaining: adFreeRemaining,
        canWatch: canWatchNextAd,
        cooldownRemaining: cooldownRemaining,
      );

  String get subtitleLabel => AdFreeCampaignLogic.subtitleLabel(
        adsWatchedToday: _adsWatchedToday,
        adFreeActive: isAdFreeActive,
        adFreeRemaining: adFreeRemaining,
        canWatch: canWatchNextAd,
        cooldownRemaining: cooldownRemaining,
      );

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _loadFromPrefs(prefs.getString(storageKey));
    _initialized = true;
    notifyListeners();
  }

  /// Başarılı ödüllü reklam sonrası ilerlemeyi kaydeder.
  Future<void> onRewardedAdCompleted({DateTime? now}) async {
    final clock = now ?? DateTime.now();
    _rollCampaignDayIfNeeded(clock);

    if (AdFreeCampaignLogic.isAdFreeActive(_adFreeUntil, clock)) {
      return;
    }
    if (!AdFreeCampaignLogic.canWatchNextAd(
      adsWatchedToday: _adsWatchedToday,
      lastRewardedAdAt: _lastRewardedAdAt,
      now: clock,
      adFreeActive: false,
    )) {
      return;
    }

    _adsWatchedToday++;
    _lastRewardedAdAt = clock;

    if (_adsWatchedToday >= requiredAds) {
      _adFreeUntil = clock.add(adFreeDuration);
      _adsWatchedToday = 0;
    }

    await _persist();
    notifyListeners();
  }

  /// Test / debug için durumu sıfırlar.
  @visibleForTesting
  Future<void> resetForTesting() async {
    _campaignDay = null;
    _adsWatchedToday = 0;
    _lastRewardedAdAt = null;
    _adFreeUntil = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
    notifyListeners();
  }

  @visibleForTesting
  Future<void> applyStateForTesting({
    required String campaignDay,
    required int adsWatchedToday,
    DateTime? lastRewardedAdAt,
    DateTime? adFreeUntil,
  }) async {
    _campaignDay = campaignDay;
    _adsWatchedToday = adsWatchedToday;
    _lastRewardedAdAt = lastRewardedAdAt;
    _adFreeUntil = adFreeUntil;
    await _persist();
    notifyListeners();
  }

  void _rollCampaignDayIfNeeded(DateTime now) {
    final today = AdFreeCampaignLogic.campaignDayKey(now);
    if (_campaignDay == today) return;

    _campaignDay = today;
    if (!AdFreeCampaignLogic.isAdFreeActive(_adFreeUntil, now)) {
      _adsWatchedToday = 0;
    }
  }

  void _loadFromPrefs(String? raw) {
    if (raw == null || raw.isEmpty) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _campaignDay = map['campaignDay'] as String?;
      _adsWatchedToday = (map['adsWatchedToday'] as num?)?.toInt() ?? 0;
      _lastRewardedAdAt = _parseDate(map['lastRewardedAdAt']);
      _adFreeUntil = _parseDate(map['adFreeUntil']);
    } catch (_) {
      _campaignDay = null;
      _adsWatchedToday = 0;
      _lastRewardedAdAt = null;
      _adFreeUntil = null;
    }

    _rollCampaignDayIfNeeded(DateTime.now());
  }

  DateTime? _parseDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'campaignDay': _campaignDay ?? AdFreeCampaignLogic.campaignDayKey(DateTime.now()),
      'adsWatchedToday': _adsWatchedToday,
      if (_lastRewardedAdAt != null)
        'lastRewardedAdAt': _lastRewardedAdAt!.toIso8601String(),
      if (_adFreeUntil != null) 'adFreeUntil': _adFreeUntil!.toIso8601String(),
    });
    await prefs.setString(storageKey, payload);
  }
}

/// Saf mantık — unit testler için.
abstract final class AdFreeCampaignLogic {
  static String campaignDayKey(DateTime dateTime) {
    final local = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static bool isAdFreeActive(DateTime? adFreeUntil, DateTime now) {
    return adFreeUntil != null && now.isBefore(adFreeUntil);
  }

  static double progress({
    required int adsWatchedToday,
    required bool adFreeActive,
  }) {
    if (adFreeActive) return 1;
    return (adsWatchedToday / AdFreeCampaignService.requiredAds).clamp(0.0, 1.0);
  }

  static bool canWatchNextAd({
    required int adsWatchedToday,
    required DateTime? lastRewardedAdAt,
    required DateTime now,
    required bool adFreeActive,
  }) {
    if (adFreeActive) return false;
    if (adsWatchedToday >= AdFreeCampaignService.requiredAds) return false;
    if (lastRewardedAdAt == null) return true;
    return now.difference(lastRewardedAdAt) >=
        AdFreeCampaignService.minCooldownBetweenAds;
  }

  static Duration? cooldownRemaining({
    required DateTime? lastRewardedAdAt,
    required DateTime now,
    required bool canWatch,
  }) {
    if (canWatch || lastRewardedAdAt == null) return null;
    final elapsed = now.difference(lastRewardedAdAt);
    final remaining =
        AdFreeCampaignService.minCooldownBetweenAds - elapsed;
    if (remaining.isNegative || remaining.inSeconds <= 0) return null;
    return remaining;
  }

  static Duration? adFreeRemaining({
    required DateTime? adFreeUntil,
    required DateTime now,
  }) {
    if (adFreeUntil == null || !now.isBefore(adFreeUntil)) return null;
    return adFreeUntil.difference(now);
  }

  static String formatDurationShort(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}s ${minutes}dk';
    }
    if (minutes > 0) {
      return '${minutes}dk';
    }
    return '${duration.inSeconds.remainder(60)}sn';
  }

  static String ctaButtonLabel({
    required int adsWatchedToday,
    required bool adFreeActive,
    required Duration? adFreeRemaining,
    required bool canWatch,
    required Duration? cooldownRemaining,
  }) {
    if (adFreeActive && adFreeRemaining != null) {
      return 'Reklamsız mod aktif';
    }
    if (!canWatch && cooldownRemaining != null) {
      return 'Sonraki reklam: ${formatDurationShort(cooldownRemaining)}';
    }
    final next = adsWatchedToday + 1;
    if (next >= AdFreeCampaignService.requiredAds) {
      return 'Son reklamı izle — 12 saat reklamsız başlat';
    }
    return 'Reklam izle ($next/${AdFreeCampaignService.requiredAds}) — '
        '12 saat reklamsız kazan';
  }

  static String subtitleLabel({
    required int adsWatchedToday,
    required bool adFreeActive,
    required Duration? adFreeRemaining,
    required bool canWatch,
    required Duration? cooldownRemaining,
  }) {
    if (adFreeActive && adFreeRemaining != null) {
      return 'Reklamsız çalışma: ${formatDurationShort(adFreeRemaining)} kaldı';
    }
    if (!canWatch && cooldownRemaining != null) {
      return 'Reklamlar arası en az 4 saat beklenir · '
          '${formatDurationShort(cooldownRemaining)} sonra devam edebilirsiniz';
    }
    if (adsWatchedToday == 0) {
      return 'Günde 3 reklam izleyerek 12 saat reklamsız çalışın';
    }
    return '${AdFreeCampaignService.requiredAds - adsWatchedToday} reklam kaldı · '
        'her reklam arasında en az 4 saat';
  }
}
