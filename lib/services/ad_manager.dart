import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_constants.dart';
import 'ad_free_campaign_service.dart';
import 'app_config_service.dart';
import 'app_preferences.dart';
import 'daily_solution_quota_service.dart';

/// Reklam ve adil fiyatlandırma mimarisi.
///
/// Kurallar:
/// - Ana kabukta (alt menü üstü) küçük banner — test/deneme ekranında YOK
/// - Pomodoro mola ekranında altta küçük banner
/// - Test/ders ortasında interstitial YOK
/// - Her 3 sayfa geçişinde bir kapatılabilir interstitial
/// - Günde 5 detaylı çözüm (ödüllü reklam); 6.+ Pro yönlendirme
/// - isPremium == true → tüm reklamlar bypass
/// - 12 saat kampanya → yalnızca banner; çözüm/kota/interstitial durur
/// - Panel `bannerAdsEnabled=false` → shell banner kapalı
class AdManager extends ChangeNotifier {
  AdManager._();
  static final AdManager instance = AdManager._();

  bool _isPremium = false;
  bool _isInTestSession = false;
  bool _adFreeTestSession = false;
  bool _skipNextPageTransition = false;
  int _pageTransitionCount = 0;
  bool _sdkReady = false;
  bool _focusScreenOpen = false;
  bool _focusBreakActive = false;
  DateTime? _interstitialSuppressedUntil;

  BannerAd? _shellBannerAd;
  BannerAd? _focusBreakBannerAd;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  /// Oturum önbelleği — bugün açılmış detaylı çözüm soru ID'leri.
  final Set<String> _unlockedSolutionIds = {};

  /// TG detaylı analiz — oturum boyunca reklamla açılan deneme id'leri.
  final Set<int> _unlockedTgAnalysisIds = {};

  int _dailyDetailedSolutionsRemaining =
      AdConstants.freeDetailedSolutionsPerDay;

  /// Bugün kalan ücretsiz detaylı çözüm hakkı.
  int get dailyDetailedSolutionsRemaining {
    if (_isPremium || _adFreeTestSession) {
      return AdConstants.freeDetailedSolutionsPerDay;
    }
    return _dailyDetailedSolutionsRemaining < 0
        ? 0
        : _dailyDetailedSolutionsRemaining;
  }

  bool get isDailyDetailedSolutionLimitReached =>
      !_isPremium &&
      !_adFreeTestSession &&
      dailyDetailedSolutionsRemaining <= 0;

  /// @deprecated [dailyDetailedSolutionsRemaining] kullanın.
  int get freeSolutionUnlocksRemaining => dailyDetailedSolutionsRemaining;

  bool get isPremium => _isPremium;
  bool get isSdkReady => _sdkReady || _bypassAllAds;
  bool get isInTestSession => _isInTestSession;
  bool get isAdFreeActive => AdFreeCampaignService.instance.isAdFreeActive;
  bool get _bypassAllAds => _isPremium || kIsWeb;
  bool get _panelBannersOff => !AppConfigService.instance.bannerAdsEnabled;
  bool get _suppressBanners =>
      _bypassAllAds ||
      _isInTestSession ||
      AdFreeCampaignService.instance.isAdFreeActive ||
      _panelBannersOff;

  /// Ana kabuk banner — test/deneme oturumunda null.
  BannerAd? get shellBannerAd => _suppressBanners ? null : _shellBannerAd;

  /// Pomodoro mola ekranı — odak modu + mola aktifken altta banner.
  BannerAd? get focusBreakBannerAd {
    if (_suppressBanners || !_focusScreenOpen || !_focusBreakActive) {
      return null;
    }
    return _focusBreakBannerAd;
  }

  /// Geriye dönük uyumluluk (quiz artık banner göstermez).
  BannerAd? get bannerAd => shellBannerAd;

  void setPremium(bool value) {
    _isPremium = value;
    if (value) {
      _disposeAllAds();
    } else {
      ensureShellBanner();
    }
    notifyListeners();
  }

