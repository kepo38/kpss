import 'package:flutter/foundation.dart';

import 'ad_manager.dart';

/// UI’dan ödüllü reklam — load/show kodu widget’a yazılmaz.
enum AdRewardKind {
  campaign,
  solutionUnlock,
  dailyTestBonus,
}

class AdService {
  AdService._();

  static Future<bool> showRewardedAd({
    AdRewardKind kind = AdRewardKind.dailyTestBonus,
    String? questionId,
    VoidCallback? onComplete,
  }) async {
    final ads = AdManager.instance;
    final earned = switch (kind) {
      AdRewardKind.campaign => await ads.requestCampaignRewardedAd(),
      AdRewardKind.solutionUnlock =>
        await ads.requestSolutionUnlock(questionId ?? ''),
      AdRewardKind.dailyTestBonus => await ads.requestDailyTestBonus(),
    };
    if (earned) onComplete?.call();
    return earned;
  }
}
