import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/widgets/watermark_widget.dart';

void main() {
  testWidgets('WatermarkWidget places logo layer behind content', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WatermarkWidget(
            child: Container(
              height: 400,
              color: const Color(0xFF0C1424),
              alignment: Alignment.center,
              child: const Text('Soru metni'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Soru metni'), findsOneWidget);
    expect(find.text('HEDEF'), findsOneWidget);
    expect(find.text('KAMU'), findsOneWidget);
    expect(find.byType(WatermarkWidget), findsOneWidget);
  });
}
