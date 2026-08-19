import 'package:flutter/material.dart';
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
    expect(FormattedText.wrapBareLatex(r'$Yalnız I$'), 'Yalnız I');
    expect(FormattedText.wrapBareLatex('I ve II'), 'I ve II');
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

  test('forceDisplaySizeAll upgrades tfrac and over to displaystyle frac', () {
    expect(
      FormattedText.forceDisplaySizeAll(r'\tfrac{x}{y}'),
      r'\displaystyle \frac{x}{y}',
    );
    expect(
      FormattedText.forceDisplaySizeAll(r'{x \over y}'),
      r'\displaystyle \frac{x}{y}',
    );
    expect(
      FormattedText.forceDisplaySizeAll(r'\frac{x}{y}'),
      r'\displaystyle \frac{x}{y}',
    );
    expect(
      FormattedText.forceDisplaySizeAll(r'\displaystyle \frac{x}{y}'),
      r'\displaystyle \frac{x}{y}',
    );
    expect(
      FormattedText.prepareTex(r'\tfrac{x}{y}'),
      contains(r'\displaystyle'),
    );
    expect(FormattedText.usesDisplayMath(r'\tfrac{x}{y}'), isTrue);
    expect(FormattedText.usesDisplayMath(r'{x \over y}'), isTrue);
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
}