  Future<void> initialize() async {
    if (_bypassAllAds) {
      _sdkReady = true;
      notifyListeners();
      return;
    }
    try {
      await MobileAds.instance.initialize();
      _sdkReady = true;
      _loadInterstitial();
      _loadRewarded();
      ensureShellBanner();
      if (_focusBreakActive && _focusScreenOpen) {
        _loadFocusBreakBanner();
      }
      unawaited(_refreshDailySolutionRemaining());
    } catch (e, st) {
      _sdkReady = false;
      debugPrint('AdManager initialize failed: $e\n$st');
    }
    notifyListeners();
  }

  /// Quiz veya test ekranına giderken bir sonraki geçiş reklamını atla.
  void skipNextPageTransition() {
    _skipNextPageTransition = true;
  }

  /// Odak modu açıkken geçiş reklamı gösterme.
  void setFocusScreenOpen(bool open) {
    if (_focusScreenOpen == open) return;
    _focusScreenOpen = open;
    if (!open) {
      setFocusBreakMode(false);
    }
  }

  /// Mola modu — alt banner göster (odak modu açıkken).
  void setFocusBreakMode(bool active) {
    if (_focusBreakActive == active) return;
    _focusBreakActive = active;
    if (active) {
      _loadFocusBreakBanner();
    } else {
      _disposeFocusBreakBanner();
    }
  }

  /// Mola bitiş zilinden hemen önce/sonra geçiş reklamı çıkmasın.
  void suppressInterstitialForFocusChime() {
    _skipNextPageTransition = true;
    _interstitialSuppressedUntil =
        DateTime.now().add(const Duration(seconds: 12));
  }

  bool get _interstitialBlocked {
    if (_focusScreenOpen) return true;
    final until = _interstitialSuppressedUntil;
    if (until != null && DateTime.now().isBefore(until)) return true;
    return false;
  }

  /// Test oturumu başladığında çağrılır — interstitial devre dışı, banner gizlenir.
  /// [adFreeExperience]: çözüm kilidi ve bitiş reklamı yok (Günün Denemesi).
  void startTestSession({bool adFreeExperience = false}) {
    _isInTestSession = true;
    _adFreeTestSession = adFreeExperience;
    _unlockedSolutionIds.clear();
    unawaited(_hydrateDailySolutionUnlocks());
    unawaited(_refreshPanelFlagsForTest());
    notifyListeners();
  }

  Future<void> _hydrateDailySolutionUnlocks() async {
    if (_isPremium || _adFreeTestSession) {
      _dailyDetailedSolutionsRemaining =
          AdConstants.freeDetailedSolutionsPerDay;
      return;
    }
    final ids =
        await DailySolutionQuotaService.instance.unlockedQuestionIdsToday();
    _unlockedSolutionIds.addAll(ids);
    await _refreshDailySolutionRemaining();
    if (_isInTestSession) notifyListeners();
  }

  Future<void> _refreshDailySolutionRemaining() async {
    if (_isPremium || _adFreeTestSession) {
      _dailyDetailedSolutionsRemaining =
          AdConstants.freeDetailedSolutionsPerDay;
      return;
    }
    _dailyDetailedSolutionsRemaining =
        await DailySolutionQuotaService.instance.remainingToday();
  }

  Future<void> _refreshPanelFlagsForTest() async {
    await AppConfigService.instance.refresh();
    if (!_isInTestSession) return;
    notifyListeners();
  }

  /// Ana kabuk görünürken banner yükle/yenile.
  void ensureShellBanner() {
    if (_suppressBanners || !_sdkReady) {
      _disposeShellBanner();
      return;
    }
    if (_shellBannerAd != null) return;
    _loadShellBanner();
  }

  /// Test oturumu bittiğinde çağrılır.
  void endTestSession() {
    _isInTestSession = false;
    _adFreeTestSession = false;
    _unlockedSolutionIds.clear();
    unawaited(_refreshDailySolutionRemaining());
    ensureShellBanner();
    notifyListeners();
  }

