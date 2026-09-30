import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/utils/line_break_hyphens.dart';
import 'package:kpss_akademi/utils/turkish_hyphenation.dart';

void main() {
  const root = TextStyle(fontFamily: 'Roboto', fontSize: 9, letterSpacing: 0.25);
  const bold = TextStyle(fontWeight: FontWeight.bold);

  String plainOf(List<InlineSpan> spans) =>
      TextSpan(children: spans).toPlainText(includeSemanticsLabels: false);

  List<InlineSpan> spansFor(String text) => [
        TextSpan(text: TurkishHyphenation.hyphenate('Bu soruda ')),
        TextSpan(text: TurkishHyphenation.hyphenate(text), style: bold),
        TextSpan(
          text: TurkishHyphenation.hyphenate(
            ' hangisi doğrudur diye sorulmaktadır; değerlendirilebilir.',
          ),
        ),
      ];

  void expectConsistent(List<InlineSpan> resolved, double width) {
    final plain = plainOf(resolved);
    final painter = TextPainter(
      text: TextSpan(style: root, children: resolved),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.justify,
    )..layout(maxWidth: width);
    final ends = <int>{};
    var offset = 0;
    while (offset < plain.length) {
      final b = painter.getLineBoundary(TextPosition(offset: offset));
      if (b.end <= offset) break;
      if (b.end < plain.length) ends.add(b.end);
      offset = b.end;
    }
    for (final e in ends) {
      expect(plain[e - 1] == TurkishHyphenation.softHyphen, isFalse,
          reason: 'width=$width soft hyphen at line end @${e - 1}: $plain');
    }
    for (var i = 0; i < plain.length; i++) {
      if (plain[i] == '-') {
        expect(ends.contains(i + 1), isTrue,
            reason: 'width=$width mid-line dash @$i in "$plain"');
      }
    }
    painter.dispose();
  }

  test('her genişlikte tireler yalnızca satır sonunda kalır', () {
    for (var w = 120.0; w <= 420.0; w += 3) {
      final resolved = LineBreakHyphens.resolve(
        children: spansFor('yukarıdakilerden'),
        rootStyle: root,
        maxWidth: w,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.justify,
      );
      expectConsistent(resolved, w);
    }
  });

  test('geniş alanda görünür tire çıkmaz, harfler korunur', () {
    final src = spansFor('yukarıdakilerden');
    final resolved = LineBreakHyphens.resolve(
      children: src,
      rootStyle: root,
      maxWidth: 2000,
      textDirection: TextDirection.ltr,
    );
    final plain = plainOf(resolved);
    expect(plain.contains('-'), isFalse);
    expect(plain, plainOf(src).replaceAll(TurkishHyphenation.softHyphen, ''));
  });

  test('kaynaktaki gerçek tireler korunur', () {
    final resolved = LineBreakHyphens.resolve(
      children: [TextSpan(text: TurkishHyphenation.hyphenate('zarf-fiil örneği'))],
      rootStyle: root,
      maxWidth: 2000,
      textDirection: TextDirection.ltr,
    );
    expect(plainOf(resolved), contains('zarf-fi'));
  });

  test('WidgetSpan varsa tireler tamamen kaldırılır', () {
    final resolved = LineBreakHyphens.resolve(
      children: [
        TextSpan(text: TurkishHyphenation.hyphenate('yukarıdakilerden ')),
        const WidgetSpan(child: SizedBox(width: 10, height: 10)),
      ],
      rootStyle: root,
      maxWidth: 60,
      textDirection: TextDirection.ltr,
    );
    final plain = plainOf(resolved);
    expect(plain.contains(TurkishHyphenation.softHyphen), isFalse);
    expect(plain.contains('-'), isFalse);
  });
}
