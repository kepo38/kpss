import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/services/notification_service.dart';

void main() {
  test('saat gelmediyse aynı gün, geçtiyse ertesi gün', () {
    expect(
      nextDailyFire(DateTime(2026, 8, 13, 8, 59), hour: 9),
      DateTime(2026, 8, 13, 9),
    );
    expect(
      nextDailyFire(DateTime(2026, 8, 13, 9), hour: 9),
      DateTime(2026, 8, 14, 9),
    );
    expect(
      nextDailyFire(DateTime(2026, 8, 13, 20, 0), hour: 21),
      DateTime(2026, 8, 13, 21),
    );
  });
}
