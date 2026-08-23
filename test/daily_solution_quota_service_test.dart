import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/services/ad_constants.dart';
import 'package:kpss_akademi/services/daily_solution_quota_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('DailySolutionQuotaService', () {
    test('allows up to daily limit distinct questions', () async {
      final svc = DailySolutionQuotaService.instance;
      for (var i = 0; i < AdConstants.freeDetailedSolutionsPerDay; i++) {
        expect(await svc.tryUnlock('q_$i'), isTrue);
      }
      expect(await svc.usedToday(), AdConstants.freeDetailedSolutionsPerDay);
      expect(await svc.remainingToday(), 0);
      expect(await svc.tryUnlock('q_extra'), isFalse);
    });

    test('re-opening same question does not consume extra slot', () async {
      final svc = DailySolutionQuotaService.instance;
      expect(await svc.tryUnlock('q_same'), isTrue);
      expect(await svc.tryUnlock('q_same'), isTrue);
      expect(await svc.usedToday(), 1);
    });
  });
}
