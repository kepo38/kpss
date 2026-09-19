import 'package:flutter/material.dart';

import '../constants/wrong_notebook_constants.dart';
import '../models/wrong_notebook_capacity_result.dart';
import '../widgets/pro_upsell_sheet.dart';

/// Yanlış defteri arşiv sınırı — Pro upsell.
class WrongNotebookCapacityUpsell {
  WrongNotebookCapacityUpsell._();

  static Future<void> maybeShowAfterAdd(
    BuildContext context,
    WrongNotebookCapacityResult result,
  ) async {
    if (!context.mounted || !result.shouldPromptUpsell) return;
    await _show(context);
  }

  static Future<void> showAtLimit(BuildContext context) async {
    if (!context.mounted) return;
    await _show(context);
  }

  static Future<void> _show(BuildContext context) {
    return ProUpsellSheet.show(
      context,
      emoji: '📒',
      title: 'YANLIŞ DEFTERİ',
      subtitle: WrongNotebookConstants.proUpsellSubtitle,
      cta: 'Pro Üye ol',
    );
  }
}
