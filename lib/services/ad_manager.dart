import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_constants.dart';
import 'ad_free_campaign_service.dart';

/// Reklam ve adil fiyatlandırma mimarisi.
///
/// Kurallar:
/// - Test/ders ortasında interstitial YOK
/// - Test ekranında yalnızca altta küçük banner
/// - Her 3 sayfa geçişinde bir kapatılabilir interstitial
/// - Ödüllü video ile çözüm kilidi (test bitene kadar önbellekte)
/// - isPremium == true → tüm reklamlar bypass
/// - 12 saat kampanya → yalnızca banner; çözüm/kota/interstitial durur
class AdManager {
  AdManager._();
  static final AdManager instance = AdManager._();

  bool _isPremium = false;
  bool _isInTestSession = false;
  bool _adFreeTestSession = false;
  bool _skipNextPageTransition = false;
  int _pageTransitionCount = 0;

  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  /// Test oturumu boyunca ödüllü reklamla açılan çözüm ID'leri.
  final Set<String> _unlockedSolutionIds = {};

  bool get isPremium => _isPremium;
  bool get isInTestSession => _isInTestSession;
  bool get isAdFreeActive => AdFreeCampaignService.instance.isAdFreeActive;
  bool get _bypassAllAds => _isPremium || kIsWeb;
  bool get _suppressBanners =>
      _bypassAllAds || AdFreeCampaignService.instance.isAdFreeActive;
  BannerAd? get bannerAd => _suppressBanners ? null : _bannerAd;

  void setPremium(bool value) {
    _isPremium = value;
    if (value) {
      _disposeAllAds();
    }
  }

  Future<void> initialize() async {
    if (_bypassAllAds) return;
    await MobileAds.instance.initialize();
    _loadInterstitial();
    _loadRewarded();
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
    if (_suppressBanners || adFreeExperience) return;
    _loadBanner();
  }

  /// Test oturumu bittiğinde çağrılır.
  void endTestSession() {
    _isInTestSession = false;
    _adFreeTestSession = false;
    _unlockedSolutionIds.clear();
    _disposeBanner();
  }

  /// Sayfa geçişlerinde sayaç — her 3'te bir interstitial.
  Future<void> onPageTransition({VoidCallback? onAdDismissed}) async {
    if (_bypassAllAds || _isInTestSession) return;

    if (_skipNextPageTransition) {
      _skipNextPageTransition = false;
      return;
    }

    _pageTransitionCount++;
    if (_pageTransitionCount % AdConstants.pageTransitionAdInterval != 0) {
      return;
    }

    await _showInterstitial(onDismissed: onAdDismissed);
  }

  /// 12 saat reklamsız kampanya — ana sayfa progress bar.
  Future<bool> requestCampaignRewardedAd() async {
    if (_bypassAllAds || isAdFreeActive) return false;
    final earned = await _showRewardedVideo();
    if (!earned) return false;

    await AdFreeCampaignService.instance.onRewardedAdCompleted();
    if (AdFreeCampaignService.instance.isAdFreeActive) {
      _disposeBanner();
    }
    return true;
  }

  /// Detaylı çözüm kilidi — ödüllü reklam veya önbellek.
  Future<bool> requestSolutionUnlock(String questionId) async {
    if (_isPremium || _adFreeTestSession) return true;
    if (_unlockedSolutionIds.contains(questionId)) return true;

    final earned = await _showRewardedVideo();
    if (earned) {
      _unlockedSolutionIds.add(questionId);
    }
    return earned;
  }

  /// Günlük test hakkı bittiğinde +1 test için ödüllü video (~30 sn).
  Future<bool> requestDailyTestBonus() async {
    if (_bypassAllAds) return false;
    return _showRewardedVideo();
  }

  Future<bool> _showRewardedVideo() async {
    if (_bypassAllAds) return false;

    final cachedAd = _rewardedAd;
    if (cachedAd != null) {
      _rewardedAd = null;
      return _presentRewardedAd(cachedAd);
    }

    final loadCompleter = Completer<RewardedAd?>();
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

    final loadedAd = await loadCompleter.future.timeout(
      const Duration(seconds: 20),
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

    return completer.future;
  }

  bool isSolutionUnlocked(String questionId) {
    return _isPremium ||
        _adFreeTestSession ||
        _unlockedSolutionIds.contains(questionId);
  }

  /// Test bitişinde (Bitir) premium olmayan kullanıcılara tam ekran reklam.
  Future<void> showTestCompletionInterstitial() async {
    if (_bypassAllAds || _adFreeTestSession) return;

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
    if (_suppressBanners) return;
    _bannerAd?.dispose();
    _bannerAd = BannerAd(
      adUnitId: AdConstants.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    )..load();
  }

  void _loadInterstitial() {
    if (_bypassAllAds) return;
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
  }

  void _loadRewarded() {
    if (_bypassAllAds) return;
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
  }

  Future<void> _showInterstitial({VoidCallback? onDismissed}) async {
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
      },
    );

    await ad.show();
  }

  void _disposeBanner() {
    _bannerAd?.dispose();
    _bannerAd = null;
  }

  void _disposeAllAds() {
    _disposeBanner();
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }

  void dispose() {
    _disposeAllAds();
  }
}
