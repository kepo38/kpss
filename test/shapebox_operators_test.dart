import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/widgets/formatted_text.dart';

void main() {
  test('rewriteSymbolicShapeOperators maps prefix ops to shapebox', () {
    final out = FormattedText.rewriteSymbolicShapeOperators(
      r'$\square AB$ ve $\triangle 37$',
    );
    expect(out, contains(r'\shapebox{square}{AB}'));
    expect(out, contains(r'\shapebox{triangle}{37}'));
    expect(out, isNot(contains(r'\square AB')));
  });

  test('normalizeLatex rewrites square/triangle prefixes', () {
    final out = FormattedText.normalizeLatex(r'$\square 73 + \triangle 37$');
    expect(out, contains(r'\shapebox{square}{73}'));
    expect(out, contains(r'\shapebox{triangle}{37}'));
  });

  testWidgets('shapebox renders inside square and triangle outlines', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FormattedText(
            r'$\shapebox{square}{73} + \shapebox{triangle}{37}$',
            examLayout: true,
            examWrap: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('73'), findsOneWidget);
    expect(find.text('37'), findsOneWidget);
    expect(find.textContaining('â–¡'), findsNothing);
  });
}
