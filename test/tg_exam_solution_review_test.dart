import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/models/question_model.dart';
import 'package:kpss_akademi/screens/quiz_screen.dart';

QuestionModel _question({String id = 'tg-1'}) {
  return QuestionModel(
    id: id,
    dersAdi: 'Türkçe',
    konuAdi: 'Paragraf',
    altKonuAdi: 'Ana düşünce',
    soruMetni: 'Bu sorunun doğru cevabı hangisidir?',
    siklar: const {
      'A': 'Birinci seçenek',
      'B': 'İkinci seçenek',
      'C': 'Üçüncü seçenek',
      'D': 'Dördüncü seçenek',
      'E': 'Beşinci seçenek',
    },
    dogruCevap: 'A',
    cozumMetni: 'Çözüm açıklaması',
    guncellenmeTarihi: DateTime(2026),
  );
}

Widget _review({String? answer}) {
  return MaterialApp(
    home: QuizScreen(
      title: '2026 TG Deneme Sınavı',
      questions: [_question()],
      initialAnswers: [answer],
      hideQuestionCounter: true,
      adFreeExperience: true,
      tgExamMode: true,
      tgExamSolutionReview: true,
      skipResultDialog: true,
    ),
  );
}

void main() {
  testWidgets('TG solution review shows exam title and section filters',
      (tester) async {
    await tester.pumpWidget(_review(answer: 'A'));
    await tester.pump();

    expect(find.text('2026 TG Deneme Sınavı'), findsWidgets);
    expect(find.text('Soru 1/1'), findsNothing);
    expect(find.text('GY'), findsOneWidget);
    expect(find.text('GK'), findsOneWidget);
  });

  testWidgets('TG solution review identifies correct answer', (tester) async {
    await tester.pumpWidget(_review(answer: 'A'));
    await tester.pump();

    expect(find.text('Doğru cevapladın'), findsOneWidget);
  });

  testWidgets('TG solution review identifies wrong and blank answers',
      (tester) async {
    await tester.pumpWidget(_review(answer: 'B'));
    await tester.pump();
    expect(find.text('Yanlış cevapladın'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_review());
    await tester.pump();
    expect(find.text('Bu soruyu cevaplamadın'), findsOneWidget);
  });

  testWidgets('TG solution review closes from any question without submit dialog',
      (tester) async {
    final questions = List.generate(3, (i) => _question(id: 'tg-$i'));

    await tester.pumpWidget(
      MaterialApp(
        home: QuizScreen(
          title: 'TG Deneme',
          questions: questions,
          initialAnswers: const ['A', null, 'B'],
          hideQuestionCounter: true,
          adFreeExperience: true,
          tgExamMode: true,
          tgExamSolutionReview: true,
          skipResultDialog: true,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Geri'));
    await tester.pumpAndSettle();

    expect(find.text('Sınavı Tamamla'), findsNothing);
    expect(find.text('TG Deneme'), findsNothing);
  });

  testWidgets('TG solution review last question shows Kapat not Tamamla',
      (tester) async {
    final questions = List.generate(2, (i) => _question(id: 'tg-$i'));

    await tester.pumpWidget(
      MaterialApp(
        home: QuizScreen(
          title: 'TG Deneme',
          questions: questions,
          initialAnswers: const ['A', 'B'],
          initialIndex: 1,
          hideQuestionCounter: true,
          adFreeExperience: true,
          tgExamMode: true,
          tgExamSolutionReview: true,
          skipResultDialog: true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Tamamla'), findsNothing);
    expect(find.text('Kapat'), findsOneWidget);

    await tester.tap(find.text('Kapat'));
    await tester.pumpAndSettle();

    expect(find.text('Sınavı Tamamla'), findsNothing);
    expect(find.text('TG Deneme'), findsNothing);
  });
}
