import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/utils/turkish_hyphenation.dart';
import 'package:kpss_akademi/widgets/formatted_text.dart';

/// Gerçek RenderParagraph üzerinden doğrulama: ekrandaki her heceleme tiresi
/// yalnızca satır sonunda olmalı; hece sınırında kırılan her satır tireyle
/// bitmeli.
const _soft = '\u00AD';
final _letter = RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşüÂâÎîÛû]');

const _stemStyle = TextStyle(
  fontFamily: 'Roboto',
  fontSize: 9,
  height: 1.5,
  color: Colors.white,
);

const _optionStyle = TextStyle(
  fontFamily: 'Roboto',
  fontSize: 7.5,
  height: 1.35,
  color: Colors.white,
);

const _samples = <String>[
  'Aşağıdakilerden hangisi yukarıdakilerden farklı olarak değerlendirilebilir '
      'çalışmalarının sonuçlarını göstermektedir?',
  'Bu soruda **yukarıdakilerden** hangisi __doğrudur__ diye sorulmaktadır; '
      'anlatılanlarla eşleştirilemeyen ifadeleri belirleyiniz.',
  'Osmanlı Devleti\'nde yönetimsel düzenlemeler kapsamında gerçekleştirilen '
      'yenileşme hareketlerinin **temel amaçlarından** biri değildir.',
  'İlköğretimde uygulanan öğretmenlik mesleğine yönelik değerlendirmelerin '
      'kapsamı genişletilmiştir ve sonuçlar açıklanmıştır.',
];

class _Violations {
  final List<String> items = [];
  void add(String s) => items.add(s);
  bool get isEmpty => items.isEmpty;
  @override
  String toString() => items.join('\n');
}

/// Gerçek RenderParagraph'ın satır sonu ofsetlerini (bitiş dahil değil) döner.
List<int> _lineEnds(RenderParagraph p, int length) {
  final set = <int>{};
  for (var y = 1.0; y < p.size.height; y += 2) {
    final pos = p.getPositionForOffset(Offset(p.size.width + 5000, y));
    set.add(pos.offset.clamp(0, length));
  }
  return set.toList()..sort();
}
_Violations _inspect(WidgetTester tester) {
  final v = _Violations();
  final paragraphs =
      tester.renderObjectList<RenderParagraph>(find.byType(RichText)).toList();
  for (final p in paragraphs) {
    final plain = p.text.toPlainText(includeSemanticsLabels: false);
    final ends = _lineEnds(p, plain.length);
    final effectiveEnds = <int>{};
    for (var k = 0; k < ends.length - 1; k++) {
      var e = ends[k];
      while (e > 0 && plain[e - 1] == ' ') {
        e--;
      }
      effectiveEnds.add(e);
      if (e <= 0 || e >= plain.length) continue;
      final last = plain[e - 1];
      if (last == _soft) {
        v.add('soft hyphen satır sonunda (tiresiz kırılma): "$plain"');
      } else if (_letter.hasMatch(last) &&
          e < plain.length &&
          _letter.hasMatch(plain[e])) {
        v.add('kelime tiresiz bölündü @${e - 1}: "$plain"');
      }
    }
    for (var i = 0; i < plain.length; i++) {
      if (plain[i] != '-') continue;
      if (!effectiveEnds.contains(i + 1)) {
        v.add('satır ortasında tire @$i: "$plain"');
      }
    }
  }
  return v;
}

Future<void> _pump(
  WidgetTester tester, {
  required String text,
  required double width,
  required TextStyle style,
  double textScale = 1.0,
  TextAlign align = TextAlign.justify,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: FormattedText(
                TurkishHyphenation.hyphenate(text),
                preNormalized: true,
                preserveLineBreaks: true,
                examLayout: true,
                examWrap: true,
                examScaleDown: false,
                textAlign: align,
                style: style,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('soru metni: her genişlikte tire yalnızca satır sonunda', (
    tester,
  ) async {
    final all = _Violations();
    for (final text in _samples) {
      for (var w = 190.0; w <= 420.0; w += 9) {
        await _pump(tester, text: text, width: w, style: _stemStyle);
        final v = _inspect(tester);
        for (final s in v.items) {
          all.add('w=$w  $s');
        }
      }
    }
    expect(all.isEmpty, isTrue, reason: '\n$all');
  });

  testWidgets('şık: dar genişlik ve büyük yazı ölçeğinde tire tutarlı', (
    tester,
  ) async {
    final all = _Violations();
    for (final text in _samples) {
      for (final scale in const [1.0, 1.3]) {
        for (var w = 200.0; w <= 340.0; w += 11) {
          await _pump(
            tester,
            text: text,
            width: w,
            style: _optionStyle,
            textScale: scale,
            align: TextAlign.start,
          );
          final v = _inspect(tester);
          for (final s in v.items) {
            all.add('w=$w scale=$scale  $s');
          }
        }
      }
    }
    expect(all.isEmpty, isTrue, reason: '\n$all');
  });

  testWidgets('tire gerçekten görünüyor (hepsi silinmemiş)', (tester) async {
    var visibleDashes = 0;
    for (final text in _samples) {
      for (var w = 190.0; w <= 420.0; w += 9) {
        await _pump(tester, text: text, width: w, style: _stemStyle);
        for (final p in tester.renderObjectList<RenderParagraph>(
          find.byType(RichText),
        )) {
          visibleDashes += '-'
              .allMatches(p.text.toPlainText(includeSemanticsLabels: false))
              .length;
        }
      }
    }
    expect(visibleDashes, greaterThan(10));
  });

  testWidgets('kalın yazı erişilebilirlik ayarı + yazı ölçeği 1.5', (
    tester,
  ) async {
    final all = _Violations();
    for (final text in _samples) {
      for (var w = 230.0; w <= 400.0; w += 13) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                boldText: true,
                textScaler: TextScaler.linear(1.5),
              ),
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: w,
                    child: FormattedText(
                      TurkishHyphenation.hyphenate(text),
                      preNormalized: true,
                      preserveLineBreaks: true,
                      examLayout: true,
                      examWrap: true,
                      examScaleDown: false,
                      textAlign: TextAlign.justify,
                      style: _stemStyle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        for (final s in _inspect(tester).items) {
          all.add('w=$w  $s');
        }
      }
    }
    expect(all.isEmpty, isTrue, reason: '\n$all');
  });

  testWidgets('yazı tipi değişimi (fontsChange) sonrası yeniden çözülür', (
    tester,
  ) async {
    await _pump(
      tester,
      text: _samples.first,
      width: 250,
      style: _stemStyle,
    );
    await tester.binding.handleSystemMessage(<String, dynamic>{
      'type': 'fontsChange',
    });
    await tester.pump();
    expect(_inspect(tester).isEmpty, isTrue);
    expect(tester.takeException(), isNull);
  });}
