import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_constants.dart';
import 'ad_free_campaign_service.dart';
import 'app_config_service.dart';
import 'app_preferences.dart';

/// Reklam ve adil fiyatlandırma mimarisi.
///
/// Kurallar:
/// - Test/ders ortasında interstitial YOK
/// - Test ekranında yalnızca altta küçük banner
/// - Her 3 sayfa geçişinde bir kapatılabilir interstitial
/// - Ödüllü video ile çözüm kilidi (testte ilk 4 ücretsiz; 5.+ her biri reklam)
/// - isPremium == true → tüm reklamlar bypass
/// - 12 saat kampanya → yalnızca banner; çözüm/kota/interstitial durur
/// - Panel `bannerAdsEnabled=false` → yalnızca quiz banner kapalı
class AdManager extends ChangeNotifier {
  AdManager._();
  static final AdManager instance = AdManager._();

  bool _isPremium = false;
  bool _isInTestSession = false;
  bool _adFreeTestSession = false;
  bool _skipNextPageTransition = false;
  int _pageTransitionCount = 0;
  bool _sdkReady = false;

  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  /// Test oturumu boyunca açılan tam çözüm soru ID'leri (ücretsiz veya reklam).
  final Set<String> _unlockedSolutionIds = {};

  /// Bu turda kalan ücretsiz tam çözüm hakkı (reklam sonrası yenilenir).
  int _freeSolutionCredits = AdConstants.freeSolutionsPerTest;

  bool get isPremium => _isPremium;
  bool get isSdkReady => _sdkReady || _bypassAllAds;
  bool get isInTestSession => _isInTestSession;
  bool get isAdFreeActive => AdFreeCampaignService.instance.isAdFreeActive;
  bool get _bypassAllAds => _isPremium || kIsWeb;
  bool get _panelBannersOff => !AppConfigService.instance.bannerAdsEnabled;
  bool get _suppressBanners =>
      _bypassAllAds ||
      AdFreeCampaignService.instance.isAdFreeActive ||
      _panelBannersOff;
  BannerAd? get bannerAd => _suppressBanners ? null : _bannerAd;

  void setPremium(bool value) {
    _isPremium = value;
    if (value) {
      _disposeAllAds();
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
      _retryBannerIfInTestSession();
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

  /// Test oturumu başladığında çağrılır — interstitial devre dışı kalır.
  /// [adFreeExperience]: çözüm kilidi, banner ve bitiş reklamı yok (Günün Denemesi).
  void startTestSession({bool adFreeExperience = false}) {
    _isInTestSession = true;
    _adFreeTestSession = adFreeExperience;
    _unlockedSolutionIds.clear();
    _freeSolutionCredits = AdConstants.freeSolutionsPerTest;
    // Panel banner bayrağı bir sonraki teste yansısın.
    unawaited(_startTestSessionAds(adFreeExperience: adFreeExperience));
  }

  Future<void> _startTestSessionAds({required bool adFreeExperience}) async {
    await AppConfigService.instance.refresh();
    if (!_isInTestSession) return;
    if (_suppressBanners || adFreeExperience || _adFreeTestSession) {
      _disposeBanner();
      notifyListeners();
      return;
    }
    _loadBanner();
    notifyListeners();
  }

  /// SDK geç hazır olduysa (telefonda hızlı test açılışı) banner'ı tekrar dene.
  void _retryBannerIfInTestSession() {
    if (!_isInTestSession || _adFreeTestSession || _suppressBanners) return;
    if (_bannerAd != null) return;
    _loadBanner();
  }

  /// Test oturumu bittiğinde çağrılır.
  void endTestSession() {
    _isInTestSession = false;
    _adFreeTestSession = false;
    _unlockedSolutionIds.clear();
    _freeSolutionCredits = AdConstants.freeSolutionsPerTest;
    _disposeBanner();
  }

  /// Sayfa geçişlerinde sayaç — her 3'te bir interstitial.
  Future<void> onPageTransition({VoidCallback? onAdDismissed}) async {
    if (_bypassAllAds || _isInTestSession || !_sdkReady) return;

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
      _disposeBanner();
      notifyListeners();
    }
    return true;
  }

  /// Detaylı çözüm kilidi — testte ilk [AdConstants.freeSolutionsPerTest]
  /// ücretsiz; 5. ve sonrası her tam çözüm için ödüllü reklam.
  /// Açılanlar oturum boyunca önbellekte; sıra karışık da sayılır.
  Future<bool> requestSolutionUnlock(String questionId) async {
    if (ensureFreeSolutionUnlock(questionId)) return true;

    final earned = await _showRewardedVideo();
    if (earned) {
      _unlockedSolutionIds.add(questionId);
    }
    return earned;
  }

  /// Kota varsa reklam olmadan tam çözümü açar. Zaten açıksa true.
  bool ensureFreeSolutionUnlock(String questionId) {
    if (questionId.isEmpty) return false;
    if (_isPremium || _adFreeTestSession) {
      _unlockedSolutionIds.add(questionId);
      return true;
    }
    if (_unlockedSolutionIds.contains(questionId)) return true;
    if (_freeSolutionCredits > 0) {
      _unlockedSolutionIds.add(questionId);
      _freeSolutionCredits--;
      return true;
    }
    return false;
  }

  /// Bu testte kalan ücretsiz tam çözüm hakkı (reklamla açılanlar düşmez).
  int get freeSolutionUnlocksRemaining {
    if (_isPremium || _adFreeTestSession) {
      return AdConstants.freeSolutionsPerTest;
    }
    return _freeSolutionCredits < 0 ? 0 : _freeSolutionCredits;
  }

  /// Günlük test hakkı bittiğinde +1 test için ödüllü video (~30 sn).
  Future<bool> requestDailyTestBonus() async {
    if (_bypassAllAds) return false;
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

  void _loadBanner() {
    if (_suppressBanners || !_sdkReady) {
      _disposeBanner();
      return;
    }
    try {
      _bannerAd?.dispose();
      _bannerAd = BannerAd(
        adUnitId: AdConstants.bannerAdUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) => notifyListeners(),
          onAdFailedToLoad: (ad, error) {
            debugPrint('BannerAd failed to load: $error');
            ad.dispose();
            if (identical(_bannerAd, ad)) {
              _bannerAd = null;
            }
            notifyListeners();
          },
        ),
      )..load();
      notifyListeners();
    } catch (e, st) {
      debugPrint('BannerAd load failed: $e\n$st');
      _bannerAd = null;
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

  void _disposeBanner() {
    _bannerAd?.dispose();
    _bannerAd = null;
    notifyListeners();
  }

  void _disposeAllAds() {
    _disposeBanner();
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
