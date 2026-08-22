import 'package:flutter/material.dart';

import '../models/tg_exam_models.dart';
import '../screens/tg_exam/tg_exam_result_screen.dart';
import '../services/ad_service.dart';
import '../services/auth_service.dart';
import 'account_link_card.dart';

/// TG deneme erişim kapıları — Google hesabı + detaylı analiz reklamı.
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

  /// Detaylı istatistik / Türkiye geneli sıralama — ödüllü reklam (Premium ücretsiz).
  static Future<bool> requireAnalysisAd(
    BuildContext context, {
    required int examId,
  }) async {
    final earned = await AdService.showRewardedAd(
      kind: AdRewardKind.tgExamDetailedAnalysis,
      examId: examId,
    );
    if (earned) return true;
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Detaylı istatistik ve sıralama için kısa bir reklam izlemeniz gerekir.',
        ),
      ),
    );
    return false;
  }

  /// Reklam (veya Premium) sonrası [TgExamResultScreen] açar.
  static Future<void> openDetailedAnalysis(
    BuildContext context,
    TgExamModel exam,
  ) async {
    if (!exam.canAccessDetailedAnalysis) return;
    final ok = await requireAnalysisAd(context, examId: exam.id);
    if (!ok || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TgExamResultScreen(exam: exam),
      ),
    );
  }
}
