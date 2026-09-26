import '../models/practice_exam_model.dart';

/// Netlerden tahmini KPSS P3 / GY / GK puanı (ÖSYM resmi puanı değildir).
class KpssScoreEstimate {
  final double gyNet;
  final double gkNet;
  final double totalNet;
  final double gyScore;
  final double gkScore;
  final double p3Score;

  const KpssScoreEstimate({
    required this.gyNet,
    required this.gkNet,
    required this.totalNet,
    required this.gyScore,
    required this.gkScore,
    required this.p3Score,
  });
}

class KpssScoreCalculatorService {
  KpssScoreCalculatorService._();

  static const _gyMaxNet = 60.0;
  static const _gkMaxNet = 60.0;
  static const _minScore = 40.0;
  static const _maxScore = 100.0;

  static KpssScoreEstimate estimate(Map<String, DersSonuc> dersSonuclari) {
    var gyNet = 0.0;
    for (final d in PracticeExamModel.genelYetenekDersleri) {
      gyNet += dersSonuclari[d]?.net ?? 0;
    }

    var gkNet = 0.0;
    for (final d in PracticeExamModel.genelKulturDersleri) {
      gkNet += dersSonuclari[d]?.net ?? 0;
    }

    final gyScore = _standardScore(gyNet, _gyMaxNet);
    final gkScore = _standardScore(gkNet, _gkMaxNet);
    final p3Score = gyScore * 0.5 + gkScore * 0.5;

    return KpssScoreEstimate(
      gyNet: gyNet,
      gkNet: gkNet,
      totalNet: gyNet + gkNet,
      gyScore: gyScore,
      gkScore: gkScore,
      p3Score: p3Score,
    );
  }

  /// Monoton eğri — orta-yüksek netlerde hafif yukarı eğim.
  static double _standardScore(double net, double maxNet) {
    if (maxNet <= 0) return _minScore;
    final ratio = (net / maxNet).clamp(0.0, 1.0);
    final smooth = ratio * ratio * (3 - 2 * ratio);
    return _minScore + smooth * (_maxScore - _minScore);
  }
}
