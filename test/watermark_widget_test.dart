import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/constants/brand_constants.dart';
import 'package:kpss_akademi/widgets/watermark_widget.dart';

void main() {
  testWidgets('WatermarkWidget shows a single brand mark behind content',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WatermarkWidget(
            child: Container(
              height: 900,
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
    expect(find.text(BrandConstants.brandLine1), findsOneWidget);
    expect(find.text(BrandConstants.brandLine2), findsOneWidget);
    expect(find.byType(WatermarkWidget), findsOneWidget);
  });
}
