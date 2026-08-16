import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

    expect(find.byType(Center), findsOneWidget);
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
}
