import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/widgets/exam_text/exam_solution_view.dart';
import 'package:kpss_akademi/widgets/question_stem_content.dart';

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

  testWidgets('ExamSolutionBlock skips top image when [ŞEKİL] present', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExamSolutionBlock(
            text: 'Açıklama\n\n${QuestionStemContent.inlineFigurePlaceholder}\n\nSonuç',
            imageUrl: 'https://example.com/solution.png',
            sekilKodu:
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><circle cx="5" cy="5" r="4"/></svg>',
          ),
        ),
      ),
    );

    expect(find.text('Şekil üzerinde işaretli çözüm'), findsNothing);
    expect(find.textContaining('Açıklama'), findsOneWidget);
    expect(find.textContaining('Sonuç'), findsOneWidget);
  });

  testWidgets('ExamSolutionBlock prefers SVG over annotation PNG without [ŞEKİL]',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExamSolutionBlock(
            text: 'Çözüm metni — şekil metnin altında',
            imageUrl: 'https://example.com/solution_overlay.png',
            sekilKodu:
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><circle cx="5" cy="5" r="4"/></svg>',
          ),
        ),
      ),
    );

    expect(find.text('Şekil üzerinde işaretli çözüm'), findsNothing);
    expect(find.textContaining('Çözüm metni'), findsOneWidget);
    expect(find.byType(QuestionSvgFigure), findsOneWidget);
  });
}
