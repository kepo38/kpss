import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/services/ai_coach_service.dart';
import 'package:kpss_akademi/widgets/ai_coach_insight_card.dart';

void main() {
  test('coach message uses natural Turkish and avoids slang', () {
    final message = AiCoachService.composeMessage(
      subject: 'Tarih',
      topic: 'Atatürk İnkılapları',
      streak: 3,
    );

    expect(
      message,
      'Son üç test sonucuna göre Tarih dersinde gelişime açık bir alan '
      'bulunuyor. Öncelikle “Atatürk İnkılapları” konusuna odaklanmanı '
      'öneriyorum.',
    );
    expect(message, isNot(contains('patlıyorsun')));
    expect(message, isNot(contains("'tır")));
  });

  testWidgets('topic chip invokes navigation callback', (tester) async {
    final semantics = tester.ensureSemantics();
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiCoachInsightCard(
            insight: const CoachInsight(
              message: 'Konuya odaklanmanı öneriyorum.',
              subject: 'Tarih',
              topic: 'Atatürk İnkılapları',
            ),
            isPremium: true,
            onTopicTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Atatürk İnkılapları'));
    await tester.pump();

    expect(tapped, isTrue);
    expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsOneWidget);
    expect(
      tester.getSemantics(
        find.bySemanticsLabel('Atatürk İnkılapları konusuna git'),
      ),
      matchesSemantics(
        label: 'Atatürk İnkılapları konusuna git',
        isButton: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('locked coach card cannot invoke topic callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiCoachInsightCard(
            insight: const CoachInsight(
              message: 'Kişisel premium değerlendirme.',
              subject: 'Tarih',
              topic: 'Atatürk İnkılapları',
            ),
            isPremium: false,
            onTopicTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Atatürk İnkılapları konusuna git'), findsNothing);
    expect(tapped, isFalse);
  });

  testWidgets('empty state does not fabricate a performance claim',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AiCoachInsightCard(
            insight: null,
            isPremium: true,
          ),
        ),
      ),
    );

    expect(
      find.textContaining('Birkaç test çözdükten sonra'),
      findsOneWidget,
    );
    expect(find.textContaining('Coğrafya dersinde'), findsNothing);
  });
}
