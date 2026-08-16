import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/widgets/store_rating_card.dart';

void main() {
  testWidgets('shows five stars and opens store on tap', (tester) async {
    var opened = 0;
    int? lastStars;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StoreRatingCard(
            onOpenStore: () async {
              opened++;
              lastStars = 5;
            },
          ),
        ),
      ),
    );

    expect(find.text('Uygulamayı puanla'), findsOneWidget);
    expect(find.byIcon(Icons.star_border_rounded), findsNWidgets(5));

    await tester.tap(find.bySemanticsLabel('5 yıldız').first);
    await tester.pump();

    expect(opened, 1);
    expect(lastStars, 5);
    expect(find.byIcon(Icons.star_rounded), findsWidgets);
  });

  testWidgets('individual star tap fills that many stars', (tester) async {
    var opened = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StoreRatingCard(
            onOpenStore: () async => opened++,
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('3 yıldız').first);
    await tester.pump();

    expect(opened, 1);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
    expect(find.byIcon(Icons.star_border_rounded), findsNWidgets(2));
  });
}
