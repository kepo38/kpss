import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/widgets/question_rating_bar.dart';

void main() {
  testWidgets('shows five stars and submits selected value', (tester) async {
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuestionRatingBar(
            selectedStars: 2,
            averageRating: 3.5,
            ratingCount: 12,
            onRate: (stars) async => selected = stars,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.star_border_rounded), findsNWidgets(3));
    expect(find.text('3.50 · 12 oy'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('4 yıldız').first);
    await tester.pump();
    expect(selected, 4);
  });

  testWidgets('disables rating while saving', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuestionRatingBar(
            selectedStars: 3,
            saving: true,
            onRate: (_) async => calls++,
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('5 yıldız').first);
    await tester.pump();
    expect(calls, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
