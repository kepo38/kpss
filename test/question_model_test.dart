import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/models/question_model.dart';

void main() {
  test('keeps array display math delimiters from json', () {
    const array =
        r'$$\begin{array}{r} AB8 \\ -16C \\ \hline CA3 \end{array}$$';
    final q = QuestionModel.fromJson({
      'id': 'q1',
      'dersAdi': 'Matematik',
      'konuAdi': 'Basamak',
      'altKonuAdi': '',
      'soruMetni': array,
      'siklar': {'A': '11'},
      'dogruCevap': 'A',
      'cozumMetni': '',
      'guncellenmeTarihi': '2026-01-01T00:00:00.000Z',
    });
    expect(q.soruMetni, array);
  });

  test('downgrades short gemini display wrappers to inline', () {
    final q = QuestionModel.fromJson({
      'id': 'q2',
      'dersAdi': 'Matematik',
      'konuAdi': 'Basamak',
      'altKonuAdi': '',
      'soruMetni': r'$$x+1$$',
      'siklar': {'A': '1'},
      'dogruCevap': 'A',
      'cozumMetni': '',
      'guncellenmeTarihi': '2026-01-01T00:00:00.000Z',
    });
    expect(q.soruMetni, r'$x+1$');
  });
}