  /// Sayfa geçişlerinde sayaç — her 3'te bir interstitial.
  Future<void> onPageTransition({VoidCallback? onAdDismissed}) async {
    if (_bypassAllAds || _isInTestSession || _interstitialBlocked || !_sdkReady) {
      return;
    }

    if (_skipNextPageTransition) {
      _skipNextPageTransition = false;
      return;
    }

    _pageTransitionCount++;
    if (_pageTransitionCount % AdConstants.pageTransitionAdInterval != 0) {
      return;
    }

    // Navigasyonu bekletme — gösterim arka planda (fail-open).
    unawaited(_showInterstitial(onDismissed: onAdDismissed));
  }

  /// 12 saat reklamsız kampanya — ana sayfa progress bar.
  Future<bool> requestCampaignRewardedAd() async {
    if (_bypassAllAds || isAdFreeActive) return false;
    final earned = await _showRewardedVideo();
    if (!earned) return false;

    await AdFreeCampaignService.instance.onRewardedAdCompleted();
    if (AdFreeCampaignService.instance.isAdFreeActive) {
      _disposeShellBanner();
      notifyListeners();
    }
    return true;
  }

  /// Detaylı çözüm — günde [AdConstants.freeDetailedSolutionsPerDay] ödüllü reklam;
  /// kotası dolunca Pro gerekir.
  Future<bool> requestSolutionUnlock(String questionId) async {
    if (questionId.isEmpty) return false;
    if (_isPremium || _adFreeTestSession) {
      _unlockedSolutionIds.add(questionId);
      return true;
    }
    if (_unlockedSolutionIds.contains(questionId)) return true;

    if (await DailySolutionQuotaService.instance.isUnlockedToday(questionId)) {
      _unlockedSolutionIds.add(questionId);
      return true;
    }

    if (isDailyDetailedSolutionLimitReached) return false;

    final earned = await _showRewardedVideo();
    if (!earned) return false;

    final granted =
        await DailySolutionQuotaService.instance.tryUnlock(questionId);
    if (granted) {
      _unlockedSolutionIds.add(questionId);
    }
    await _refreshDailySolutionRemaining();
    notifyListeners();
    return granted;
  }

  /// Bugün zaten açılmış veya premium oturum — reklamsız yeniden açar.
  Future<bool> ensureFreeSolutionUnlock(String questionId) async {
    if (questionId.isEmpty) return false;
    if (_isPremium || _adFreeTestSession) {
      _unlockedSolutionIds.add(questionId);
      return true;
    }
    if (_unlockedSolutionIds.contains(questionId)) return true;

    if (await DailySolutionQuotaService.instance.isUnlockedToday(questionId)) {
      _unlockedSolutionIds.add(questionId);
      return true;
    }
    return false;
  }

  /// Reklam/kota bypass oturumları (TG çözüm inceleme, tanıtım testi).
  void grantSessionSolutionUnlock(String questionId) {
    if (questionId.isEmpty) return;
    _unlockedSolutionIds.add(questionId);
    notifyListeners();
  }

  /// Günlük test hakkı bittiğinde +1 test için ödüllü video (~30 sn).
  Future<bool> requestDailyTestBonus() async {
    if (_bypassAllAds) return false;
    return _showRewardedVideo();
  }

  /// Yanlış defteri — tüm eksikleri kapat quiz'i (Premium ücretsiz).
  Future<bool> requestWrongNotebookBatchPractice() async {
    if (_bypassAllAds) return true;
    return _showRewardedVideo();
  }

  static const _kWrongNotebookShareDay = 'wrong_notebook_share_day_v2';
  static const _kWrongNotebookShareCount = 'wrong_notebook_share_count_v2';
  static const _kWrongNotebookShareAdDay = 'wrong_notebook_share_ad_day_v2';

