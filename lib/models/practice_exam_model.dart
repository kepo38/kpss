/// KPSS deneme kaydı — GK/GY ayrımı ve yayın evi destekli.
class PracticeExamModel {
  final String id;
  final String denemeAdi;
  final String yayinEvi;
  final DateTime tarih;
  final Map<String, DersSonuc> dersSonuclari;
  final String? notlar;
  final String? sourcePackId;
  final bool isInAppGenerated;

  const PracticeExamModel({
    required this.id,
    required this.denemeAdi,
    required this.yayinEvi,
    required this.tarih,
    required this.dersSonuclari,
    this.notlar,
    this.sourcePackId,
    this.isInAppGenerated = false,
  });

  static const genelYetenekDersleri = ['Türkçe', 'Matematik'];
  static const genelKulturDersleri = [
    'Tarih',
    'Coğrafya',
    'Vatandaşlık',
  ];

  /// KPSS deneme ders başına soru sayısı.
  static const Map<String, int> dersSoruSayilari = {
    'Türkçe': 30,
    'Matematik': 30,
    'Tarih': 27,
    'Coğrafya': 18,
    'Vatandaşlık': 15,
  };

  static int soruSayisi(String ders) => dersSoruSayilari[ders] ?? 0;

  double get toplamNet =>
      dersSonuclari.values.fold(0.0, (sum, d) => sum + d.net);

  double get genelYetenekNet => _sectionNet(genelYetenekDersleri);
  double get genelKulturNet => _sectionNet(genelKulturDersleri);

  double _sectionNet(List<String> dersler) {
    return dersler
        .where(dersSonuclari.containsKey)
        .fold(0.0, (sum, d) => sum + dersSonuclari[d]!.net);
  }

  int get toplamDogru =>
      dersSonuclari.values.fold(0, (sum, d) => sum + d.dogru);
  int get toplamYanlis =>
      dersSonuclari.values.fold(0, (sum, d) => sum + d.yanlis);
  int get toplamBos =>
      dersSonuclari.values.fold(0, (sum, d) => sum + d.bos);

  factory PracticeExamModel.fromJson(Map<String, dynamic> json) {
    final dersMap = (json['dersSonuclari'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(
        key as String,
        DersSonuc.fromJson(Map<String, dynamic>.from(value as Map)),
      ),
    );
    return PracticeExamModel(
      id: json['id'] as String,
      denemeAdi: json['denemeAdi'] as String,
      yayinEvi: json['yayinEvi'] as String? ?? 'Diğer',
      tarih: DateTime.parse(json['tarih'] as String),
      dersSonuclari: dersMap,
      notlar: json['notlar'] as String?,
      sourcePackId: json['sourcePackId'] as String?,
      isInAppGenerated: json['isInAppGenerated'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'denemeAdi': denemeAdi,
        'yayinEvi': yayinEvi,
        'tarih': tarih.toIso8601String(),
        'dersSonuclari':
            dersSonuclari.map((k, v) => MapEntry(k, v.toJson())),
        'notlar': notlar,
        'sourcePackId': sourcePackId,
        'isInAppGenerated': isInAppGenerated,
      };
}

class DersSonuc {
  final int dogru;
  final int yanlis;
  final int bos;

  const DersSonuc({
    required this.dogru,
    required this.yanlis,
    required this.bos,
  });

  double get net => dogru - (yanlis / 4);

  factory DersSonuc.fromJson(Map<String, dynamic> json) => DersSonuc(
        dogru: json['dogru'] as int,
        yanlis: json['yanlis'] as int,
        bos: json['bos'] as int,
      );

  Map<String, dynamic> toJson() => {
        'dogru': dogru,
        'yanlis': yanlis,
        'bos': bos,
      };

  DersSonuc copyWith({int? dogru, int? yanlis, int? bos}) => DersSonuc(
        dogru: dogru ?? this.dogru,
        yanlis: yanlis ?? this.yanlis,
        bos: bos ?? this.bos,
      );
}

/// Yayın evi bazlı performans özeti.
class PublisherStats {
  final String yayinEvi;
  final int denemeSayisi;
  final double ortalamaNet;
  final double enYuksekNet;
  final double ortalamaGy;
  final double ortalamaGk;

  const PublisherStats({
    required this.yayinEvi,
    required this.denemeSayisi,
    required this.ortalamaNet,
    required this.enYuksekNet,
    required this.ortalamaGy,
    required this.ortalamaGk,
  });
}

/// Haftalık performans özeti.
class WeeklyPerformanceSummary {
  final int denemeSayisi;
  final double ortalamaNet;
  final double netDegisim;
  final int tekrarBekleyenSoru;
  final String enGucluDers;
  final String gelistirilmesiGerekenDers;

  const WeeklyPerformanceSummary({
    required this.denemeSayisi,
    required this.ortalamaNet,
    required this.netDegisim,
    required this.tekrarBekleyenSoru,
    required this.enGucluDers,
    required this.gelistirilmesiGerekenDers,
  });
}
