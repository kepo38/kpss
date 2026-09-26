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

  test('does not hyphenate inside latex math delimiters', () {
    const array =
        r'$$\displaystyle \begin{array}{r} AB8 \\ -16C \\ \hline CA3 \end{array}$$';
    final out = TurkishHyphenation.hyphenate(array);
    expect(out, array);
    expect(out.contains(TurkishHyphenation.softHyphen), isFalse);

    const mixed =
        r'İlköğretimde $A + B + C$ ve $$\begin{array}{r} x \\ y \end{array}$$ vardır.';
    final mixedOut = TurkishHyphenation.hyphenate(mixed);
    expect(mixedOut, contains(r'$A + B + C$'));
    expect(mixedOut, contains(r'$$\begin{array}{r} x \\ y \end{array}$$'));
    expect(mixedOut.contains(r'\begin'), isTrue);
    // Prose outside math still hyphenates.
    expect(mixedOut.contains(TurkishHyphenation.softHyphen), isTrue);
  });
}
