import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/models/question_model.dart';

void main() {
  test('QuestionModel parses visual option image urls', () {
    final q = QuestionModel.fromJson({
      'id': 'q1',
      'dersAdi': 'Mat',
      'konuAdi': 'Konu',
      'altKonuAdi': '',
      'soruMetni': 'Mum hangisi?',
      'siklar': {
        'A': 'Görsel şık',
        'B': 'Görsel şık',
        'C': 'Görsel şık',
        'D': 'Görsel şık',
        'E': 'Görsel şık',
      },
      'optionsAreImages': true,
      'optionImageUrls': {
        'A': 'https://example.com/a.jpg',
        'B': 'https://example.com/b.jpg',
        'C': null,
        'D': 'https://example.com/d.jpg',
        'E': 'https://example.com/e.jpg',
      },
      'dogruCevap': 'A',
      'cozumMetni': 'A',
      'guncellenmeTarihi': '2026-08-23T10:00:00.000Z',
    });
    expect(q.optionsAreImages, isTrue);
    expect(q.hasVisualOptions, isTrue);
    expect(q.optionImageUrlFor('A'), 'https://example.com/a.jpg');
    expect(q.optionImageUrlFor('C'), isNull);
  });

  test('QuestionModel text options stay non-visual', () {
    final q = QuestionModel.fromJson({
      'id': 'q2',
      'dersAdi': 'Mat',
      'konuAdi': 'Konu',
      'altKonuAdi': '',
      'soruMetni': '2+2?',
      'siklar': {'A': '3', 'B': '4', 'C': '5', 'D': '6', 'E': '7'},
      'dogruCevap': 'B',
      'cozumMetni': '4',
      'guncellenmeTarihi': '2026-08-23T10:00:00.000Z',
    });
    expect(q.optionsAreImages, isFalse);
    expect(q.hasVisualOptions, isFalse);
    expect(q.optionImageUrlFor('A'), isNull);
  });
}
