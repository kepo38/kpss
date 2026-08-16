import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/savings_constants.dart';
import '../data/kpss_curriculum.dart';
import '../models/content_models.dart';
import 'content_bank_service.dart';
import 'notification_service.dart';
import 'play_billing_service.dart';
import 'premium_service.dart';

/// Kullanıcının ücretsiz / reklamlı testlerden elde ettiği tahmini kazanç
/// ve 20 test kilometre taşı bildirimi.
class UserSavingsInsightService extends ChangeNotifier {
  UserSavingsInsightService._();
  static final UserSavingsInsightService instance = UserSavingsInsightService._();

  bool _initialized = false;
  bool _is20TestNotified = false;

  bool get isInitialized => _initialized;
  bool get is20TestNotified => _is20TestNotified;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _is20TestNotified =
        prefs.getBool(SavingsConstants.prefsIs20TestNotified) ?? false;
    _initialized = true;
    ContentBankService.instance.addListener(_onBankChanged);
    notifyListeners();
  }

  void _onBankChanged() => notifyListeners();

  /// Test tamamlandığında çağrılır — 20. test bildirimini tetikler.
  Future<void> handleTestCompleted() async {
    if (!_initialized || PremiumService.instance.isPremium) return;
    if (_is20TestNotified) return;

    final total = ContentBankService.instance.globalStats().totalAttempts;
    if (total < SavingsConstants.milestoneTotalTests) return;

    // Tekrar gönderilmesin diye önce bayrağı kalıcı olarak işaretle.
    await _mark20TestNotified();

    final savingsTl = monthlyAdSavingsTl > 0
        ? monthlyAdSavingsTl
        : lifetimeSavingsTl.clamp(
            SavingsConstants.milestoneTotalTests *
                SavingsConstants.adBonusTestValueTl,
            9999,
          ).round();

    await NotificationService.instance.showPremiumSavingsNotification(
      savingsTl: savingsTl,
    );
  }

  Future<void> _mark20TestNotified() async {
    _is20TestNotified = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SavingsConstants.prefsIs20TestNotified, true);
  }

  /// Ana ekran bilgi kutusu metni; premium kullanıcıda null.
  String? homeBannerMessage({required bool isPremium}) {
    if (isPremium) return null;

    final monthlyAd = monthlyAdTestsCount;
    final monthlySavings = monthlyAdSavingsTl;

    // Ay içinde reklamla anlamlı kazanç varsa öncelikli mesaj.
    if (monthlyAd >= SavingsConstants.milestoneTotalTests ||
        monthlySavings >= 150) {
      return 'Bu ay şimdiye kadar reklam izleyerek '
          '$monthlySavings liralık testi ücretsiz çözdün!';
    }

    final dailyTests = dailyFreeTestSlots;
    final dailyValue = dailyFreeValueTl;
    return 'Bugün $dailyValue TL değerindeki $dailyTests özgün testi '
        'tamamen ücretsiz çözüyorsun!';
  }

  /// Paywall üst metni.
  String paywallHeadline({String? monthlyPriceLabel}) {
    final profit = lifetimeSavingsTl;
    final monthly = monthlyPriceLabel ??
        '${SavingsConstants.paywallMonthlyHighlightTl} TL';
    return 'Zaten bugüne kadar $profit TL kâr ettin! '
        'Şimdi bu başarıyı taçlandır; aylık sadece $monthly\'ye '
        'bizzat hata yaptığın sorulardan oluşan sana özel Akıllı PDF '
        'dökümanını indir, sınavı riske atma.';
  }

  String get monthlyPriceLabelForPaywall {
    final product = PlayBillingService.instance.monthlyProduct;
    if (product != null && product.price.trim().isNotEmpty) {
      return product.price;
    }
    return '${SavingsConstants.paywallMonthlyHighlightTl} TL';
  }

  int get dailyFreeTestSlots =>
      SavingsConstants.missionSubjectIds.length *
      ContentBankService.dailyFreeTestsPerSubject;

  int get dailyFreeValueTl => dailyFreeTestSlots * SavingsConstants.freeTestValueTl;

  int get monthlyAdTestsCount =>
      _splitByQuota(_attemptsInCurrentMonth()).adCount;

  int get monthlyAdSavingsTl =>
      (monthlyAdTestsCount * SavingsConstants.adBonusTestValueTl).round();

  int get lifetimeSavingsTl {
    final split = _splitByQuota(ContentBankService.instance.allAttempts);
    final freeValue = split.freeCount * SavingsConstants.freeTestValueTl;
    final adValue =
        (split.adCount * SavingsConstants.adBonusTestValueTl).round();
    return freeValue + adValue;
  }

  List<TestAttemptModel> _attemptsInCurrentMonth() {
    final now = DateTime.now();
    return ContentBankService.instance.allAttempts.where((a) {
      final d = a.completedAt.toLocal();
      return d.year == now.year && d.month == now.month;
    }).toList();
  }

  /// Gün + ders kovası: ilk test ücretsiz, sonrakiler reklam hakkı.
  ({int freeCount, int adCount}) _splitByQuota(
    Iterable<TestAttemptModel> attempts,
  ) {
    final buckets = <String, List<TestAttemptModel>>{};
    for (final attempt in attempts) {
      final subjectId =
          KpssCurriculum.subjectIdForTopic(attempt.kpssType, attempt.topicId);
      if (subjectId == null) continue;
      final d = attempt.completedAt.toLocal();
      final key = '${d.year}-${d.month}-${d.day}_$subjectId';
      buckets.putIfAbsent(key, () => []).add(attempt);
    }

    var freeCount = 0;
    var adCount = 0;
    for (final list in buckets.values) {
      list.sort((a, b) => a.completedAt.compareTo(b.completedAt));
      for (var i = 0; i < list.length; i++) {
        if (i < ContentBankService.dailyFreeTestsPerSubject) {
          freeCount++;
        } else {
          adCount++;
        }
      }
    }
    return (freeCount: freeCount, adCount: adCount);
  }
}
