/// Semver-benzeri sürüm karşılaştırması (build numarası ve sonek yok sayılır).
int compareAppVersions(String a, String b) {
  final partsA = _parseVersionParts(a);
  final partsB = _parseVersionParts(b);
  for (var i = 0; i < 3; i++) {
    if (partsA[i] < partsB[i]) return -1;
    if (partsA[i] > partsB[i]) return 1;
  }
  return 0;
}

/// Yüklü sürüm önerilenden düşük mü?
bool isAppVersionOlder(String installed, String recommended) {
  final rec = recommended.trim();
  if (rec.isEmpty) return false;
  return compareAppVersions(installed, rec) < 0;
}

List<int> _parseVersionParts(String raw) {
  final core = raw.split('+').first.split('-').first.trim();
  if (core.isEmpty) return const [0, 0, 0];
  final parts = core
      .split('.')
      .map((part) => int.tryParse(part.trim()) ?? 0)
      .toList();
  while (parts.length < 3) {
    parts.add(0);
  }
  return parts.take(3).toList();
}
