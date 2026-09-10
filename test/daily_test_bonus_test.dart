import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/models/content_models.dart';
import 'package:kpss_akademi/services/content_bank_service.dart';
import 'package:kpss_akademi/widgets/countdown_widget.dart';

void main() {
  test('daily bonus key includes type, subject and local date', () {
    final key = ContentBankService.dailyBonusStorageKeyFor(
      KpssType.lisans,
      'mat',
      DateTime(2026, 8, 9, 15, 30),
    );
    expect(key, 'lisans_mat_2026-08-09');
  });

  test('quota constants define one free and one ad bonus per subject', () {
    expect(ContentBankService.dailyFreeTestsPerSubject, 1);
    expect(ContentBankService.dailyAdBonusPerSubject, 1);
  });

  test('free quota locks after one completed test', () {
    expect(
      ContentBankService.hasDailyTestQuota(
        completedTests: 0,
        adBonusTests: 0,
      ),
      isTrue,
    );
    expect(
      ContentBankService.hasDailyTestQuota(
        completedTests: 1,
        adBonusTests: 0,
      ),
      isFalse,
    );
  });

  test('one ad bonus unlocks exactly one additional test', () {
    expect(
      ContentBankService.canEarnDailyAdBonus(
        completedTests: 1,
        adBonusTests: 0,
      ),
      isTrue,
    );
    expect(
      ContentBankService.hasDailyTestQuota(
        completedTests: 1,
        adBonusTests: 1,
      ),
      isTrue,
    );
    expect(
      ContentBankService.hasDailyTestQuota(
        completedTests: 2,
        adBonusTests: 1,
      ),
      isFalse,
    );
    expect(
      ContentBankService.canEarnDailyAdBonus(
        completedTests: 2,
        adBonusTests: 1,
      ),
      isFalse,
    );
  });

  test('cihaz ücretsiz hakkı yanığı misafir→Google çift kullanımı engeller', () {
    expect(
      ContentBankService.effectiveCompletedForQuota(
        userCompleted: 0,
        deviceFreeConsumed: 1,
      ),
      ContentBankService.dailyFreeTestsPerSubject,
    );
    expect(
      ContentBankService.hasDailyTestQuota(
        completedTests: ContentBankService.effectiveCompletedForQuota(
          userCompleted: 0,
          deviceFreeConsumed: 1,
        ),
        adBonusTests: 0,
      ),
      isFalse,
    );
    expect(
      ContentBankService.hasDailyTestQuota(
        completedTests: ContentBankService.effectiveCompletedForQuota(
          userCompleted: 0,
          deviceFreeConsumed: 1,
        ),
        adBonusTests: 1,
      ),
      isTrue,
    );
  });

  test('Google hesap yanığı telefon/tablet senkronunu temsil eder', () {
    expect(
      ContentBankService.effectiveCompletedForQuota(
        userCompleted: 0,
        deviceFreeConsumed: 0,
        accountFreeConsumed: 1,
      ),
      ContentBankService.dailyFreeTestsPerSubject,
    );
    expect(
      ContentBankService.hasDailyTestQuota(
        completedTests: ContentBankService.effectiveCompletedForQuota(
          userCompleted: 0,
          deviceFreeConsumed: 0,
          accountFreeConsumed: 1,
        ),
        adBonusTests: 0,
      ),
      isFalse,
    );
  });

  test('Google A cihaz yanığı üretmez; yalnız misafir cihaz yanığı Google’ı keser',
      () {
    // Google A→B: cihaz=0, hesap B=0 → hak var
    expect(
      ContentBankService.hasDailyTestQuota(
        completedTests: ContentBankService.effectiveCompletedForQuota(
          userCompleted: 0,
          deviceFreeConsumed: 0,
          accountFreeConsumed: 0,
        ),
        adBonusTests: 0,
      ),
      isTrue,
    );
    // Misafir yakmış → cihaz=1 → Google de kilitli (çift hak yok)
    expect(
      ContentBankService.hasDailyTestQuota(
        completedTests: ContentBankService.effectiveCompletedForQuota(
          userCompleted: 0,
          deviceFreeConsumed: 1,
          accountFreeConsumed: 0,
        ),
        adBonusTests: 0,
      ),
      isFalse,
    );
  });

  test('günün denemesi bugünkü ödeve sayılmaz', () {
    TestAttemptModel attempt({required String testId}) {
      return TestAttemptModel(
        id: 'a1',
        testId: testId,
        topicId: 'turkce_anlam',
        kpssType: KpssType.lisans,
        correct: 16,
        wrong: 4,
        blank: 0,
        total: 20,
        duration: const Duration(minutes: 12),
        completedAt: DateTime(2026, 8, 14, 9),
      );
    }

    expect(
      ContentBankService.countsTowardDailyHomework(
        attempt(testId: 'daily_mini_2026-08-14_lisans'),
      ),
      isFalse,
    );
    expect(
      ContentBankService.countsTowardDailyHomework(
        attempt(testId: 'topic_turkce_anlam_1'),
      ),
      isTrue,
    );
  });
}
