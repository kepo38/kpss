import 'package:flutter/foundation.dart';

import 'ad_manager.dart';

/// UI’dan ödüllü reklam — load/show kodu widget’a yazılmaz.
enum AdRewardKind {
  campaign,
  solutionUnlock,
  dailyTestBonus,
  wrongNotebookShare,
  tgExamDetailedAnalysis,
}

class AdService {
  AdService._();

  static Future<bool> showRewardedAd({
    AdRewardKind kind = AdRewardKind.dailyTestBonus,
    String? questionId,
    int? examId,
    VoidCallback? onComplete,
  }) async {
    final ads = AdManager.instance;
    final earned = switch (kind) {
      AdRewardKind.campaign => await ads.requestCampaignRewardedAd(),
      AdRewardKind.solutionUnlock =>
        await ads.requestSolutionUnlock(questionId ?? ''),
      AdRewardKind.dailyTestBonus => await ads.requestDailyTestBonus(),
      AdRewardKind.wrongNotebookShare =>
        await ads.requestWrongNotebookShareUnlock(),
      AdRewardKind.tgExamDetailedAnalysis =>
        await ads.requestTgExamAnalysisUnlock(examId ?? 0),
    };
    if (earned) onComplete?.call();
    return earned;
  }
}