  String _todayKey([DateTime? now]) {
    final d = now ?? DateTime.now();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  Future<void> _ensureShareDayBucket(SharedPreferences prefs) async {
    final today = _todayKey();
    if (prefs.getString(_kWrongNotebookShareDay) == today) return;
    await prefs.setString(_kWrongNotebookShareDay, today);
    await prefs.setInt(_kWrongNotebookShareCount, 0);
  }

  int wrongNotebookShareLimit({required bool premium}) {
    return premium
        ? AdConstants.wrongNotebookSharesPerDayPremium
        : AdConstants.wrongNotebookSharesPerDayFree;
  }

  Future<int> wrongNotebookSharesUsedToday() async {
    final prefs = await AppPreferences.instance;
    await _ensureShareDayBucket(prefs);
    return prefs.getInt(_kWrongNotebookShareCount) ?? 0;
  }

  Future<int> wrongNotebookSharesRemainingToday({required bool premium}) async {
    final used = await wrongNotebookSharesUsedToday();
    final left = wrongNotebookShareLimit(premium: premium) - used;
    return left < 0 ? 0 : left;
  }

  /// Bugün yanlış defteri paylaşımı için reklam izlendi mi?
  Future<bool> hasWrongNotebookShareUnlockToday() async {
    final prefs = await AppPreferences.instance;
    return prefs.getString(_kWrongNotebookShareAdDay) == _todayKey();
  }

  /// Premium değilse günde bir ödüllü reklam (o günün tek paylaşım hakkı için).
  Future<bool> requestWrongNotebookShareUnlock() async {
    if (await hasWrongNotebookShareUnlockToday()) return true;
    final earned = await _showRewardedVideo();
    if (!earned) return false;
    final prefs = await AppPreferences.instance;
    await prefs.setString(_kWrongNotebookShareAdDay, _todayKey());
    return true;
  }

  /// TG detaylı istatistik / Türkiye geneli sıralama — deneme başına oturum kilidi.
  Future<bool> requestTgExamAnalysisUnlock(int examId) async {
    if (examId <= 0) return false;
    if (_unlockedTgAnalysisIds.contains(examId)) return true;
    if (_bypassAllAds) {
      _unlockedTgAnalysisIds.add(examId);
      return true;
    }
    final earned = await _showRewardedVideo();
    if (earned) {
      _unlockedTgAnalysisIds.add(examId);
    }
    return earned;
  }

  bool isTgExamAnalysisUnlocked(int examId) =>
      examId > 0 && (_bypassAllAds || _unlockedTgAnalysisIds.contains(examId));

  /// Başarılı paylaşım sonrası kotayı düşer. false → günlük limit dolu.
  Future<bool> consumeWrongNotebookShare({required bool premium}) async {
    final prefs = await AppPreferences.instance;
    await _ensureShareDayBucket(prefs);
    final used = prefs.getInt(_kWrongNotebookShareCount) ?? 0;
    final limit = wrongNotebookShareLimit(premium: premium);
    if (used >= limit) return false;
    await prefs.setInt(_kWrongNotebookShareCount, used + 1);
    return true;
  }

  Future<bool> _showRewardedVideo() async {
    if (_bypassAllAds || !_sdkReady) return false;

    final cachedAd = _rewardedAd;
    if (cachedAd != null) {
      _rewardedAd = null;
      return _presentRewardedAd(cachedAd);
    }

    final loadCompleter = Completer<RewardedAd?>();
    try {
      RewardedAd.load(
        adUnitId: AdConstants.rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            if (loadCompleter.isCompleted) {
              ad.dispose();
            } else {
              loadCompleter.complete(ad);
            }
          },
          onAdFailedToLoad: (_) {
            if (!loadCompleter.isCompleted) loadCompleter.complete(null);
          },
        ),
      );
    } catch (e, st) {
      debugPrint('RewardedAd.load failed: $e\n$st');
      return false;
    }

