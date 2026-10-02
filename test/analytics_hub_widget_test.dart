import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/models/subject_performance.dart';
import 'package:kpss_akademi/screens/analytics_hub_screen.dart';
import 'package:kpss_akademi/widgets/countdown_widget.dart';
import 'package:kpss_akademi/widgets/analytics_study_vault.dart';
import 'package:kpss_akademi/widgets/analytics_success_hero.dart';

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
    expect(
      tester.getTopLeft(find.byType(AnalyticsStudyVault)).dy,
      lessThan(tester.getTopLeft(find.textContaining('HAFTALIK')).dy),
    );
  });

  testWidgets('boş başarı hero ölçüm yok metnini gösterir', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnalyticsSuccessHero(
            overall: OverallPerformance(
              solved: 0,
              correct: 0,
              wrong: 0,
              blank: 0,
              totalQuestions: 120,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('BAŞARI'), findsOneWidget);
    expect(find.text('Konu testleri'), findsOneWidget);
    expect(find.text('Henüz ölçüm yok'), findsOneWidget);
  });

  testWidgets('dolu başarı hero net oranı ve metrikleri gösterir', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnalyticsSuccessHero(
            overall: OverallPerformance(
              solved: 20,
              correct: 12,
              wrong: 4,
              blank: 4,
              totalQuestions: 200,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('BAŞARI'), findsOneWidget);
    expect(find.text('Net oranı'), findsOneWidget);
    expect(find.text('Doğru'), findsOneWidget);
    expect(find.text('Yanlış'), findsOneWidget);
    expect(find.text('Boş'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('4'), findsNWidgets(2)); // wrong + blank
    expect(find.text('Net 11.00'), findsOneWidget);
    expect(find.text('20 çözülen'), findsOneWidget);
    expect(find.text('200 soruluk havuz'), findsOneWidget);
  });
}
