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

  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    buffer.write(ch);
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
  if (lastSpace > maxChars ~/ 2) {
    return '${slice.substring(0, lastSpace).trim()}…';
  }
  return '${slice.trim()}…';
}
