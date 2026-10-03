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

  test('interleaveOsymSordu places one ÖSYM after every four unlabeled', () {
    QuestionModel q(String id, {bool osym = false}) {
      return QuestionModel(
        id: id,
        dersAdi: 'Tarih',
        konuAdi: 'Osmanlı',
        altKonuAdi: '',
        soruMetni: id,
        siklar: const {'A': 'a', 'B': 'b', 'C': 'c', 'D': 'd', 'E': 'e'},
        dogruCevap: 'A',
        cozumMetni: '',
        guncellenmeTarihi: DateTime.utc(2026, 1, 1),
        osymSordu: osym,
      );
    }

    final mixed = [
      for (var i = 1; i <= 16; i++) q('p$i'),
      for (var i = 1; i <= 4; i++) q('o$i', osym: true),
    ];
    final laid = QuestionModel.interleaveOsymSordu(mixed);
    expect(laid.length, 20);
    expect(
      [for (var i = 0; i < laid.length; i++) if (laid[i].osymSordu) i],
      [4, 9, 14, 19],
    );
    expect(laid.where((e) => e.osymSordu).length, 4);
  });

  test('interleaveOsymSordu continues normally when unlabeled are scarce', () {
    QuestionModel q(String id, {bool osym = false}) {
      return QuestionModel(
        id: id,
        dersAdi: 'Tarih',
        konuAdi: 'Osmanlı',
        altKonuAdi: '',
        soruMetni: id,
        siklar: const {'A': 'a', 'B': 'b', 'C': 'c', 'D': 'd', 'E': 'e'},
        dogruCevap: 'A',
        cozumMetni: '',
        guncellenmeTarihi: DateTime.utc(2026, 1, 1),
        osymSordu: osym,
      );
    }

    final laid = QuestionModel.interleaveOsymSordu([
      q('p1'),
      q('p2'),
      q('o1', osym: true),
      q('o2', osym: true),
      q('o3', osym: true),
    ]);
    expect(laid.map((e) => e.id).toList(), ['p1', 'p2', 'o1', 'o2', 'o3']);
  });
}
