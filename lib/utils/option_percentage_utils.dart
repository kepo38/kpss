/// Şık dağılım yüzdeleri — sunucu gecikmesinde yerel tahmin.
Map<String, double> bumpOptionDistribution({
  required Map<String, double>? base,
  required int solvedCount,
  required String selectedKey,
  required Iterable<String> optionKeys,
}) {
  final keys = optionKeys.map((k) => k.trim().toUpperCase()).toList();
  final pick = selectedKey.trim().toUpperCase();
  if (keys.isEmpty || !keys.contains(pick)) return base ?? const {};

  if (solvedCount <= 0 && (base == null || base.isEmpty)) {
    return {for (final k in keys) k: k == pick ? 100.0 : 0.0};
  }

  final counts = <String, int>{for (final k in keys) k: 0};
  var total = solvedCount > 0 ? solvedCount : 0;

  if (base != null && total > 0) {
    var assigned = 0;
    String? driftKey;
    var driftVal = -1;
    for (final k in keys) {
      final c = ((base[k] ?? 0) * total / 100).round();
      counts[k] = c;
      assigned += c;
      if (c >= driftVal) {
        driftVal = c;
        driftKey = k;
      }
    }
    final drift = total - assigned;
    if (drift != 0 && driftKey != null) {
      counts[driftKey] = counts[driftKey]! + drift;
    }
  }

  counts[pick] = (counts[pick] ?? 0) + 1;
  total += 1;

  final out = <String, double>{};
  var pctSum = 0.0;
  String? lastKey;
  for (final k in keys) {
    lastKey = k;
    final pct = (counts[k]! * 1000 / total).round() / 10.0;
    out[k] = pct;
    pctSum += pct;
  }
  if (lastKey != null && (pctSum - 100).abs() > 0.05) {
    out[lastKey] = double.parse(
      (out[lastKey]! + (100 - pctSum)).toStringAsFixed(1),
    );
  }
  return out;
}
