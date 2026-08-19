import '../constants/brand_constants.dart';
import '../constants/daily_mini_exam_constants.dart';

/// Python backend ile aynı LCG Fisher-Yates.
List<String> lcgShuffle(List<String> items, int seed) {
  final arr = List<String>.from(items);
  var state = seed & 0xFFFFFFFF;
  for (var i = arr.length - 1; i > 0; i--) {
    state = (state * 1664525 + 1013904223) & 0xFFFFFFFF;
    final j = state % (i + 1);
    final tmp = arr[i];
    arr[i] = arr[j];
    arr[j] = tmp;
  }
  return arr;
}

/// FNV-1a 32-bit — `daily_mini_exam._uint32_seed` ile aynı.
int dailyMiniSeed(DateTime examDate, String kpssType) {
  final raw = '${isoDate(examDate)}|$kpssType|daily-mini-v1';
  var h = 2166136261;
  for (final unit in raw.codeUnits) {
    h ^= unit & 0xff;
    h = (h * 16777619) & 0xFFFFFFFF;
  }
  return h;
}

String isoDate(DateTime d) {
  final local = DateTime(d.year, d.month, d.day);
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

({String prefix, String rest}) splitFrostedEmail(String email) {
  final value = email.trim();
  if (value.isEmpty) return (prefix: '', rest: '');
  final at = value.indexOf('@');
  if (at < 0) {
    final prefix = value.length <= 3 ? value : value.substring(0, 3);
    final masked = '•' * (value.length - prefix.length);
    return (prefix: prefix, rest: masked);
  }
  final local = value.substring(0, at);
  final domain = value.substring(at);
  if (local.length <= 3) {
    return (prefix: local, rest: domain);
  }
  return (prefix: local.substring(0, 3), rest: '•••$domain');
}

/// Mini deneme süresi — örn. `8 dk 04 sn` veya `1:05:22`.
String formatExamDuration(int seconds) {
  if (seconds <= 0) return '—';
  final d = Duration(seconds: seconds);
  if (d.inHours > 0) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
  final m = d.inMinutes;
  final s = d.inSeconds.remainder(60);
  if (m > 0) return '$m dk ${s.toString().padLeft(2, '0')} sn';
  return '$s sn';
}

String formatTrInt(int value) {
  final sign = value < 0 ? '-' : '';
  final digits = value.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final fromEnd = digits.length - i;
    if (i > 0 && fromEnd % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  return '$sign$buf';
}

/// "Bugünkü Sıralaman: 5.340 Kişi Arasından 312."
String formatRankBadgeLine({
  required int participantCount,
  required int rank,
}) {
  return 'Bugünkü Sıralaman: ${formatTrInt(participantCount)} Kişi Arasından '
      '${formatTrInt(rank)}.';
}

String buildDailyMiniShareText({
  required int rank,
  required int participantCount,
  required int correct,
  required int total,
}) {
  return 'Hedef Kamu — Günün Mini Denemesi 🏆\n'
      '${formatTrInt(participantCount)} kişi arasından ${formatTrInt(rank)}. oldum '
      '($correct/$total doğru).\n'
      'Sen de dene! ${BrandConstants.shareHashtag}';
}

String formatHms(Duration remaining) {
  final d = remaining.isNegative ? Duration.zero : remaining;
  final h = d.inHours.toString().padLeft(2, '0');
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}

/// 06:00–00:00 açık; gece yarısı kapanır, 06:00'de yenilenir.
class DailyMiniExamWindow {
  final DateTime now;
  final DateTime opensAt;
  final DateTime closesAt;

  const DailyMiniExamWindow({
    required this.now,
    required this.opensAt,
    required this.closesAt,
  });

  factory DailyMiniExamWindow.from(DateTime now) {
    final local = now.toLocal();
    final today = DateTime(local.year, local.month, local.day);
    final opensAt = today.add(
      const Duration(hours: DailyMiniExamConstants.opensHour),
    );
    final closesAt = today.add(const Duration(days: 1));
    return DailyMiniExamWindow(now: local, opensAt: opensAt, closesAt: closesAt);
  }

  bool get isOpen => !now.isBefore(opensAt) && now.isBefore(closesAt);

  /// Gece yarısı – 06:00 arası (henüz açılmadan önce).
  bool get isPreOpen => now.isBefore(opensAt);

  DateTime get examDate => DateTime(now.year, now.month, now.day);

  Duration get remaining {
    final target = isOpen ? closesAt : opensAt;
    final left = target.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  String get remainingLabel => '${formatHms(remaining)} kaldı';
}

String congratulationsMessage({
  required int total,
  required int correct,
  required int wrong,
  int blank = 0,
  int? rank,
  int? participantCount,
}) {
  final buf = StringBuffer(
    'Tebrikler! $total Soruda $correct Doğru, $wrong Yanlış yaptın.',
  );
  if (blank > 0) {
    buf.write(' ($blank boş)');
  }
  if (rank != null && participantCount != null && participantCount > 0) {
    buf.write(
      ' Bugün bu testi çözen ${formatTrInt(participantCount)} kişi arasında '
      '$rank. oldun!',
    );
  }
  return buf.toString();
}

/// Yerel yedek seçim (API yoksa). Sıralı id listeleri verilir.
List<String> pickLocalQuestionIds({
  required DateTime examDate,
  required String kpssType,
  required List<String> tarihIds,
  required List<String> cografyaIds,
  required List<String> vatandaslikIds,
  required List<String> turkceIds,
  List<String> leftovers = const [],
}) {
  final seed = dailyMiniSeed(examDate, kpssType);
  final selected = <String>[];
  final used = <String>{};

  void take(List<String> pool) {
    final unused = pool.where((id) => !used.contains(id)).toList()..sort();
    final shuffled = lcgShuffle(unused, seed);
    final takeN = shuffled.take(DailyMiniExamConstants.perPool);
    selected.addAll(takeN);
    used.addAll(takeN);
  }

  take(tarihIds);
  take(cografyaIds);
  take(vatandaslikIds);
  take(turkceIds);

  if (selected.length < DailyMiniExamConstants.questionCount) {
    final extraPool = leftovers.where((id) => !used.contains(id)).toList()
      ..sort();
    final extra = lcgShuffle(extraPool, seed ^ 0xA5A5A5A5).take(
      DailyMiniExamConstants.questionCount - selected.length,
    );
    selected.addAll(extra);
  }
  return selected.take(DailyMiniExamConstants.questionCount).toList();
}
