import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/theme/exam_typography.dart';
import 'package:kpss_akademi/widgets/exam_text/exam_option_view.dart';
import 'package:kpss_akademi/widgets/exam_text/exam_solution_view.dart';
import 'package:kpss_akademi/widgets/exam_text/exam_stem_view.dart';
import 'package:kpss_akademi/widgets/exam_text/option_column_layout.dart';
import 'package:kpss_akademi/widgets/formatted_text.dart';

void main() {
  testWidgets('exam stem keeps uniform 18pt with bold question line', (tester) async {
    const stem =
        'Nizamülmülk, Siyasetname adlı eserinde bir kimsenin mahkemeye '
        'gelmek istememesi hâlinde ne kadar yüksek makam sahibi olursa '
        'olsun onun zorla mahkemeye getirilmesi gerektiğini ifade etmiştir.\n\n'
        '**Buna göre Nizamülmülk’ün aşağıdakilerden hangisini '
        'gerçekleştirmeyi hedeflediği söylenemez?**';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: ExamStemView(text: stem),
          ),
        ),
      ),
    );

    expect(find.textContaining('Nizamülmülk'), findsWidgets);
    expect(find.textContaining('Buna göre'), findsOneWidget);
    expect(find.byType(FittedBox), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exam solution wraps long lines without horizontal clip', (tester) async {
    const solution =
        '• **Açıklama:** Nizamülmülk’ün metindeki ifadesi tamamen '
        'adalet sistemine güven duyulması gerektiğini vurgular.\n'
        '-A Şıkkı (Toplumun adalet sistemine güvenini artırmayı): '
        'Metindeki ifade ile uyumludur.';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: ExamSolutionView(text: solution),
          ),
        ),
      ),
    );

    expect(find.textContaining('Açıklama'), findsOneWidget);
    expect(find.byType(FittedBox), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exam option wraps long single line at 14pt without FittedBox',
      (tester) async {
    const option =
        'Toplumun, ülkedeki adalet sistemine olan güvenini artırmayı';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: ExamOptionView(text: option),
          ),
        ),
      ),
    );

    expect(find.textContaining('Toplumun'), findsOneWidget);
    expect(find.byType(FittedBox), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('parseSpans is public', () {
    final spans = FormattedText.parseSpans(
      '**kalın** metin',
      ExamTypography.body(color: Colors.black),
    );
    expect(spans, isNotEmpty);
  });

  test('dash-separated options become three columns', () {
    expect(
      OptionColumnLayout.cellsOf(
        'İnanç: Şanlıurfa, Mağara: Antalya, Termal: Afyonkarahisar',
      ),
      ['Şanlıurfa', 'Antalya', 'Afyonkarahisar'],
    );
    expect(
      OptionColumnLayout.headersFromOptions([
        'İnanç: Şanlıurfa, Mağara: Antalya, Termal: Afyonkarahisar',
        'İnanç: Trabzon, Mağara: Konya, Termal: İzmir',
      ], 3),
      ['İnanç', 'Mağara', 'Termal'],
    );
    expect(
      OptionColumnLayout.cellsOf('Şanlıurfa — Antalya — Afyonkarahisar'),
      ['Şanlıurfa', 'Antalya', 'Afyonkarahisar'],
    );
    expect(
      OptionColumnLayout.cellsOf('Şanlıurfa --- Antalya --- Afyonkarahisar'),
      ['Şanlıurfa', 'Antalya', 'Afyonkarahisar'],
    );
    expect(
      OptionColumnLayout.alignedCount([
        'Şanlıurfa - Antalya - Afyonkarahisar',
        'Konya - Mersin - Denizli',
      ]),
      3,
    );
    expect(
      OptionColumnLayout.alignedCount([
        'Şanlıurfa — Antalya — Afyonkarahisar',
        'Trabzon — Konya — İzmir',
        'Hatay — Edirne — Rize',
        'Düz cümle şıkkı burada',
      ]),
      3,
    );
    expect(
      OptionColumnLayout.headersFromStem(
        'I. İnanç II. Mağara III. Termal turizmi',
        3,
      ),
      ['İnanç', 'Mağara', 'Termal'],
    );
    expect(
      OptionColumnLayout.headersFromStem(
        'Soru metni\n<!--optcols:İnanç|Mağara|Termal-->',
        3,
      ),
      ['İnanç', 'Mağara', 'Termal'],
    );
    expect(
      OptionColumnLayout.visibleStem(
        'Soru metni\n<!--optcols:İnanç|Mağara|Termal-->',
      ),
      'Soru metni',
    );
  });
}
