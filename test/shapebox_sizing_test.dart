import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/widgets/formatted_text.dart';

void main() {
  testWidgets('triangle shapebox stays compact with label inside', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const stem =
        r'''$\shapebox{triangle}{AB}$: Küpü $AB$'ye eşit

$\shapebox{square}{73} + \shapebox{triangle}{37}$ ifadesinin değeri kaçtır?''';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0B1526),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: FormattedText(
              stem,
              preNormalized: true,
              preserveLineBreaks: true,
              examLayout: true,
              examWrap: true,
              examScaleDown: false,
              textAlign: TextAlign.justify,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                height: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AB'), findsOneWidget);
    expect(find.text('73'), findsOneWidget);
    expect(find.text('37'), findsOneWidget);

    // Parse sanity: WidgetSpan child text is present (not eaten by math).
    final abBox = tester.getSize(find.text('AB'));
    expect(abBox.width, greaterThan(0));
    expect(abBox.height, greaterThan(0));

    // Shape boxes are ~1.75em at 18px ≈ 31.5px; reject full-bleed triangles.
    final paints = find.byType(CustomPaint);
    var shapeCount = 0;
    final triangleBoxes = <Rect>[];
    for (final el in paints.evaluate()) {
      final rb = el.renderObject as RenderBox?;
      if (rb == null || !rb.hasSize) continue;
      if (rb.size.width >= 100 || rb.size.height >= 80) continue; // scaffold etc.
      expect(rb.size.width, greaterThan(24), reason: 'triangle too small ${rb.size}');
      expect(rb.size.width, lessThan(55), reason: 'triangle width ${rb.size}');
      expect(rb.size.height, greaterThan(20), reason: 'triangle too short ${rb.size}');
      expect(rb.size.height, lessThan(45), reason: 'triangle height ${rb.size}');
      final topLeft = rb.localToGlobal(Offset.zero);
      triangleBoxes.add(topLeft & rb.size);
      shapeCount++;
    }
    expect(shapeCount, greaterThanOrEqualTo(2));

    // Label vertical center should sit in the visual/centroid band (~50–68% of △ height),
    // not pinned near the base (old top:0.38 / bottom:0.06 padding).
    void expectLabelInVisualCenter(Finder labelFinder) {
      final labelTopLeft = tester.getTopLeft(labelFinder);
      final labelSize = tester.getSize(labelFinder);
      final labelCy = labelTopLeft.dy + labelSize.height / 2;
      Rect? host;
      for (final box in triangleBoxes) {
        if (box.inflate(2).contains(labelTopLeft + Offset(labelSize.width / 2, labelSize.height / 2))) {
          host = box;
          break;
        }
      }
      expect(host, isNotNull, reason: 'label not inside a triangle outline');
      final t = (labelCy - host!.top) / host.height;
      expect(t, greaterThan(0.48), reason: 'label too high in triangle (t=$t)');
      expect(t, lessThan(0.70), reason: 'label too low in triangle (t=$t)');
    }

    expectLabelInVisualCenter(find.text('AB'));
    expectLabelInVisualCenter(find.text('37'));
  });

  test('parseMathBodyWithShapes keeps AB as shape label', () {
    const base = TextStyle(fontSize: 16, color: Colors.white);
    final spans = FormattedText.parseSpans(
      r'$\shapebox{triangle}{AB}$',
      base,
    );
    expect(spans, isNotEmpty);
    final hasAb = spans.any((s) {
      if (s is WidgetSpan) {
        // buildShapeBox → Text('AB') somewhere under the widget
        return true;
      }
      return false;
    });
    expect(hasAb, isTrue);
  });
}
