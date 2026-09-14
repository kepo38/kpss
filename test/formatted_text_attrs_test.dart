import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/widgets/formatted_text.dart';

bool _hasWeight(InlineSpan root, {required int min}) {
  var found = false;
  void walk(InlineSpan span) {
    if (span is TextSpan) {
      final w = span.style?.fontWeight?.value ?? 0;
      if (w >= min) found = true;
      span.children?.forEach(walk);
    }
  }

  walk(root);
  return found;
}

bool _hasUnderline(InlineSpan root) {
  var found = false;
  void walk(InlineSpan span) {
    if (span is TextSpan) {
      if (span.style?.decoration == TextDecoration.underline) found = true;
      span.children?.forEach(walk);
    }
  }

  walk(root);
  return found;
}

String _plainText(InlineSpan root) {
  if (root is TextSpan) {
    final self = root.text ?? '';
    final kids = root.children?.map(_plainText).join() ?? '';
    return self + kids;
  }
  return '';
}

bool _hasGreenText(InlineSpan root) {
  var found = false;
  void walk(InlineSpan span) {
    if (span is TextSpan) {
      if (span.style?.color == const Color(0xFF4ADE80)) found = true;
      span.children?.forEach(walk);
    }
  }

  walk(root);
  return found;
}

void main() {
  test('normalize html tags with attributes', () {
    expect(
      FormattedText.normalizeMarkup('<strong class="x">kalın</strong>'),
      '**kalın**',
    );
    expect(
      FormattedText.normalizeMarkup('<b style="font-weight:bold">x</b>'),
      '**x**',
    );
    expect(
      FormattedText.normalizeMarkup(
        '<u style="text-decoration:underline">a</u>',
      ),
      '__a__',
    );
    expect(
      FormattedText.normalizeMarkup(
        '<span style="color:red;font-weight:700">y</span>',
      ),
      '{red}**y**{/red}',
    );
  });

  testWidgets('renders attributed html bold and underline', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FormattedText(
            '<strong class="editor">kalın</strong> ve '
            '<span style="text-decoration: underline">altı</span>',
            style: TextStyle(fontSize: 16, color: Colors.black),
          ),
        ),
      ),
    );

    final rich = tester.widget<RichText>(find.byType(RichText));
    final root = rich.text as TextSpan;
    expect(_hasWeight(root, min: 700), isTrue);
    expect(_hasUnderline(root), isTrue);
    expect(find.textContaining('<strong'), findsNothing);
  });

  testWidgets('renders underline and green inside bold (q_dd640972fd)', (
    tester,
  ) async {
    const src =
        '**(Metinde __YOKTUR__ -{green} Doğru Cevap{/green}):**';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FormattedText(
            src,
            style: TextStyle(fontSize: 16, color: Colors.black),
          ),
        ),
      ),
    );

    final rich = tester.widget<RichText>(find.byType(RichText));
    final root = rich.text as TextSpan;
    final plain = _plainText(root);
    expect(plain, contains('Doğru Cevap'));
    expect(plain, isNot(contains('YOKTUR -YOKTUR')));
    expect(_hasUnderline(root), isTrue);
    expect(_hasGreenText(root), isTrue);
  });
}
