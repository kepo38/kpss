class WrongQuestionModel {
  final String soruId;
  final int correctStreak;
  final DateTime sonCozulmeTarihi;

  const WrongQuestionModel({
    required this.soruId,
    this.correctStreak = 0,
    required this.sonCozulmeTarihi,
  });

  factory WrongQuestionModel.fromJson(Map<String, dynamic> json) {
    return WrongQuestionModel(
      soruId: json['soruId'] as String,
      correctStreak: json['correctStreak'] as int? ?? 0,
      sonCozulmeTarihi: DateTime.parse(json['sonCozulmeTarihi'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'soruId': soruId,
        'correctStreak': correctStreak,
        'sonCozulmeTarihi': sonCozulmeTarihi.toIso8601String(),
      };

  WrongQuestionModel copyWith({
    String? soruId,
    int? correctStreak,
    DateTime? sonCozulmeTarihi,
  }) {
    return WrongQuestionModel(
      soruId: soruId ?? this.soruId,
      correctStreak: correctStreak ?? this.correctStreak,
      sonCozulmeTarihi: sonCozulmeTarihi ?? this.sonCozulmeTarihi,
    );
  }
}