    final loadedAd = await loadCompleter.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => null,
    );
    if (loadedAd == null) return false;
    return _presentRewardedAd(loadedAd);
  }

  Future<bool> _presentRewardedAd(RewardedAd ad) {
    final completer = Completer<bool>();
    var rewardEarned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadRewarded();
        if (!completer.isCompleted) completer.complete(rewardEarned);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _loadRewarded();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    try {
      ad.show(
        onUserEarnedReward: (_, __) {
          rewardEarned = true;
        },
      );
    } catch (_) {
      ad.dispose();
      _loadRewarded();
      if (!completer.isCompleted) completer.complete(false);
    }

    return completer.future.timeout(
      const Duration(seconds: 90),
      onTimeout: () => rewardEarned,
    );
  }

  bool isSolutionUnlocked(String questionId) {
    return _isPremium ||
        _adFreeTestSession ||
        _unlockedSolutionIds.contains(questionId);
  }

  /// Test bitişinde (Bitir) premium olmayan kullanıcılara tam ekran reklam.
  Future<void> showTestCompletionInterstitial() async {
    if (_bypassAllAds || _adFreeTestSession || !_sdkReady) return;

    final ad = _interstitialAd;
    if (ad == null) {
      _loadInterstitial();
      return;
    }

    final completer = Completer<void>();
    void complete() {
      if (!completer.isCompleted) completer.complete();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
        complete();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
        complete();
      },
    );

    try {
      ad.show();
    } catch (_) {
      complete();
    }

    await completer.future.timeout(
      const Duration(seconds: 90),
      onTimeout: complete,
    );
  }

  void _loadShellBanner() {
    if (_suppressBanners || !_sdkReady) {
      _disposeShellBanner();
      return;
    }
    try {
      _shellBannerAd?.dispose();
      _shellBannerAd = BannerAd(
        adUnitId: AdConstants.bannerAdUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) => notifyListeners(),
          onAdFailedToLoad: (ad, error) {
            debugPrint('Shell banner failed to load: $error');
            ad.dispose();
            if (identical(_shellBannerAd, ad)) {
              _shellBannerAd = null;
            }
            notifyListeners();
          },
        ),
      )..load();
      notifyListeners();
    } catch (e, st) {
      debugPrint('Shell banner load failed: $e\n$st');
      _shellBannerAd = null;
    }
  }

  void _loadFocusBreakBanner() {
    if (_suppressBanners || !_sdkReady || !_focusScreenOpen || !_focusBreakActive) {
      _disposeFocusBreakBanner();
      return;
    }
    if (_focusBreakBannerAd != null) return;
    try {
      _focusBreakBannerAd = BannerAd(
        adUnitId: AdConstants.bannerAdUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) => notifyListeners(),
          onAdFailedToLoad: (ad, error) {
            debugPrint('Focus break banner failed to load: $error');
            ad.dispose();
            if (identical(_focusBreakBannerAd, ad)) {
              _focusBreakBannerAd = null;
            }
            notifyListeners();
          },
        ),
      )..load();
      notifyListeners();
    } catch (e, st) {
      debugPrint('Focus break banner load failed: $e\n$st');
      _focusBreakBannerAd = null;
    }
  }

  void _loadInterstitial() {
    if (_bypassAllAds || !_sdkReady) return;
    try {
      InterstitialAd.load(
        adUnitId: AdConstants.interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd?.dispose();
            _interstitialAd = ad;
          },
          onAdFailedToLoad: (_) {},
        ),
      );
    } catch (e, st) {
      debugPrint('InterstitialAd.load failed: $e\n$st');
    }
  }

  void _loadRewarded() {
    if (_bypassAllAds || !_sdkReady) return;
    try {
      RewardedAd.load(
        adUnitId: AdConstants.rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd?.dispose();
            _rewardedAd = ad;
          },
          onAdFailedToLoad: (_) {},
        ),
      );
    } catch (e, st) {
      debugPrint('RewardedAd.load failed: $e\n$st');
    }
  }

  Future<void> _showInterstitial({VoidCallback? onDismissed}) async {
    if (!_sdkReady) return;
    final ad = _interstitialAd;
    if (ad == null) {
      _loadInterstitial();
      return;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
        onDismissed?.call();
      },
    );

    try {
      await ad.show();
    } catch (e, st) {
      debugPrint('Interstitial show failed: $e\n$st');
      ad.dispose();
      _interstitialAd = null;
      _loadInterstitial();
      onDismissed?.call();
    }
  }

  void _disposeShellBanner() {
    _shellBannerAd?.dispose();
    _shellBannerAd = null;
    notifyListeners();
  }

  void _disposeFocusBreakBanner() {
    _focusBreakBannerAd?.dispose();
    _focusBreakBannerAd = null;
    notifyListeners();
  }

  void _disposeAllAds() {
    _disposeShellBanner();
    _disposeFocusBreakBanner();
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }

  @override
  void dispose() {
    _disposeAllAds();
    super.dispose();
  }
}
