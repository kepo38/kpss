import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/theme/exam_typography.dart';
import 'package:kpss_akademi/widgets/formatted_text.dart';

void main() {
  testWidgets('renders green red blue color markdown', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FormattedText(
            '{green}doğru{/green} {red}yanlış{/red} {blue}bilgi{/blue}',
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      ),
    );

    final rich = tester.widget<RichText>(find.byType(RichText));
    final flat = <TextSpan>[];
    void walk(InlineSpan span) {
      if (span is TextSpan) {
        flat.add(span);
        span.children?.forEach(walk);
      }
    }
    walk(rich.text as TextSpan);

    expect(
      flat.any((s) => s.text == 'doğru' && s.style?.color == const Color(0xFF4ADE80)),
      isTrue,
    );
    expect(
      flat.any((s) => s.text == 'yanlış' && s.style?.color == const Color(0xFFF87171)),
      isTrue,
    );
    expect(
      flat.any((s) => s.text == 'bilgi' && s.style?.color == const Color(0xFF60A5FA)),
      isTrue,
    );
  });

  testWidgets('color tags wrapping math are not shown as literal braces', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FormattedText(
            r'{red}$x \cdot y = 48$ durumu için:{/red}',
            preserveLineBreaks: true,
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      ),
    );

    expect(find.textContaining('{red}'), findsNothing);
    expect(find.textContaining('{/red}'), findsNothing);
    expect(find.textContaining('durumu için:'), findsOneWidget);
  });

  test('repairs telegram \\vert{x\\vert} groups to lvert/rvert', () {
    final out = FormattedText.wrapBareLatex(r'$\vert{a - c\vert} = b$');
    expect(out, contains(r'\lvert a - c \rvert'));
    expect(out, isNot(contains(r'\vert{')));
  });

  testWidgets('renders bold italic underline markdown', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FormattedText(
            '**kalın** ve *italik* ve __altı__',
            style: TextStyle(fontSize: 16, color: Colors.black),
          ),
        ),
      ),
    );

    final rich = tester.widget<RichText>(find.byType(RichText));
    final spans = rich.text as TextSpan;
    final flat = <TextSpan>[];
    void walk(InlineSpan span) {
      if (span is TextSpan) {
        flat.add(span);
        span.children?.forEach(walk);
      }
    }
    walk(spans);

    expect(
      flat.any((s) => (s.style?.fontWeight?.value ?? 0) >= 700),
      isTrue,
      reason: 'bold span missing',
    );
    expect(
      flat.any((s) => s.style?.fontStyle == FontStyle.italic),
      isTrue,
      reason: 'italic span missing',
    );
    expect(
      flat.any((s) => s.style?.decoration == TextDecoration.underline),
      isTrue,
      reason: 'underline span missing',
    );
  });

    testWidgets('renders markdown with windows line breaks', (tester) async {
    const stem =
        "**Cumhuriyet'in ilk yıllarında**\r\n\r\nI. madde";
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FormattedText(
            stem,
            paragraphLayout: true,
            style: const TextStyle(fontSize: 16, color: Colors.black),
          ),
        ),
      ),
    );

    expect(find.textContaining('Cumhuriyet'), findsOneWidget);
    final boldTexts = tester.widgetList<RichText>(find.byType(RichText));
    expect(
      boldTexts.any((rich) {
        TextSpan? boldSpan;
        void walk(InlineSpan span) {
          if (span is TextSpan) {
            if ((span.style?.fontWeight?.value ?? 0) >= 700) boldSpan = span;
            span.children?.forEach(walk);
          }
        }
        walk(rich.text as InlineSpan);
        return boldSpan != null;
      }),
      isTrue,
    );
  });

  test('examFormat keeps display math on its own paragraph', () {
    const stem =
        'x negatif bir gerçel sayı olmak üzere\n'
        r'$$\frac{a}{b}$$'
        '\n**olduğuna göre x kaçtır?**';
    final formatted = FormattedText.examFormat(stem);
    expect(formatted, contains(r'$$\frac{a}{b}$$'));
    expect(formatted.split('\n\n').length, greaterThanOrEqualTo(3));
  });

  test('prepareExamJustifyText preserves Turkish g-breve', () {
    const stem =
        'onun zorla mahkemeye getirilmesi gerektiğini ifade etmiştir.\n\n'
        '**Buna göre Nizamülmülk’ün aşağıdakilerden hangisini '
        'gerçekleştirmeyi hedeflediği söylenemez?**';
    final cleaned = FormattedText.prepareExamJustifyText(stem);
    expect(cleaned, contains('gerektiğini'));
    expect(cleaned, isNot(contains('gerekti ini')));
    expect(cleaned, contains('aşağıdakilerden'));
    // Soft newline merge keeps ğ (may insert a space after the line join).
    final softBroken = FormattedText.prepareExamJustifyText(
      'getirilmesi gerektiğ\nini ifade etmiştir.',
    );
    expect(softBroken, contains('ğ'));
    expect(softBroken, isNot(contains(RegExp(r'gerekti\s+ini'))));
  });

  testWidgets('renders bold wrapped underline markdown', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FormattedText(
            '**Aşağıdakilerden hangisi __değildir?__**',
            style: const TextStyle(fontSize: 16, color: Colors.black),
          ),
        ),
      ),
    );

    TextSpan? comboSpan;
    void walk(InlineSpan span) {
      if (span is TextSpan) {
        if (span.text == 'değildir?' &&
            (span.style?.fontWeight?.value ?? 0) >= 700 &&
            span.style?.decoration == TextDecoration.underline) {
          comboSpan = span;
        }
        span.children?.forEach(walk);
      }
    }
    walk(tester.widget<RichText>(find.byType(RichText)).text as InlineSpan);
    expect(comboSpan, isNotNull);
  });

  testWidgets('renders underline wrapped bold markdown', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FormattedText(
            'Sonu __**değildir?**__',
            style: const TextStyle(fontSize: 16, color: Colors.black),
          ),
        ),
      ),
    );

    TextSpan? comboSpan;
    void walk(InlineSpan span) {
      if (span is TextSpan) {
        if (span.text == 'değildir?' &&
            (span.style?.fontWeight?.value ?? 0) >= 700 &&
            span.style?.decoration == TextDecoration.underline) {
          comboSpan = span;
        }
        span.children?.forEach(walk);
      }
    }
    walk(tester.widget<RichText>(find.byType(RichText)).text as InlineSpan);
    expect(comboSpan, isNotNull);
  });

  testWidgets('renders display math block centered and larger', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FormattedText(
            'Metin\n\n\$\$\\frac{1}{2}\$\$',
            paragraphLayout: true,
            style: const TextStyle(fontSize: 16, color: Colors.black),
          ),
        ),
      ),
    );

    expect(find.byType(FittedBox), findsWidgets);
  });

  testWidgets('normalizes html bold tags', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FormattedText(
            '<strong>kalın</strong> metin',
            style: TextStyle(fontSize: 16, color: Colors.black),
          ),
        ),
      ),
    );

    final rich = tester.widget<RichText>(find.byType(RichText));
    TextSpan? boldSpan;
    void walk(InlineSpan span) {
      if (span is TextSpan) {
        if ((span.style?.fontWeight?.value ?? 0) >= 700) boldSpan = span;
        span.children?.forEach(walk);
      }
    }
    walk(rich.text as TextSpan);
    expect(boldSpan, isNotNull);
    expect(boldSpan!.text, 'kalın');
  });

  test('frac in dollar signs is treated as display math', () {
    expect(
      FormattedText.usesDisplayMath(r'\frac{5^{-1}}{3}'),
      isTrue,
    );
    expect(FormattedText.usesDisplayMath('x+1'), isFalse);
  });

  test('inline x/y fraction stays after göre, not on its own line', () {
    const src = r'Buna göre $\frac{x}{y}$ oranı kaçtır?';
    final out = FormattedText.restoreCollapsedBreaks(src);
    expect(out.contains('\n'), isFalse);
    expect(out, contains(r'göre $\frac{x}{y}$ oranı'));
    expect(
      FormattedText.isStandaloneDisplayEquation(r'\frac{x}{y}'),
      isFalse,
    );
    expect(
      FormattedText.isStandaloneDisplayEquation(
        r'\sqrt{x} - \sqrt{y} = 2\sqrt{2}',
      ),
      isTrue,
    );
  });

  test('inline surrounded fraction uses dfrac at body size', () {
    const tex = r'\frac{x}{y}';
    expect(FormattedText.usesDisplayMath(tex), isTrue);
    final prepared = FormattedText.prepareTex(tex, forceDisplayStyle: true);
    expect(prepared, contains(r'\dfrac{x}{y}'));
    expect(prepared, contains(r'\displaystyle'));
  });

  test('forceDisplaySizeAll keeps inline frac compact when not display', () {
    expect(
      FormattedText.forceDisplaySizeAll(r'\frac{x}{y}', forceDisplayStyle: false),
      r'\frac{x}{y}',
    );
  });

  test('restoreCollapsedBreaks splits glued sentences after latex', () {
    const glued =
        r'...aynıdır ($a^b \equiv a$).Verilen ana bilgi:$a+b$Bu durumu';
    final out = FormattedText.restoreCollapsedBreaks(glued);
    expect(out, contains('.\nVerilen'));
    expect(out, contains(r'$'));
    expect(
      FormattedText.restoreCollapsedBreaks(
        '15 ile bölünür.1. Adım: En büyük sayıyı bulma',
      ),
      contains('.\n1. Adım'),
    );
    final roman = FormattedText.restoreCollapsedBreaks(
      r'**Buna göre** I. $a \cdot (b + c)$ II. $a + b + c$',
    );
    expect(roman, contains('göre**'));
    expect(roman, contains('\nI.'));
    expect(roman, contains('\nII.'));
    final gluedQuestion = FormattedText.restoreCollapsedBreaks(
      r'I. $a \cdot (b + c)$ II. $a + b + c$ III. $a \cdot b + c$ **ifadelerinden hangileri __her zaman__ çift sayıdır?**',
    );
    expect(gluedQuestion.startsWith('I.'), isTrue);
    expect(gluedQuestion, contains('\nII.'));
    expect(gluedQuestion, contains('\nIII.'));
    expect(gluedQuestion, contains('\n**ifadelerinden'));
    expect(
      FormattedText.restoreCollapsedBreaks(
        '- **Linyit** III. Jeolojik Zaman\'da (Tersiyer) oluşmuş kahverengi bir kömür türüdür.',
      ),
      isNot(contains('\nIII.')),
    );
    expect(
      FormattedText.restoreCollapsedBreaks(
        r'{red}$x \cdot y = 48$ durumu için:{/red}',
      ),
      isNot(contains('\ndurumu')),
    );
    expect(
      FormattedText.examFormat(
        'I. \$a\$\nII. \$b\$\nIII. \$c\$\n**ifadelerinden hangileri**',
      ),
      contains('\n\nII.'),
    );
  });

  test('wrapBareLatex restores missing backslash and dollar delimiters', () {
    expect(
      FormattedText.wrapBareLatex(r'-\frac{1}{2}'),
      r'$-\frac{1}{2}$',
    );
    expect(
      FormattedText.wrapBareLatex(r'-frac{1}{2}'),
      r'$-\frac{1}{2}$',
    );
    expect(
      FormattedText.wrapBareLatex(r'$-\frac{1}{2}$'),
      r'$-\frac{1}{2}$',
    );
    expect(FormattedText.wrapBareLatex('-1'), '-1');
    expect(FormattedText.wrapBareLatex('-2'), '-2');
    expect(FormattedText.wrapBareLatex('-1/2'), r'$-\frac{1}{2}$');
    expect(FormattedText.wrapBareLatex('-3/2'), r'$-\frac{3}{2}$');
    expect(FormattedText.wrapBareLatex('1/4'), r'$\frac{1}{4}$');
    expect(FormattedText.wrapBareLatex('3 / 4'), r'$\frac{3}{4}$');
    expect(FormattedText.wrapBareLatex(r'$Yalnız I$'), 'Yalnız I');
    expect(FormattedText.wrapBareLatex('I ve II'), 'I ve II');
  });

  test('normalizeSlashFractions converts variable ratios to frac', () {
    expect(
      FormattedText.normalizeSlashFractions('Buna göre x/y oranı kaçtır?'),
      contains(r'$\frac{x}{y}$'),
    );
    expect(
      FormattedText.normalizeSlashFractions(r'Buna göre $x$/$y$ oranı kaçtır?'),
      contains(r'$\frac{x}{y}$'),
    );
    expect(
      FormattedText.normalizeSlashFractions('Buna göre\nx\ny oranı kaçtır?'),
      contains(r'$\frac{x}{y}$'),
    );
    expect(
      FormattedText.normalizeSlashFractions('Buna göre x y oranı kaçtır?'),
      contains(r'$\frac{x}{y}$'),
    );
    expect(
      FormattedText.wrapBareLatex('x/y'),
      r'$\frac{x}{y}$',
    );
  });

  test('emphasizeSignWords is no-op for exam stems', () {
    expect(
      FormattedText.emphasizeSignWords('x negatif bir gerçek sayı'),
      'x negatif bir gerçek sayı',
    );
    expect(
      FormattedText.normalizeMarkup('x negatif bir gerçek sayı'),
      isNot(contains('{red}')),
    );
  });

  test('replaceHlineWithColoredRule converts hline to colored rule row', () {
    const array =
        r'\begin{array}{r} AB8 \\ -16C \\ \hline CA3 \end{array}';
    final out = FormattedText.replaceHlineWithColoredRule(array);
    expect(out, isNot(contains(r'\hline')));
    expect(out, contains(r'\rule{5em}{0.05em}'));
    expect(out, contains('CA3'));
  });

  test('forceDisplaySizeAll skips displaystyle for array environments', () {
    expect(
      FormattedText.forceDisplaySizeAll(
        r'\begin{array}{r} AB8 \\ -16C \end{array}',
      ),
      isNot(contains(r'\displaystyle')),
    );
    expect(
      FormattedText.forceDisplaySizeAll(r'\frac{x}{y}'),
      contains(r'\displaystyle'),
    );
  });

  test('forceDisplaySizeAll upgrades tfrac and over to displaystyle dfrac', () {
    expect(
      FormattedText.forceDisplaySizeAll(r'\tfrac{x}{y}'),
      r'\displaystyle \dfrac{x}{y}',
    );
    expect(
      FormattedText.forceDisplaySizeAll(r'{x \over y}'),
      r'\displaystyle \dfrac{x}{y}',
    );
    expect(
      FormattedText.forceDisplaySizeAll(r'\frac{x}{y}'),
      r'\displaystyle \dfrac{x}{y}',
    );
    expect(
      FormattedText.forceDisplaySizeAll(r'\displaystyle \frac{x}{y}'),
      r'\displaystyle \dfrac{x}{y}',
    );
    expect(
      FormattedText.prepareTex(r'\tfrac{x}{y}'),
      contains(r'\displaystyle'),
    );
    expect(FormattedText.usesDisplayMath(r'\tfrac{x}{y}'), isTrue);
    expect(FormattedText.usesDisplayMath(r'{x \over y}'), isTrue);
  });

  test('forceDisplaySizeAll keeps nested fractions at display size via dfrac', () {
    final out = FormattedText.forceDisplaySizeAll(
      r'\left(\frac{1 + \frac{1}{4}}{2 + \frac{1}{2}}\right)',
    );
    expect(RegExp(r'(?<![d])\\frac\{').hasMatch(out), isFalse);
    expect(out, contains(r'\dfrac{1}{4}'));
    expect(out, contains(r'\dfrac{1}{2}'));
    expect(out, startsWith(r'\displaystyle'));
  });

  testWidgets('exam layout keeps bold lines at body font size', (tester) async {
    const stem =
        'a bir gerçel sayı olmak üzere\n'
        r'$g(x) = 2x + a$'
        '\n**eşitlikleri veriliyor.**\n'
        '**f(1) = 9 olduğuna göre f(9) değeri kaçtır?**';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: FormattedText(
              stem,
              preserveLineBreaks: true,
              style: ExamTypography.body(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
          ),
        ),
      ),
    );

    final richTexts = tester.widgetList<RichText>(find.byType(RichText));
    final fontSizes = <double>{};
    for (final rich in richTexts) {
      void walk(InlineSpan span) {
        if (span is TextSpan) {
          if (span.style?.fontSize != null) {
            fontSizes.add(span.style!.fontSize!);
          }
          span.children?.forEach(walk);
        }
      }
      walk(rich.text as InlineSpan);
    }
    expect(fontSizes.every((s) => (s - 18).abs() < 0.01), isTrue);
  });

  testWidgets('long math line scales down without overflow', (tester) async {
    const stem = r'$|4a - 2b| + |2a + 3b| = |6a + b|$';
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: FormattedText(
              stem,
              preserveLineBreaks: true,
              style: const TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(FittedBox), findsWidgets);
  });

  testWidgets('solution mode keeps fixed font size without fitted shrink', (tester) async {
    const stem =
        r'**2. Adım:** $8 - C = 3$ ve $C + A = 7$ denklem sistemini çözelim.';
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: FormattedText(
              stem,
              preserveLineBreaks: true,
              examScaleDown: false,
              style: ExamTypography.solution(color: Colors.white),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(FittedBox), findsNothing);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('prepareTex strips soft hyphens from latex commands', () {
    const broken =
        'dis\u00ADplaystyle \\be\u00ADgin{array}{r} AB8 \\\\ -16C \\\\ \\hli\u00ADne CA3 \\end{array}';
    final out = FormattedText.prepareTex(broken);
    expect(out.contains('\u00AD'), isFalse);
    expect(out, contains(r'\begin{array}'));
    expect(out, contains(r'\rule{5em}{0.05em}'));
    expect(out, isNot(contains(r'\hline')));
  });

  test('wrapBareLatex keeps simple algebra dollar delimiters', () {
    expect(FormattedText.wrapBareLatex(r'$A + B + C$'), r'$A + B + C$');
    expect(FormattedText.wrapBareLatex(r'$Yalnız I$'), 'Yalnız I');
    expect(FormattedText.wrapBareLatex('A + B + C'), r'$A + B + C$');
  });

  test('wrapBareLatex does not wrap prose with year/hyphen ranges as math', () {
    const stems = <String>[
      'Türkiye arazisi yaklaşık son 2-3 milyon yıl içinde yükselmiştir.',
      'Bu geziler, XVIII - XIX. yüzyıllarda bilim insanlarının katılımıyla sürdü.',
      "El'Kitab'ül-Muhtasar fi Hisab'il-Cebri hakkında hangisidir?",
      'Cümlede zarf-fiil ve isim-fiil kullanılır.',
      'Amasya Protokolü 20-22 Ekim tarihlerinde imzalandı.',
      '1923-1950 döneminde hangi gelişme yaşanmıştır?',
      'Michelson-Morley deneyi ışık hızını ölçmeye çalışmıştır.',
    ];
    for (final stem in stems) {
      final out = FormattedText.wrapBareLatex(stem);
      expect(out, equals(stem), reason: stem);
      expect(FormattedText.looksLikeMath(stem), isFalse, reason: stem);
    }
  });

  test('wrapBareLatex keeps stem after leading single-letter dollars', () {
    const stem =
        r'$a$ sıfırdan farklı bir gerçel sayı olmak üzere bir $f$ fonksiyonu'
        '\n'
        r'$f(x) = \frac{x}{a} + 1$'
        '\n'
        r'olduğuna göre $a$ kaçtır?';
    final out = FormattedText.wrapBareLatex(stem);
    expect(out, startsWith('a sıfırdan'));
    expect(out, contains(r'$f$'));
    expect(out, contains(r'\frac{x}{a}'));
    expect(out, contains('kaçtır?'));
    expect(out, isNot(equals('a')));
  });

  test('wrapBareLatex keeps stem after leading inequality dollars', () {
    const stem =
        r'$a < b < 0$ olmak üzere hangisi doğrudur?';
    final out = FormattedText.wrapBareLatex(stem);
    expect(out, contains(r'$a < b < 0$'));
    expect(out, contains('hangisi doğrudur?'));
  });

  test('normalizeMarkup restores nested math inside bold (no §§E leak)', () {
    final out = FormattedText.normalizeMarkup(
      r'**I. $a \cdot (b + c)$** ve - 1. Durum ($T \cdot Ç$): sonuç',
    );
    expect(out, isNot(contains('§§E')));
    expect(out, contains(r'$a \cdot (b + c)$'));
    expect(out, contains(r'$T \cdot Ç$'));
    expect(out, contains('**'));
  });

  test('restoreCollapsedBreaks keeps Payda and Kesrin on own lines', () {
    final out = FormattedText.restoreCollapsedBreaks(
      r'1. İlk kesri: Pay: $\frac{11}{2}$ Payda: $\frac{13}{2}$ '
      r'Kesrin değeri: $\frac{11}{13}$',
    );
    expect(out, isNot(contains('§§M')));
    expect(out, contains('\nPayda:'));
    expect(out, contains('\nKesrin değeri:'));
    expect(out, contains(r'\frac{11}{2}'));
  });

  test('plain math letters match body style helpers', () {
    expect(FormattedText.isPlainMathLetter('x'), isTrue);
    expect(FormattedText.isPlainMathLetter('z'), isTrue);
    expect(FormattedText.isPlainMathLetter(r'z > 1'), isFalse);
    expect(
      FormattedText.mathTextStyle(
        const TextStyle(fontSize: 15, color: Colors.white),
        display: true,
      ).fontSize,
      15,
    );
    expect(
      FormattedText.mathTextStyle(
        const TextStyle(fontSize: 15),
        display: false,
      ).fontStyle,
      FontStyle.normal,
    );
    expect(
      FormattedText.uprightMathLetters(r'z > 1'),
      contains(r'\mathrm{z}'),
    );
  });

  test('uprightMathLetters uprights letters inside sqrt and frac', () {
    expect(
      FormattedText.uprightMathLetters(r'\sqrt{4xy}'),
      r'\sqrt{4\mathrm{x}\mathrm{y}}',
    );
    expect(
      FormattedText.uprightMathLetters(r'x + y + \sqrt{4xy}'),
      contains(r'\sqrt{4\mathrm{x}\mathrm{y}}'),
    );
    expect(
      FormattedText.uprightMathLetters(r'\frac{18}{a}'),
      contains(r'{\mathrm{a}}'),
    );
    expect(
      FormattedText.uprightMathLetters(r'\text{Kelime}'),
      r'\text{Kelime}',
    );
  });

  test('uprightMathLetters restores commands (no §§C leak)', () {
    final out = FormattedText.uprightMathLetters(r'a^{b} + b \cdot c');
    expect(out.contains('§§'), isFalse);
    expect(out, contains(r'\cdot'));
    expect(out, contains(r'\mathrm{a}'));
    expect(out, contains(r'\mathrm{b}'));
    expect(out, contains(r'\mathrm{c}'));

    final frac = FormattedText.uprightMathLetters(r'\frac{18}{a}');
    expect(frac.contains('§§'), isFalse);
    expect(frac, contains(r'\frac'));
  });

  test('uprightMathLetters skips array environments', () {
    const array =
        r'\displaystyle \begin{array}{r} AB8 \\ -16C \\ \rule{5em}{0.05em} \\ CA3 \end{array}';
    expect(FormattedText.uprightMathLetters(array), array);
  });

  testWidgets('exam stem renders display array math not raw latex', (tester) async {
    const stem =
        'İşlem aşağıda verilmiştir.\n'
        r'$$\displaystyle \begin{array}{r} AB8 \\ -16C \\ \hline CA3 \end{array}$$'
        '\n'
        r'$A + B + C$ değerini bulunuz.';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: FormattedText(
              stem,
              preserveLineBreaks: true,
              examLayout: true,
              examWrap: true,
              style: ExamTypography.body(color: Colors.white, fontSize: 18),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(Math), findsNWidgets(2));
    expect(find.textContaining(r'$$\displaystyle'), findsNothing);
    expect(find.textContaining(r'\begin{array}'), findsNothing);
    expect(find.textContaining(r'$A + B + C$'), findsNothing);
  });

  test('restoreCollapsedBreaks splits Google Docs math solution paste', () {
    const src =
        r'📊 Adım Adım Net Matematiksel GösterimKitabın Tamamı: 300 sayfa'
        r'İlk 3 Gün Toplamı: \(300 \times \frac{3}{5} = \mathbf{180}\) sayfa.'
        r'4. Gün Okunan: \(300 - 180 = \mathbf{120}\) sayfa.'
        r'İlk İki Gün Toplamı: göre;'
        r'\(120=(\text{1.\ Gün}+\text{2.\ Gün})\times \frac{5}{6}'
        r'\implies \text{1.\ Gün}+\text{2.\ Gün}=\mathbf{144}\)'
        r'3. Gün Okunan: çıkarırsak;\(180-144=\mathbf{36}\)';
    final out = FormattedText.restoreCollapsedBreaks(
      FormattedText.normalizeLatex(src),
    );
    expect(out, contains('Gösterim\nKitabın'));
    expect(out, contains('sayfa\nİlk 3 Gün'));
    expect(out, contains('sayfa.\n4. Gün'));
    expect(out, contains('göre;\n'));
    expect(out, contains('çıkarırsak;\n'));
    expect(out, contains('3. Gün Okunan'));
    expect(out.split('\n').length, greaterThan(5));
  });

  test('restoreCollapsedBreaks does not split inline dollar math', () {
    const src = r'Taban alanı $Toplam = 5$ olarak bulunur.';
    final out = FormattedText.restoreCollapsedBreaks(src);
    expect(out, contains(r'$Toplam = 5$'));
    expect(out, isNot(contains(r'$\nToplam')));
  });

  test('normalizeLatex collapses multiline paren to inline dollar', () {
    const src = r'Buradan \(x = 5' '\n' r'+ 3\) bulunur.';
    final out = FormattedText.normalizeLatex(src);
    expect(out, contains(r'$x = 5 + 3$'));
  });

  test('restoreCollapsedBreaks does not split units and brands', () {
    const src = 'Değer 5A akım, pH değeri 7, iPhone modeli ve 3D görüntü.';
    final out = FormattedText.restoreCollapsedBreaks(src);
    expect(out, contains('5A akım'));
    expect(out, contains('pH değeri'));
    expect(out, contains('iPhone modeli'));
    expect(out, contains('3D görüntü'));
    expect(out, isNot(contains('5\nA')));
    expect(out, isNot(contains('p\nH')));
  });

  test('structureSolutionOutline rebuilds Google logic solution lists', () {
    const src =
        '💡 Adım Adım Çözüm\n'
        'Kural Özeti:\n'
        'Tüm öğrenciler başlangıçta oturuyor.\n'
        'Söylenen harf isminde varsa durum değiştirir.\n'
        'Bir öğrencinin son durumda ayakta kalması gerekir.\n'
        'Şimdi seçenekleri kontrol edelim:\n'
        'A) AYBERK:\n'
        'A var (Kalktı), B var (Otuttu), C yok.\n'
        'Toplam değişim: 2 kez → Oturuyor.\n'
        'B) BERKCAN:\n'
        'A var (Kalktı), B var (Otuttu), C var (Kalktı).\n'
        'Toplam değişim: 3 kez → 🧍 AYAKTA.\n'
        'C) CEYDA:\n'
        'Toplam değişim: 2 kez → Oturuyor.';
    final out = FormattedText.structureSolutionOutline(src);
    expect(out, contains('**💡 Adım Adım Çözüm**'));
    expect(out, contains('**Kural Özeti:**'));
    expect(out, contains('- Tüm öğrenciler başlangıçta oturuyor.'));
    expect(out, contains('- **A) AYBERK:**'));
    expect(out, contains('  - A var (Kalktı), B var (Otuttu), C yok.'));
    expect(out, contains('- **B) BERKCAN:**'));
    expect(out, contains('**AYAKTA**'));
    expect(out, contains('- **C) CEYDA:**'));
    final again = FormattedText.structureSolutionOutline(out);
    expect('- **A) AYBERK:**'.allMatches(again).length, 1);
  });

  test('structureSolutionOutline handles A Seçeneği Google candle paste', () {
    const glued =
        'inceleyelim:A Seçeneği: Dizilim 2 - 3 - 5 - 4 - 1 şeklindedir.'
        '2 - 3 - 4 üçlüsü zaten sıralıdır. (2 hamlede yapılabilir)'
        'B Seçeneği: Dizilim 3 - 1 - 4 - 5 - 2 şeklindedir.'
        '1 - 4 - 5 üçlüsü zaten sıralıdır. (2 hamlede yapılabilir)';
    final broken = FormattedText.restoreCollapsedBreaks(glued);
    expect(broken, contains('\nA Seçeneği:'));
    expect(broken, contains('\nB Seçeneği:'));
    final out = FormattedText.structureSolutionOutline(broken);
    expect(out, contains('- **A Seçeneği:**'));
    expect(out, contains('- **B Seçeneği:**'));
    expect(out, contains('  - Dizilim 2 - 3 - 5 - 4 - 1'));
  });

  test('structureSolutionOutline rebuilds Google HEL presence table', () {
    const src =
        '💡 Adım Adım Mantıksal ÇözümÖğretmenin seçtiği 3 harfin her bir '
        'ismini tek bir şekilde (kesin olarak) belirleyebilmesi için, bu 3 '
        'harfin isimlerdeki dağılımının (kümelenmesinin) her öğrenci için '
        'tamamen benzersiz (farklı) olması gerekir.Öğrencilerimiz: AYNUR, '
        'GÖZDE, HÜLYA, LEMAN, ZEHRASeçeneklerde yer alan H, E, L harflerinin '
        'bu isimlerde bulunma durumlarını ("Var: 1", "Yok: 0") kodlayarak '
        'bir tablo oluşturalım:ÖğrenciH HarfiE HarfiL HarfiOluşan Benzersiz '
        'Kod (H, E, L)AYNURYok (0)Yok (0)Yok (0)000GÖZDEYok (0)Var (1)Yok (0)'
        '010HÜLYAVar (1)Yok (0)Var (1)101LEMANYok (0)Var (1)Var (1)011ZEHRA'
        'Var (1)Var (1)Yok (0)110Görüldüğü üzere, H, E, L harfleri seçildiğinde '
        'her öğrenci için tamamen farklı bir kod kombinasyonu oluşmaktadır.';
    final broken = FormattedText.restoreCollapsedBreaks(src);
    expect(broken, contains('Çözüm\nÖğretmenin'));
    expect(broken, contains('gerekir.\nÖğrencilerimiz:'));
    expect(broken, contains('ZEHRA\nSeçeneklerde'));
    expect(broken, contains('Öğrenci\nH Harfi'));
    expect(broken, contains('AYNUR\nYok (0)'));
    expect(broken, contains('000\nGÖZDE'));
    expect(broken, contains('110\nGörüldüğü'));
    expect(broken, isNot(contains('ÖğrenciH Harfi')));

    final out = FormattedText.structureSolutionOutline(broken);
    expect(out, contains('**💡 Adım Adım Mantıksal Çözüm**'));
    expect(out, contains('**Harf kodu:**'));
    expect(out, contains('- **AYNUR:** H yok, E yok, L yok → **000**'));
    expect(out, contains('- **GÖZDE:** H yok, E var, L yok → **010**'));
    expect(out, contains('- **HÜLYA:** H var, E yok, L var → **101**'));
    expect(out, contains('- **LEMAN:** H yok, E var, L var → **011**'));
    expect(out, contains('- **ZEHRA:** H var, E var, L yok → **110**'));
    expect(out, isNot(contains('ÖğrenciH')));
    final again = FormattedText.structureSolutionOutline(out);
    expect('- **AYNUR:**'.allMatches(again).length, 1);
  });

  test('joinOrphanRomanNumeralLines merges split list markers', () {
    const src = 'Buna göre\nI.\nFidan,\nII. Gamze,\nIII. Işıl';
    final out = FormattedText.joinOrphanRomanNumeralLines(src);
    expect(out, contains('I. Fidan,'));
    expect(out, isNot(contains('I.\nFidan')));
  });

  test('restoreCollapsedBreaks keeps glued roman I.Fidan on one line', () {
    const src = 'Buna göre\nI.Fidan,\nII. Gamze,\nIII. Işıl';
    final out = FormattedText.restoreCollapsedBreaks(src);
    expect(out, contains('I. Fidan,'));
    expect(out, isNot(contains('I.\nFidan')));
  });

  test('glueRomanNumeralLabels inserts space after roman dot', () {
    expect(
      FormattedText.glueRomanNumeralLabels('I.Fidan, II.Gamze'),
      'I. Fidan, II. Gamze',
    );
  });

  test('google paste egg solution preview', () {
    const src =
        r'Çözüm Adımları10.06.2024 Sonu:Tarihi geçmeyen 27 yumurta ertesi güne kalır.'
        r'Tarihi geçen 6 yumurta çöpe atılır.11.06.2024 Başlangıcı ve Ayrımı:'
        r'Güne kalan 27 yumurta ile başlanır.Bu yumurtalar ikiye ayrılır: \((3x + y) + 5 = 27\)'
        r'Buradan denklem: \(3x + y = 22\) elde edilir.Tarihi geçen 5 yumurta atılınca '
        r'geriye \(3x + y\) (yani 22) yumurta kalır.12.06.2024 Ayrımı:'
        r'Güne kalan 22 yumurta ile başlanır.Bu yumurtalar ikiye ayrılır: \(14 + 2y = 22\)'
        r'\(2y = 8 \implies \mathbf{y = 4}\) bulunur.\(x\) Değerinin Bulunması:'
        r'\(3x + y = 22\) denkleminde \(y = 4\) yazılır.'
        r'\(3x + 4 = 22 \implies 3x = 18 \implies \mathbf{x = 6}\) bulunur.'
        r'Sonuç:\(x \cdot y = 6 \cdot 4 = \mathbf{24}\) olur:';

    final collapsed = FormattedText.restoreCollapsedBreaks(src);
    final normalized = FormattedText.normalizeForSolutionDisplay(src);
    final prepared = FormattedText.prepareSolutionText(src);

    expect(collapsed, contains('Çözüm Adımları\n10.06.2024'));
    expect(collapsed, contains('10.06.2024'));
    expect(collapsed, isNot(contains('10.06.\n2024')));
    expect(collapsed, contains('Sonu:\nTarihi'));
    expect(collapsed, contains('atılır.\n11.06.2024'));
    expect(collapsed, contains('Başlangıcı ve Ayrımı:\nGüne'));
    expect(collapsed, contains('Ayrımı:\nGüne'));
    expect(collapsed, contains('bulunur.\n'));
    expect(collapsed, contains('Değerinin Bulunması:\n'));
    expect(collapsed, contains('Sonuç:\n'));

    expect(normalized, contains(r'$(3x + y) + 5 = 27$'));
    expect(normalized, contains('Sonu:\nTarihi'));
    expect(normalized, contains('kalır.\nTarihi'));
    expect(normalized, contains('10.06.2024'));
    expect(normalized, isNot(contains('10.06.\n2024')));
    expect(prepared, contains('Sonuç:\n'));
  });

  test('inline cdot math span uses alphabetic baseline alignment', () {
    const style = TextStyle(fontSize: 18, height: 1.5);
    final spans = FormattedText.parseSpans(
      r'Tablodaki verilere göre $x \cdot y$ çarpımı kaçtır?',
      style,
    );

    WidgetSpan? mathSpan;
    void walk(InlineSpan span) {
      if (span is WidgetSpan) {
        mathSpan ??= span;
      } else if (span is TextSpan) {
        span.children?.forEach(walk);
      }
    }
    for (final span in spans) {
      walk(span);
    }

    expect(mathSpan, isNotNull);
    expect(mathSpan!.alignment, PlaceholderAlignment.baseline);
    expect(mathSpan!.baseline, TextBaseline.alphabetic);
    expect(FormattedText.usesDisplayMath(r'x \cdot y'), isFalse);
  });

  test('prepareExamDisplayText preserves inline subscript math', () {
    const raw =
        r'kenarları $k_A$, $k_B$ ve $k_C$ birim; $k_A < k_B < k_C$ olduğuna göre';
    final out = FormattedText.prepareExamDisplayText(
      FormattedText.prepareExamJustifyText(
        FormattedText.wrapBareLatex(raw),
      ),
    );
    expect(out, contains(r'$k_A$'));
    expect(out, contains(r'$k_B$'));
    expect(out, contains(r'$k_A < k_B < k_C$'));
    expect(out, isNot(RegExp(r'\n\$k')));
  });

  test('prepareExamDisplayText skips solution outline splits', () {
    const raw = r'$k_A \cdot u_A = 48$';
    final outlined = FormattedText.prepareSolutionText(raw);
    final exam = FormattedText.prepareExamDisplayText(
      FormattedText.prepareExamJustifyText(
        FormattedText.wrapBareLatex(raw),
      ),
    );
    expect(exam, contains(r'$k_A'));
    expect(outlined.split('\n').length, greaterThanOrEqualTo(exam.split('\n').length));
  });

  testWidgets('exam wrap renders subscript math without raw dollar text', (tester) async {
    const stem =
        r'Kenarlar $k_A$, $k_B$ ve $k_C$ birim; $k_A < k_B < k_C$ olduğuna göre';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: FormattedText(
              FormattedText.prepareExamJustifyText(
                FormattedText.wrapBareLatex(stem),
              ),
              preserveLineBreaks: true,
              examLayout: true,
              examWrap: true,
              style: ExamTypography.body(color: Colors.white, fontSize: 18),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(Math), findsWidgets);
    expect(find.textContaining(r'$k_A$'), findsNothing);
  });

  test('mergeSplitInlineDollarMath preserves roman-numeral inline math lists', () {
    const src = r'''a, b ve c pozitif tam sayılar için

$a^b + b \cdot c$

**Buna göre**

I. $a \cdot (b + c)$

II. $a + b + c$

III. $a \cdot b + c$

**ifadelerinden hangileri __her zaman__ çift sayıdır?**''';
    final out = FormattedText.mergeSplitInlineDollarMath(src);
    expect(out, isNot(contains(r'$II.')));
    expect(out, isNot(contains(r'$III.')));
    expect(out, contains(r'I. $a \cdot (b + c)$'));
    expect(out, contains(r'II. $a + b + c$'));
    expect(out, contains(r'III. $a \cdot b + c$'));
  });
}
