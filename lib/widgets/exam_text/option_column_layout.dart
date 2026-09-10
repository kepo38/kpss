import '../formatted_text.dart';

/// ÖSYM eşleştirme şıkları: `Şanlıurfa - Antalya - Afyonkarahisar`.
class OptionColumnLayout {
  OptionColumnLayout._();

  static final _dashSplit = RegExp(r'\s+(?:[-–—―−]{1,3}|---+)\s+');
  static final _tightDashSplit = RegExp(r'[-–—―−]{1,3}');
  static final _pipeSplit = RegExp(r'\s*\|\s*');

  static final _labeledSplit = RegExp(r'\s*[,;]\s*(?=[^,:]{1,24}:)');

  static ({List<String> keys, List<String> vals})? labeledRow(String text) {
    final raw = FormattedText.stripMarkup(text)
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (raw.isEmpty || !raw.contains(':')) return null;
    final chunks = raw.split(_labeledSplit);
    if (chunks.length < 2) return null;
    final keys = <String>[];
    final vals = <String>[];
    for (final chunk in chunks) {
      final i = chunk.indexOf(':');
      if (i < 1) return null;
      final key = chunk.substring(0, i).trim();
      final val = chunk.substring(i + 1).trim();
      if (key.isEmpty || val.isEmpty || key.length > 24) return null;
      keys.add(key);
      vals.add(val);
    }
    return (keys: keys, vals: vals);
  }

  static List<String>? cellsOf(String text) {
    final labeled = labeledRow(text);
    if (labeled != null) return labeled.vals;
    final raw = FormattedText.stripMarkup(text)
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (raw.isEmpty) return null;
    var parts = _parts(raw, _dashSplit);
    if (parts.length < 2) parts = _parts(raw, _pipeSplit);
    if (parts.length < 2) {
      final tight = _parts(raw, _tightDashSplit);
      if (tight.length >= 2 && tight.every((p) => !p.contains(' '))) {
        parts = tight;
      }
    }
    if (parts.length < 2) return null;
    return parts;
  }

  static List<String> _parts(String raw, RegExp split) {
    return raw
        .split(split)
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// En az iki şık aynı sütun sayısına sahipse o sayı; aksi halde null.
  static int? alignedCount(Iterable<String> options) {
    final counts = <int, int>{};
    for (final option in options) {
      final cells = cellsOf(option);
      if (cells == null) continue;
      counts[cells.length] = (counts[cells.length] ?? 0) + 1;
    }
    var bestN = 0;
    var best = 0;
    counts.forEach((n, seen) {
      if (n >= 2 && seen > best) {
        best = seen;
        bestN = n;
      }
    });
    if (best < 2) return null;
    return bestN;
  }

  /// Explicit panel flag: dual → 2, triple → 3; otherwise null (no columns).
  static int? forcedColumns(String? optionTable) {
    switch (optionTable) {
      case 'dual':
        return 2;
      case 'triple':
        return 3;
      default:
        return null;
    }
  }

  static final _optColsMark = RegExp(r'<!--optcols:([^>]*)-->');

  static String visibleStem(String stem) {
    return stem
        .replaceAll(_optColsMark, '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static List<String>? headersFromOptions(
      Iterable<String> options, int columns) {
    for (final option in options) {
      final row = labeledRow(option);
      if (row != null && row.keys.length == columns) return row.keys;
    }
    return null;
  }

  static List<String>? headersFor(
    String stem,
    Iterable<String> options,
    int columns,
  ) {
    final found =
        headersFromStem(stem, columns) ?? headersFromOptions(options, columns);
    if (found != null) return found;
    if (columns == 2) return const ['Olay', 'Sonuç'];
    return null;
  }

  static List<String>? headersFromStem(String stem, int columns) {
    const romans = ['I', 'II', 'III', 'IV', 'V'];
    if (columns < 2 || columns > romans.length) return null;
    final marked = _markerHeaders(stem, columns);
    if (marked != null) return marked;
    final labels = <String>[];
    final visible = visibleStem(stem);
    for (var i = 0; i < columns; i++) {
      final roman = romans[i];
      final re = RegExp(
        '(^|[^IVX])$roman\\.\\s+([A-ZÇĞİÖŞÜa-zçğıöşüÂÎÛâîû]+)',
      );
      final m = re.firstMatch(visible);
      if (m == null) {
        return _pipeHeaders(visible, columns) ?? _wordHeaders(visible, columns);
      }
      labels.add(m.group(2)!);
    }
    return labels;
  }

  static List<String>? _markerHeaders(String stem, int columns) {
    final m = _optColsMark.firstMatch(stem);
    if (m == null) return null;
    final parts = m
        .group(1)!
        .split('|')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length == columns) return parts;
    return null;
  }

  static List<String>? _pipeHeaders(String stem, int columns) {
    for (final line in stem.split('\n')) {
      final parts = line
          .split('|')
          .map((e) => FormattedText.stripMarkup(e).trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (parts.length == columns) return parts;
    }
    return null;
  }

  static List<String>? _wordHeaders(String stem, int columns) {
    for (final line in stem.split('\n')) {
      final words = FormattedText.stripMarkup(line)
          .replaceAll(RegExp(r'_+'), ' ')
          .trim()
          .split(RegExp(r'\s+'))
          .where((e) => e.isNotEmpty)
          .toList();
      if (words.length != columns) continue;
      if (words.every(
          (w) => w.length <= 24 && RegExp(r'^[A-ZÇĞİÖŞÜÂÎÛ]').hasMatch(w))) {
        return words;
      }
    }
    return null;
  }
}
