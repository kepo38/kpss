import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/utils/daily_mission_copy.dart';

void main() {
  test('sabah metni sabit kopyadır', () {
    expect(
      DailyMissionCopy.morningBody,
      contains('Tarih ve Coğrafya barlarını yeşile boyamak'),
    );
    expect(DailyMissionCopy.morningHour, 9);
    expect(DailyMissionCopy.eveningHour, 21);
  });

  test('gece FOMO kalan ders adını yerleştirir', () {
    expect(
      DailyMissionCopy.eveningBody('Coğrafya'),
      'Harikasın! Bugün 4 görevi tamamladın. Son 1 test kaldı. '
      'Gece 00:00\'da hakların sıfırlanmadan önce Coğrafya '
      'barını da yeşille ve bugünü firesiz kapat! 🔥',
    );
  });

  test('yalnızca 4 dolu 1 kalan FOMO tetikler', () {
    const ready = DailyMissionProgress(
      done: 4,
      total: 5,
      remainingNames: ['Coğrafya'],
    );
    expect(ready.isFourDoneOneLeft, isTrue);
    expect(ready.remainingName, 'Coğrafya');

    const tooEarly = DailyMissionProgress(
      done: 3,
      total: 5,
      remainingNames: ['Tarih', 'Coğrafya'],
    );
    expect(tooEarly.isFourDoneOneLeft, isFalse);

    const done = DailyMissionProgress(
      done: 5,
      total: 5,
      remainingNames: [],
    );
    expect(done.isFourDoneOneLeft, isFalse);
  });
}
