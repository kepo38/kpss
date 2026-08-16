import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/services/content_sync_service.dart';
import 'package:kpss_akademi/services/iap_constants.dart';

void main() {
  test('yearly product id is distinct from monthly', () {
    expect(
      IapConstants.yearlySubscriptionId,
      isNot(IapConstants.monthlySubscriptionId),
    );
    expect(IapConstants.yearlySubscriptionId, contains('yearly'));
  });

  test('offline cache outcome marks success without download', () {
    const outcome = ContentSyncOutcome(
      success: true,
      downloaded: false,
      usedOfflineCache: true,
      message: 'İnternet yok · çevrimdışı paket kullanılıyor (v3).',
      remoteVersion: 3,
    );
    expect(outcome.success, isTrue);
    expect(outcome.usedOfflineCache, isTrue);
    expect(outcome.downloaded, isFalse);
  });
}
