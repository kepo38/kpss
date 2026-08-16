import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/widgets/countdown_widget.dart';

void main() {
  test('AGS sayacı KPSS lisans tarihinden bağımsızdır', () {
    final ags = ExamTrack.defaults.firstWhere((e) => e.id == 'ags');
    final kpss = ExamTrack.defaults.firstWhere((e) => e.id == 'kpssLisans');
    expect(ags.nextExamDate(DateTime(2026, 8, 13)), DateTime(2027, 7, 26));
    expect(kpss.nextExamDate(DateTime(2026, 8, 13)), DateTime(2026, 9, 6));
    expect(ags.contentType, KpssType.lisans);
  });

  test('Ön lisans ve ortaöğretim yalnızca çift yıllarda', () {
    final onLisans =
        ExamTrack.defaults.firstWhere((e) => e.id == 'kpssOnLisans');
    final orta =
        ExamTrack.defaults.firstWhere((e) => e.id == 'kpssOrtaogretim');
    final lisans =
        ExamTrack.defaults.firstWhere((e) => e.id == 'kpssLisans');

    expect(onLisans.nextExamDate(DateTime(2026, 8, 13)), DateTime(2026, 10, 4));
    expect(onLisans.nextExamDate(DateTime(2026, 10, 5)), DateTime(2028, 10, 4));
    expect(onLisans.nextExamDate(DateTime(2027, 3, 1)), DateTime(2028, 10, 4));
    expect(orta.nextExamDate(DateTime(2027, 1, 1)), DateTime(2028, 10, 25));
    expect(lisans.nextExamDate(DateTime(2026, 9, 7)), DateTime(2027, 9, 6));
  });

  test('JSON katalogdan yeni sınav tipi okunur', () {
    final track = ExamTrack.fromJson({
      'id': 'ales',
      'name': 'ALES',
      'shortName': 'ALES',
      'description': 'Akademik Personel',
      'examDate': '2026-11-15',
      'yearlyRepeat': true,
      'contentType': 'lisans',
      'iconKey': 'star',
      'sortOrder': 50,
      'isActive': true,
    });
    expect(track.id, 'ales');
    expect(track.nextExamDate(DateTime(2026, 8, 13)), DateTime(2026, 11, 15));
  });

  test('ALES ve DGS yerel sınav kataloğunda bulunur', () {
    final ales = ExamTrack.defaults.firstWhere((e) => e.id == 'ales');
    final dgs = ExamTrack.defaults.firstWhere((e) => e.id == 'dgs');

    expect(ales.nextExamDate(DateTime(2026, 8, 14)), DateTime(2026, 11, 29));
    expect(ales.hasUpcomingDate(DateTime(2026, 8, 14)), isTrue);
    expect(ales.hasUpcomingDate(DateTime(2026, 11, 29, 12)), isTrue);
    expect(ales.hasUpcomingDate(DateTime(2026, 11, 30)), isFalse);
    expect(dgs.hasUpcomingDate(DateTime(2026, 8, 14)), isFalse);
    expect(ales.contentType, KpssType.lisans);
    expect(dgs.contentType, KpssType.lisans);
  });
}
