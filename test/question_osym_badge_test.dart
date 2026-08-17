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

  test('QuestionModel parses scenario passage from API JSON', () {
    final q = QuestionModel.fromJson({
      'id': 'q1',
      'dersAdi': 'Türkçe',
      'konuAdi': 'Sözel Mantık',
      'altKonuAdi': '',
      'soruMetni': 'Hangisi doğrudur?',
      'siklar': {'A': 'a', 'B': 'b', 'C': 'c', 'D': 'd', 'E': 'e'},
      'dogruCevap': 'A',
      'cozumMetni': '',
      'guncellenmeTarihi': '2026-01-01T00:00:00.000Z',
      'scenarioId': '12',
      'scenarioTitle': 'Otobüs',
      'scenarioStem': 'Ali ve Ayşe aynı otobüstedir.',
      'scenarioOrder': 2,
    });
    expect(q.hasScenarioPassage, isTrue);
    expect(q.scenarioTitle, 'Otobüs');
    expect(q.scenarioOrder, 2);
  });

  test('keepGroupsContiguous restores sibling order', () {
    QuestionModel q({
      required String id,
      String? scenarioId,
      int order = 0,
    }) {
      return QuestionModel(
        id: id,
        dersAdi: 'Türkçe',
        konuAdi: 'Sözel Mantık',
        altKonuAdi: '',
        soruMetni: id,
        siklar: const {'A': 'a', 'B': 'b', 'C': 'c', 'D': 'd', 'E': 'e'},
        dogruCevap: 'A',
        cozumMetni: '',
        guncellenmeTarihi: DateTime.utc(2026, 1, 1),
        scenarioId: scenarioId,
        scenarioStem: scenarioId == null ? null : 'Olay',
        scenarioOrder: order,
      );
    }

    final ordered = QuestionModel.keepGroupsContiguous([
      q(id: 'lone'),
      q(id: 'b', scenarioId: 'g1', order: 2),
      q(id: 'a', scenarioId: 'g1', order: 1),
      q(id: 'c', scenarioId: 'g1', order: 3),
    ]);
    expect(ordered.map((e) => e.id).toList(), ['lone', 'a', 'b', 'c']);
  });
}
