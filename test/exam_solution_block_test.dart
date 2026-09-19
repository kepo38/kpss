import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/widgets/exam_text/exam_solution_view.dart';

void main() {
  testWidgets('ExamSolutionBlock shows annotation image and solution text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExamSolutionBlock(
            text: '## 1. Aşama\n\nSonuç **B**',
            imageUrl: 'https://example.com/solution.png',
          ),
        ),
      ),
    );

    expect(find.text('Şekil üzerinde işaretli çözüm'), findsOneWidget);
    expect(find.text('Büyütmek için dokun'), findsOneWidget);
    expect(find.textContaining('1. Aşama'), findsOneWidget);
  });

  testWidgets('ExamSolutionBlock hides image section when url empty', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ExamSolutionBlock(
            text: 'Yalnızca metin çözüm',
          ),
        ),
      ),
    );

    expect(find.text('Şekil üzerinde işaretli çözüm'), findsNothing);
    expect(find.text('Yalnızca metin çözüm'), findsOneWidget);
  });
}
