import 'dart:convert';

import '../widgets/countdown_widget.dart';

/// KPSS GY–GK müfredat ağacı (Lisans / Ön Lisans / Ortaöğretim ortak çekirdek).
class KpssSubject {
  final String id;
  final String name;
  final List<KpssTopic> topics;

  const KpssSubject({
    required this.id,
    required this.name,
    required this.topics,
  });
}

class KpssTopic {
  final String id;
  final String name;
  final List<String> subtopics;
  final int? questionsPerTest;

  const KpssTopic({
    required this.id,
    required this.name,
    this.subtopics = const [],
    this.questionsPerTest,
  });
}

class KpssCurriculum {
  KpssCurriculum._();

  static List<KpssSubject>? _catalogSubjects;
  static List<dynamic>? _catalogRaw;

  /// Django kataloğundan yüklenmiş müfredat var mı?
  static bool get hasCatalog =>
      _catalogSubjects != null && _catalogSubjects!.isNotEmpty;

  /// API kataloğunu uygular (panelden eklenen/sıralanan konular dahil).
  static void applyCatalogFromJson(List<dynamic> raw) {
    _catalogRaw = raw;
    _catalogSubjects = _parseSubjects(raw);
  }

  static void clearCatalog() {
    _catalogSubjects = null;
    _catalogRaw = null;
  }

