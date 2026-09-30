import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/utils/turkish_hyphenation.dart';

void main() {
  String v(String s) => TurkishHyphenation.visibleBreaks(s);

  const style = TextStyle(fontSize: 18, fontFamily: 'Roboto', height: 1.35);

  Set<int> lineEndHyphenIndices(
    String text, {
    required double maxWidth,
    TextAlign align = TextAlign.start,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    final ends = <int>{};
    var offset = 0;
    var guard = 0;
    while (offset < text.length && guard++ < text.length + 4) {
      final b = painter.getLineBoundary(TextPosition(offset: offset));
      if (b.end <= offset) break;
      if (b.end < text.length && b.end > 0 && text[b.end - 1] == '-') {
        ends.add(b.end - 1);
      }
      offset = b.end;
    }
    return ends;
  }

  List<int> midLineHyphens(
    String text, {
    required double maxWidth,
    TextAlign align = TextAlign.start,
  }) {
    final dashes = <int>[
      for (var i = 0; i < text.length; i++)
        if (text[i] == '-') i,
    ];
    final ends = lineEndHyphenIndices(text, maxWidth: maxWidth, align: align);
    return dashes.where((i) => !ends.contains(i)).toList();
  }

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
    expect(mixedOut.contains(TurkishHyphenation.softHyphen), isTrue);
  });

  test('wide width: no visible syllable dashes', () {
    final hyphenated = TurkishHyphenation.hyphenate('Ankara');
    final wide = TurkishHyphenation.applyVisibleLineBreakHyphens(
      hyphenated,
      maxWidth: 400,
      style: style,
    );
    expect(wide, 'Ankara');
    expect(wide.contains(TurkishHyphenation.softHyphen), isFalse);
  });

  test('justify prose: no mid-line syllable dashes after reflow', () {
    final prose = TurkishHyphenation.hyphenate(
      'Bu soruda yukarıdakilerden hangisi doğrudur diye sorulmaktadır.',
    );
    const maxWidth = 340.0;
    final out = TurkishHyphenation.applyVisibleLineBreakHyphens(
      prose,
      maxWidth: maxWidth,
      style: style,
      textAlign: TextAlign.justify,
    );

    expect(out.contains(TurkishHyphenation.softHyphen), isFalse);
    expect(
      midLineHyphens(out, maxWidth: maxWidth, align: TextAlign.justify),
      isEmpty,
      reason: out,
    );
    // Harfler korunur (hece tireleri budansa bile).
    expect(
      out.replaceAll('-', ''),
      prose.replaceAll(TurkishHyphenation.softHyphen, ''),
    );
  });

  test('narrow long word: dashes only at surviving line ends', () {
    final hyphenated = TurkishHyphenation.hyphenate(
      'yukarıdakilerdenhangisidir',
    );
    const maxWidth = 72.0;
    final withDash = TurkishHyphenation.applyVisibleLineBreakHyphens(
      hyphenated,
      maxWidth: maxWidth,
      style: style,
    );

    expect(withDash.contains(TurkishHyphenation.softHyphen), isFalse);
    expect(
      midLineHyphens(withDash, maxWidth: maxWidth),
      isEmpty,
      reason: withDash,
    );
    expect(
      withDash.replaceAll('-', ''),
      hyphenated.replaceAll(TurkishHyphenation.softHyphen, ''),
    );
  });

  test('preserves intentional hyphens in source text', () {
    final src = TurkishHyphenation.hyphenate('zarf-fiil örneğidir');
    final out = TurkishHyphenation.applyVisibleLineBreakHyphens(
      src,
      maxWidth: 400,
      style: style,
    );
    expect(out.contains('zarf-fiil'), isTrue);
  });
}
