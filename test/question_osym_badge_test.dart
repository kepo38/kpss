import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/models/question_model.dart';

void main() {
  test('QuestionModel parses osymSordu from API JSON', () {
    final q = QuestionModel.fromJson({
      'id': 'q1',
      'dersAdi': 'Türkçe',
      'konuAdi': 'Anlam',
      'altKonuAdi': '',
      'soruMetni': 'Soru',
      'siklar': {'A': 'a', 'B': 'b', 'C': 'c', 'D': 'd', 'E': 'e'},
      'dogruCevap': 'A',
      'cozumMetni': '',
      'guncellenmeTarihi': '2026-01-01T00:00:00.000Z',
      'osymSordu': true,
    });
    expect(q.osymSordu, isTrue);
  });
}