  static void loadCatalogFromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) {
      clearCatalog();
      return;
    }
    try {
      applyCatalogFromJson(jsonDecode(raw) as List<dynamic>);
    } catch (_) {
      clearCatalog();
    }
  }

  static String? exportCatalogJson() {
    if (_catalogRaw == null || _catalogSubjects == null) return null;
    return jsonEncode(_catalogRaw);
  }

  static List<KpssSubject> _parseSubjects(List<dynamic> raw) {
    final subjects = <KpssSubject>[];
    for (final s in raw) {
      if (s is! Map) continue;
      final subject = Map<String, dynamic>.from(s);
      final slug = subject['slug'] as String?;
      final name = subject['name'] as String?;
      if (slug == null || name == null) continue;

      final topicsRaw = subject['topics'] as List<dynamic>? ?? const [];
      final topics = <KpssTopic>[];
      for (final t in topicsRaw) {
        if (t is! Map) continue;
        final topic = Map<String, dynamic>.from(t);
        final topicSlug = topic['slug'] as String?;
        final topicName = topic['name'] as String?;
        if (topicSlug == null || topicName == null) continue;

        final subtopicsRaw = topic['subtopics'];
        final subtopics = subtopicsRaw is List
            ? subtopicsRaw.map((e) => e.toString()).toList()
            : const <String>[];

        final qpt = topic['questions_per_test'];
        topics.add(
          KpssTopic(
            id: topicSlug,
            name: topicName,
            subtopics: subtopics,
            questionsPerTest: qpt is int
                ? qpt
                : (qpt is num ? qpt.toInt() : null),
          ),
        );
      }

      subjects.add(KpssSubject(id: slug, name: name, topics: topics));
    }
    return subjects;
  }

  /// Varsayılan: konu başına testte kaç soru.
  static const int defaultQuestionsPerTest = 20;
  static const int minQuestionsPerTest = 5;
  static const int maxQuestionsPerTest = 40;

  static List<KpssSubject> subjectsFor(KpssType type) {
    if (_catalogSubjects != null && _catalogSubjects!.isNotEmpty) {
      return _catalogSubjects!;
    }
    // Tip bazlı ince farklar ileride; çekirdek GY-GK aynı.
    return switch (type) {
      KpssType.lisans || KpssType.onLisans || KpssType.ortaogretim => _gyGk,
    };
  }

  static KpssTopic? findTopic(KpssType type, String topicId) {
    for (final s in subjectsFor(type)) {
      for (final t in s.topics) {
        if (t.id == topicId) return t;
      }
    }
    return null;
  }

  static KpssSubject? findSubject(KpssType type, String subjectId) {
    for (final s in subjectsFor(type)) {
      if (s.id == subjectId) return s;
    }
    return null;
  }

  static String? subjectIdForTopic(KpssType type, String topicId) {
    for (final s in subjectsFor(type)) {
      if (s.topics.any((t) => t.id == topicId)) return s.id;
    }
    return null;
  }

  static Set<String> topicIdsForSubject(KpssType type, String subjectId) {
    final subject = findSubject(type, subjectId);
    if (subject == null) return {};
    return subject.topics.map((t) => t.id).toSet();
  }

  static const List<KpssSubject> _gyGk = [
    KpssSubject(
      id: 'turkce',
      name: 'Türkçe',
      topics: [
        KpssTopic(id: 'turkce_anlam', name: 'Sözcükte Anlam'),
        KpssTopic(id: 'turkce_cumlede_anlam', name: 'Cümlede Anlam'),
        KpssTopic(id: 'turkce_paragraf', name: 'Paragraf'),
        KpssTopic(id: 'turkce_dilbilgisi', name: 'Dil Bilgisi'),
        KpssTopic(id: 'turkce_ses', name: 'Ses Bilgisi'),
        KpssTopic(id: 'turkce_anlatim', name: 'Anlatım Bozuklukları'),
        KpssTopic(id: 'turkce_yazim', name: 'Yazım Yanlışları'),
        KpssTopic(id: 'turkce_noktalama', name: 'Noktalama İşaretleri'),
        KpssTopic(id: 'turkce_sozel_mantik', name: 'Sözel Mantık Soruları'),
      ],
    ),
    KpssSubject(
      id: 'matematik',
      name: 'Matematik',
      topics: [
        KpssTopic(id: 'mat_temel', name: 'Temel Kavramlar'),
        KpssTopic(id: 'mat_rasyonel', name: 'Rasyonel Sayılar'),
        KpssTopic(id: 'mat_koklu', name: 'Köklü Sayılar'),
        KpssTopic(id: 'mat_uslu', name: 'Üslü Sayılar'),
        KpssTopic(
          id: 'mat_problem',
          name: 'Problemler',
          questionsPerTest: 8,
        ),
        KpssTopic(
          id: 'mat_tablo_grafik',
          name: 'Tablo, Grafik Okuma ve Yorumlama',
        ),
        KpssTopic(id: 'mat_sayisal_mantik', name: 'Sayısal Mantık Soruları'),
        KpssTopic(id: 'mat_geometri', name: 'Temel Geometri'),
      ],
    ),
    KpssSubject(
      id: 'tarih',
      name: 'Tarih',
      topics: [
        KpssTopic(
          id: 'tarih_islamiyet_oncesi',
          name: 'İslamiyet Öncesi Türk Tarihi',
        ),
        KpssTopic(
          id: 'tarih_turk_islam',
          name: 'İlk Türk - İslam Devletleri ve Beylikleri',
        ),
        KpssTopic(
          id: 'tarih_osmanli_kurulus_yukselme',
          name: 'Osmanlı Devleti Kuruluş ve Yükselme Dönemleri',
        ),
        KpssTopic(
          id: 'tarih_osmanli_kultur',
          name: 'Osmanlı Devleti’nde Kültür ve Uygarlık',
        ),
        KpssTopic(
          id: 'tarih_osmanli_17',
          name: 'XVII. Yüzyılda Osmanlı Devleti (Duraklama Dönemi)',
        ),
        KpssTopic(
          id: 'tarih_osmanli_18',
          name: 'XVIII. Yüzyılda Osmanlı Devleti (Gerileme Dönemi)',
        ),
        KpssTopic(
          id: 'tarih_osmanli_19',
          name: 'XIX. Yüzyılda Osmanlı Devleti (Dağılma Dönemi)',
        ),
        KpssTopic(
          id: 'tarih_osmanli_20',
          name: 'XX. Yüzyılda Osmanlı Devleti',
        ),
        KpssTopic(
          id: 'tarih_kurtulus_hazirlik',
          name: 'Kurtuluş Savaşı Hazırlık Dönemi',
        ),
        KpssTopic(
          id: 'tarih_tbmm',
          name: 'I. TBMM Dönemi',
        ),
        KpssTopic(
          id: 'tarih_kurtulus_muharebe',
          name: 'Kurtuluş Savaşı Muharebeler Dönemi',
        ),
        KpssTopic(
          id: 'tarih_inkilaplar',
          name: 'Atatürk İnkılapları',
        ),
        KpssTopic(
          id: 'tarih_ilkeler',
          name: 'Atatürk İlkeleri',
        ),
        KpssTopic(
          id: 'tarih_partiler',
          name: 'Partiler ve Partileşme Dönemi (İç Politika)',
        ),
        KpssTopic(
          id: 'tarih_dis_politika',
          name: 'Atatürk Dönemi Türk Dış Politikası',
        ),
        KpssTopic(
          id: 'tarih_sonrasi',
          name: 'Atatürk Sonrası Dönem',
        ),
        KpssTopic(
          id: 'tarih_ataturk_hayat',
          name: 'Atatürk’ün Hayatı ve Kişiliği',
        ),
        KpssTopic(
          id: 'tarih_cagdas_turk_dunya',
          name: 'Çağdaş Türk ve Dünya Tarihi',
          subtopics: [
            'II. Dünya Savaşı Dönemi (1939 - 1945)',
            'Soğuk Savaş Dönemi (1945 - 1960\'ların Başı)',
            'Yumuşama (Detant) Dönemi ve Sonrası (1960\'lar - 1980\'ler)',
            'Küreselleşen Dünya (1990\'lardan Günümüze)',
          ],
        ),
      ],
    ),
    KpssSubject(
      id: 'cografya',
      name: 'Coğrafya',
      topics: [
        KpssTopic(
          id: 'cog_konum',
          name: 'Türkiye’nin Coğrafi Konumu',
          subtopics: [
            'Matematik (Mutlak) Konum',
            'Türkiye’nin Matematik (Mutlak) Konumu ve Sonuçları',
            'Türkiye’nin Özel (Göreceli) Konumu ve Sonuçları',
            'Türkiye’nin Jeopolitiği',
          ],
        ),
        KpssTopic(
          id: 'cog_yersekilleri',
          name: 'Türkiye’nin Yerşekilleri ve Özellikleri',
          subtopics: [
            'Türkiye’nin Yerşekillerinin Genel Özellikleri',
            'Fiziki Haritalar',
            'Türkiye’nin Jeolojik Geçmişi',
            'Türkiye’nin Platoları ve Ovaları',
            'Türkiye’de Dış Güçlerin Oluşturduğu Yer Şekilleri',
            'Türkiye’nin Kıyı Tipleri',
            'Türkiye’de Toprak Oluşumu ve Tipleri',
            'Türkiye’nin Su Varlığı',
            'Türkiye’de Doğal Afetler',
          ],
        ),
        KpssTopic(
          id: 'cog_iklim_bitki',
          name: 'Türkiye’nin İklimi ve Bitki Örtüsü',
          subtopics: [
            'Türkiye’nin İklimi',
            'Türkiye’de Sıcaklık',
            'Türkiye’de Nemlilik ve Yağış',
            'Türkiye’de İklim Tipleri',
            'Türkiye’nin Bitki Örtüsü',
            'Türkiye’nin İklim Tipleri ve Bitki Örtüsü',
          ],
        ),
        KpssTopic(
          id: 'cog_nufus_yerlesme',
          name: 'Türkiye’de Nüfus ve Yerleşme',
          subtopics: [
            'Türkiye’de Nüfus Özellikleri',
            'Türkiye’de Nüfusun Dağılışı ve Nüfus Yoğunluğu',
            'Türkiye’nin Nüfusu ve Nüfus Sayımları',
            'Türkiye’nin Nüfus Politikaları',
            'Türkiye’de Nüfus Projeksiyonları',
            'Türkiye’de Göçler',
            'Türkiye’de Yerleşme',
            'Türkiye’de Mesken Tipleri',
          ],
        ),
        KpssTopic(
          id: 'cog_anadolu_uygarlik',
          name: 'Anadolu Uygarlıkları',
        ),
        KpssTopic(
          id: 'cog_tarim',
          name: 'Türkiye’de Tarım, Hayvancılık ve Ormancılık',
          subtopics: [
            'Türkiye’de Arazi Kullanımı',
            'Türkiye Ekonomisinin Sektörel Dağılımı',
            'Türkiye Ekonomisini Etkileyen Faktörler',
            'Türkiye’de Tarım',
            'Türkiye’de Hayvancılık',
            'Türkiye’de Ormancılık',
          ],
        ),
        KpssTopic(
          id: 'cog_maden_enerji_sanayi',
          name: 'Türkiye’de Madenler, Enerji Kaynakları ve Sanayi',
          subtopics: [
            'Türkiye’de Madenler',
            'Türkiye’de Enerji Kaynakları',
            'Türkiye’de Sanayi',
          ],
        ),
        KpssTopic(
          id: 'cog_ulasim_ticaret_turizm',
          name: 'Türkiye’de Ulaşım, Ticaret ve Turizm',
          subtopics: [
            'Türkiye’de Ulaşım',
            'Türkiye’de Ticaret',
            'Türkiye’de Turizm',
            'Türkiye’nin Millî Parkları',
            'Türkiye’de Şehirler ve Özellikleri',
          ],
        ),
        KpssTopic(
          id: 'cog_bolgeler',
          name: 'Türkiye’nin Coğrafi Bölgeleri',
          subtopics: [
            'Türkiye’de Bölge Sınıflandırması',
            'Türkiye’nin Bölgesel Kalkınma Projeleri',
            'Karadeniz Bölgesi',
            'Marmara Bölgesi',
            'Ege Bölgesi',
            'Akdeniz Bölgesi',
            'İç Anadolu Bölgesi',
            'Doğu Anadolu Bölgesi',
            'Güneydoğu Anadolu Bölgesi',
            'Bölgelerin Özelliklerinin Karşılaştırılması',
          ],
        ),
      ],
    ),
    KpssSubject(
      id: 'vatandaslik',
      name: 'Vatandaşlık',
      topics: [
        KpssTopic(
          id: 'vat_hukuk_temel',
          name: 'Hukukun Temel Kavramları',
        ),
        KpssTopic(
          id: 'vat_devlet_demokrasi',
          name: 'Devlet Biçimleri, Demokrasi ve Kuvvetler Ayrılığı',
        ),
        KpssTopic(
          id: 'vat_anayasa_giris',
          name: 'Anayasa Hukukuna Giriş, Temel Kavramlar ve Türk Anayasa Tarihi',
        ),
        KpssTopic(
          id: 'vat_1982_ilkeler',
          name: '1982 Anayasasının Temel İlkeleri',
        ),
        KpssTopic(
          id: 'vat_yasama',
          name: 'Yasama',
        ),
        KpssTopic(
          id: 'vat_yurutme',
          name: 'Yürütme',
        ),
        KpssTopic(
          id: 'vat_yargi',
          name: 'Yargı',
        ),
        KpssTopic(
          id: 'vat_temel_haklar',
          name: 'Temel Hak ve Hürriyetler',
        ),
        KpssTopic(
          id: 'vat_idare_hukuku',
          name: 'İdare Hukuku',
        ),
      ],
    ),
    KpssSubject(
      id: 'guncel',
      name: 'Güncel Bilgiler',
      topics: [
        KpssTopic(
          id: 'guncel_tr',
          name: 'Türkiye Gündemi',
          subtopics: ['Siyaset', 'Ekonomi', 'Toplum'],
        ),
        KpssTopic(
          id: 'guncel_dunya',
          name: 'Dünya Gündemi',
          subtopics: ['Uluslararası Örgütler', 'Jeopolitik', 'Bilim-Teknoloji'],
        ),
      ],
    ),
  ];
}
