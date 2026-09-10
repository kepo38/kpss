import 'package:flutter/material.dart';

import '../models/tg_exam_models.dart';
import '../screens/tg_exam/tg_exam_result_screen.dart';
import '../services/auth_service.dart';
import '../services/premium_service.dart';
import '../services/tg_exam_analysis_helper.dart';
import 'account_link_card.dart';
import 'pro_upsell_sheet.dart';

/// TG deneme erişim kapıları — Google hesabı + detaylı analiz Pro.
class TgExamGates {
  TgExamGates._();

  /// Google ile kalıcı hesap yoksa sheet açar; başarısızsa false.
  static Future<bool> requireGoogleAccount(BuildContext context) async {
    if (AuthService.instance.hasPermanentAccount) return true;
    final ok = await AccountLinkCard.prompt(
      context,
      title: 'Türkiye Geneli için Google gerekli',
      subtitle:
          'TG denemelere katılmak ve sıralamanızın hesabınıza bağlanması '
          'için Google ile giriş yapın. Misafir hesapla giriş yapılamaz.',
      allowSkip: false,
    );
    return ok && AuthService.instance.hasPermanentAccount;
  }

  /// Detaylı istatistik / Türkiye geneli sıralama — Pro üyelik gerekir.
  static Future<bool> requireProAnalysis(BuildContext context) async {
    if (PremiumService.instance.isPremium) return true;
    await ProUpsellSheet.show(
      context,
      emoji: '📊',
      title: 'TÜRKİYE GENELİ ANALİZ',
      subtitle: TgExamAnalysisHelper.proUpsellSubtitle,
      cta: 'Pro Üyeliğe Geç',
    );
    return PremiumService.instance.isPremium;
  }

  /// Pro sonrası [TgExamResultScreen] açar.
  static Future<void> openDetailedAnalysis(
    BuildContext context,
    TgExamModel exam,
  ) async {
    if (!exam.canAccessDetailedAnalysis) return;
    final ok = await requireProAnalysis(context);
    if (!ok || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TgExamResultScreen(exam: exam),
      ),
    );
  }
}
