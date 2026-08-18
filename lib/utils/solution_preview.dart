import 'dart:math' as math;

/// Çözüm metninin ücretsiz önizleme ve kilitli devam bölümleri.
class SolutionPreviewParts {
  final String preview;
  final String remainder;
  final bool hasLockedRemainder;

  const SolutionPreviewParts({
    required this.preview,
    required this.remainder,
    required this.hasLockedRemainder,
  });
}

/// İlk 1–2 cümleyi (ve güvenli karakter sınırını) ücretsiz gösterir.
SolutionPreviewParts splitSolutionPreview(
  String text, {
  int maxSentences = 2,
  int maxPreviewChars = 280,
  double maxPreviewFraction = 0.33,
}) {
  final normalized = text.replaceAll('\r\n', '\n').trim();
  if (normalized.isEmpty) {
    return const SolutionPreviewParts(
      preview: '',
      remainder: '',
      hasLockedRemainder: false,
    );
  }

  final sentences = _splitSentences(normalized);
  final sentencePreview = sentences.take(maxSentences).join(' ').trim();
  final charCap = math.min(
    maxPreviewChars,
    math.max(80, (normalized.length * maxPreviewFraction).round()),
  );

  var preview = sentencePreview;
  if (preview.length > charCap) {
    preview = _truncateAtWord(preview, charCap);
  }
  preview = _cutOutsideMath(normalized, preview);

  if (preview.length >= normalized.length) {
    if (normalized.length <= 120) {
      return SolutionPreviewParts(
        preview: normalized,
        remainder: '',
        hasLockedRemainder: false,
      );
    }
    preview = _truncateAtWord(normalized, math.max(80, charCap));
  }

  var start = normalized.indexOf(preview);
  if (start < 0) {
    preview = _truncateAtWord(normalized, charCap);
    start = 0;
  }
  var remainder = normalized.substring(start + preview.length).trimLeft();
  remainder = remainder.replaceFirst(RegExp(r'^[.!?…]\s*'), '');

  if (remainder.isEmpty) {
    return SolutionPreviewParts(
      preview: normalized,
      remainder: '',
      hasLockedRemainder: false,
    );
  }

  return SolutionPreviewParts(
    preview: preview.trim(),
    remainder: remainder,
    hasLockedRemainder: true,
  );
}

List<String> _splitSentences(String text) {
  final result = <String>[];
  final buffer = StringBuffer();
  var inInlineMath = false;
  var inDisplayMath = false;

  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    final nextCh = i + 1 < text.length ? text[i + 1] : '';
    if (ch == r'$') {
      if (nextCh == r'$') {
        inDisplayMath = !inDisplayMath;
        buffer.write(r'$$');
        i++;
        continue;
      }
      inInlineMath = !inInlineMath;
      buffer.write(ch);
      continue;
    }
    buffer.write(ch);
    if (inInlineMath || inDisplayMath) continue;
    if (ch == '.' || ch == '!' || ch == '?' || ch == '…') {
      final next = i + 1 < text.length ? text[i + 1] : ' ';
      if (next == ' ' || next == '\n' || i + 1 == text.length) {
        final sentence = buffer.toString().trim();
        if (sentence.isNotEmpty) result.add(sentence);
        buffer.clear();
      }
    }
  }

  final tail = buffer.toString().trim();
  if (tail.isNotEmpty) result.add(tail);
  return result;
}

String _truncateAtWord(String text, int maxChars) {
  if (text.length <= maxChars) return text;
  final slice = text.substring(0, maxChars);
  final lastSpace = slice.lastIndexOf(' ');
  final cut = lastSpace > maxChars ~/ 2
      ? slice.substring(0, lastSpace).trim()
      : slice.trim();
  return _cutOutsideMath(text, cut);
}

/// Önizlemeyi `$...$` / `$$...$$` ortasında kesmez; yarım LaTeX basılmaz.
String _cutOutsideMath(String source, String candidate) {
  if (candidate.isEmpty || source.isEmpty) return candidate;
  var end = 0;
  final limit = math.min(candidate.length, source.length);
  while (end < limit && source.codeUnitAt(end) == candidate.codeUnitAt(end)) {
    end++;
  }
  if (end == 0) return candidate;
  final span = _mathSpanContaining(source, end);
  if (span == null) {
    return source.substring(0, end).trimRight();
  }
  final (start, close) = span;
  final consumed = end - start;
  final spanLen = close - start;
  if (consumed * 2 >= spanLen) {
    return source.substring(0, close).trim();
  }
  final trimmed = source.substring(0, start).trimRight();
  if (trimmed.isEmpty) {
    return source.substring(0, close).trim();
  }
  return trimmed;
}

(int, int)? _mathSpanContaining(String text, int index) {
  var i = 0;
  while (i < text.length) {
    if (text.startsWith(r'$$', i)) {
      final close = text.indexOf(r'$$', i + 2);
      if (close < 0) {
        if (index > i) return (i, text.length);
        i += 2;
        continue;
      }
      final end = close + 2;
      if (index > i && index < end) return (i, end);
      i = end;
      continue;
    }
    if (text[i] == r'$') {
      final close = text.indexOf(r'$', i + 1);
      if (close < 0) {
        if (index > i) return (i, text.length);
        i++;
        continue;
      }
      final end = close + 1;
      if (index > i && index < end) return (i, end);
      i = end;
      continue;
    }
    i++;
  }
  return null;
}
