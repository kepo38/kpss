import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/data/kpss_curriculum.dart';
import 'package:kpss_akademi/widgets/countdown_widget.dart';

void main() {
  tearDown(KpssCurriculum.clearCatalog);

  test('subjectsFor uses embedded fallback when catalog empty', () {
    KpssCurriculum.clearCatalog();
    final subjects = KpssCurriculum.subjectsFor(KpssType.lisans);
    expect(subjects.any((s) => s.id == 'turkce'), isTrue);
  });

  test('applyCatalogFromJson replaces subject/topic tree', () {
    KpssCurriculum.applyCatalogFromJson([
      {
        'slug': 'turkce',
        'name': 'Türkçe',
        'topics': [
          {
            'slug': 'turkce_anlam',
            'name': 'Sözcükte Anlam',
            'subtopics': [],
            'questions_per_test': 12,
          },
          {
            'slug': 'yeni_konu',
            'name': 'Panelden Eklenen Konu',
            'subtopics': ['Alt 1'],
            'questions_per_test': 8,
          },
        ],
      },
    ]);

    expect(KpssCurriculum.hasCatalog, isTrue);
    final subjects = KpssCurriculum.subjectsFor(KpssType.lisans);
    expect(subjects.length, 1);
    expect(subjects.first.topics.length, 2);
    expect(
      KpssCurriculum.findTopic(KpssType.lisans, 'yeni_konu')?.name,
      'Panelden Eklenen Konu',
    );
    expect(
      KpssCurriculum.findTopic(KpssType.lisans, 'yeni_konu')?.questionsPerTest,
      8,
    );
  });

  test('catalog persists via export/load roundtrip', () {
    final raw = [
      {
        'slug': 'matematik',
        'name': 'Matematik',
        'topics': [
          {'slug': 'mat_temel', 'name': 'Temel Kavramlar', 'subtopics': []},
        ],
      },
    ];
    KpssCurriculum.applyCatalogFromJson(raw);
    final exported = KpssCurriculum.exportCatalogJson();
    expect(exported, isNotNull);

    KpssCurriculum.clearCatalog();
    expect(KpssCurriculum.hasCatalog, isFalse);

    KpssCurriculum.loadCatalogFromJsonString(exported);
    expect(KpssCurriculum.hasCatalog, isTrue);
    expect(
      KpssCurriculum.findSubject(KpssType.lisans, 'matematik')?.name,
      'Matematik',
    );
  });
}
