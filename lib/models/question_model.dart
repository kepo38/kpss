class QuestionModel {
  final String id;
  final String dersAdi;
  final String konuAdi;
  final String altKonuAdi;
  final String soruMetni;
  final String? imageUrl;
  final String? sekilKodu;
  final Map<String, String> siklar;
  final String dogruCevap;
  final String cozumMetni;
  final int hataBildirimSayisi;
  final DateTime guncellenmeTarihi;
  final bool osymSordu;
  final String difficulty;
  final int attemptCount;
  final double? correctRate;
  final bool difficultyVisible;

  const QuestionModel({
    required this.id,
    required this.dersAdi,
    required this.konuAdi,
    required this.altKonuAdi,
    required this.soruMetni,
    this.imageUrl,
    this.sekilKodu,
    required this.siklar,
    required this.dogruCevap,
    required this.cozumMetni,
    this.hataBildirimSayisi = 0,
    required this.guncellenmeTarihi,
    this.osymSordu = false,
    this.difficulty = 'medium',
    this.attemptCount = 0,
    this.correctRate,
    this.difficultyVisible = false,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    final rawSvg = (json['sekilKodu'] as String?)?.trim();
    return QuestionModel(
      id: json['id'] as String,
      dersAdi: json['dersAdi'] as String,
      konuAdi: json['konuAdi'] as String,
      altKonuAdi: json['altKonuAdi'] as String,
      soruMetni: json['soruMetni'] as String,
      imageUrl: json['imageUrl'] as String?,
      sekilKodu: (rawSvg == null || rawSvg.isEmpty) ? null : rawSvg,
      siklar: Map<String, String>.from(json['siklar'] as Map),
      dogruCevap: json['dogruCevap'] as String,
      cozumMetni: json['cozumMetni'] as String,
      hataBildirimSayisi: json['hataBildirimSayisi'] as int? ?? 0,
      guncellenmeTarihi: DateTime.parse(json['guncellenmeTarihi'] as String),
      osymSordu: json['osymSordu'] as bool? ?? false,
      difficulty: json['difficulty'] as String? ?? 'medium',
      attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
      correctRate: (json['correctRate'] as num?)?.toDouble(),
      difficultyVisible: json['difficultyVisible'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dersAdi': dersAdi,
        'konuAdi': konuAdi,
        'altKonuAdi': altKonuAdi,
        'soruMetni': soruMetni,
        'imageUrl': imageUrl,
        'sekilKodu': sekilKodu,
        'siklar': siklar,
        'dogruCevap': dogruCevap,
        'cozumMetni': cozumMetni,
        'hataBildirimSayisi': hataBildirimSayisi,
        'guncellenmeTarihi': guncellenmeTarihi.toIso8601String(),
        'osymSordu': osymSordu,
        'difficulty': difficulty,
        'attemptCount': attemptCount,
        'correctRate': correctRate,
        'difficultyVisible': difficultyVisible,
      };

  QuestionModel copyWith({
    String? id,
    String? dersAdi,
    String? konuAdi,
    String? altKonuAdi,
    String? soruMetni,
    String? imageUrl,
    String? sekilKodu,
    Map<String, String>? siklar,
    String? dogruCevap,
    String? cozumMetni,
    int? hataBildirimSayisi,
    DateTime? guncellenmeTarihi,
    bool? osymSordu,
    String? difficulty,
    int? attemptCount,
    double? correctRate,
    bool? difficultyVisible,
  }) {
    return QuestionModel(
      id: id ?? this.id,
      dersAdi: dersAdi ?? this.dersAdi,
      konuAdi: konuAdi ?? this.konuAdi,
      altKonuAdi: altKonuAdi ?? this.altKonuAdi,
      soruMetni: soruMetni ?? this.soruMetni,
      imageUrl: imageUrl ?? this.imageUrl,
      sekilKodu: sekilKodu ?? this.sekilKodu,
      siklar: siklar ?? this.siklar,
      dogruCevap: dogruCevap ?? this.dogruCevap,
      cozumMetni: cozumMetni ?? this.cozumMetni,
      hataBildirimSayisi: hataBildirimSayisi ?? this.hataBildirimSayisi,
      guncellenmeTarihi: guncellenmeTarihi ?? this.guncellenmeTarihi,
      osymSordu: osymSordu ?? this.osymSordu,
      difficulty: difficulty ?? this.difficulty,
      attemptCount: attemptCount ?? this.attemptCount,
      correctRate: correctRate ?? this.correctRate,
      difficultyVisible: difficultyVisible ?? this.difficultyVisible,
    );
  }
}
