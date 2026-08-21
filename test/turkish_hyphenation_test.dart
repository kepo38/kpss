import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/utils/turkish_hyphenation.dart';

void main() {
  String v(String s) => TurkishHyphenation.visibleBreaks(s);

  test('bitişik kelimeler ulama ile hecelenir', () {
    expect(v('ilkokul'), 'il-ko-kul');
    expect(v('başöğretmen'), 'ba-şöğ-ret-men');
  });

  test('klasik hece örnekleri', () {
    expect(v('Ankara'), 'An-ka-ra');
    expect(v('deneme'), 'de-ne-me');
    expect(v('Türkçe'), 'Türk-çe');
  });

  test('satır başı/sonunda tek harf bırakılmaz', () {
    // a-ra-ba teorik; a- satır sonunda yasak → ara-ba
    expect(v('araba'), 'ara-ba');
    final broken = TurkishHyphenation.hyphenate('ilkokul');
    for (final part in broken.split(TurkishHyphenation.softHyphen)) {
      expect(part.length, greaterThanOrEqualTo(2));
    }
  });

  test('cümle içinde yalnızca sözcükleri işler', () {
    expect(
      v('Bu bir ilkokul örneğidir.'),
      'Bu bir il-ko-kul ör-ne-ği-dir.',
    );
  });
}
