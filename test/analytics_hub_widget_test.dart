import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/screens/analytics_hub_screen.dart';
import 'package:kpss_akademi/widgets/analytics_study_vault.dart';
import 'package:kpss_akademi/widgets/countdown_widget.dart';

void main() {
  testWidgets('AnalyticsHub embedded shows core sections', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnalyticsHubScreen(
            kpssType: KpssType.lisans,
            embedded: true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('DERSLER'), findsOneWidget);
    expect(find.byType(AnalyticsStudyVault), findsOneWidget);
    expect(find.textContaining('HAFTALIK'), findsOneWidget);
  });
}
