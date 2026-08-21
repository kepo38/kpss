/// Türkçe satır kaydırma için yumuşak tire (U+00AD) ekler.
///
/// Soft hyphen görünmezdir; yalnızca satır kırılınca `-` olarak çizilir.
/// Basit hece sezgiseli: ünlüden sonra, kalan kök yeterince uzunsa ve sonraki
/// harf ünsüzse kırılma noktası bırakılır (yaygın TR CV/VC deseni).
class TurkishHyphenation {
  TurkishHyphenation._();

  static const softHyphen = '\u00AD';

  static const _vowels = 'aeıioöuüAEIİOÖUÜ';

  static final _wordRe = RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşüÂâÎîÛû]+');

  static bool _isVowel(String ch) => _vowels.contains(ch);

  /// [minWordLength] altındaki sözcüklere dokunulmaz.
  static String hyphenate(String input, {int minWordLength = 6}) {
    if (input.isEmpty) return input;
    return input.replaceAllMapped(_wordRe, (match) {
      final word = match.group(0)!;
      if (word.length < minWordLength) return word;
      return _hyphenateWord(word);
    });
  }

  static String _hyphenateWord(String word) {
    final out = StringBuffer();
    for (var i = 0; i < word.length; i++) {
      out.write(word[i]);
      final remaining = word.length - i - 1;
      if (remaining < 2) continue;
      if (!_isVowel(word[i])) continue;
      if (_isVowel(word[i + 1])) continue;
      // Ünlü + ünsüz … → ünlüden sonra soft hyphen (An-ka-ra, yönet-melik).
      out.write(softHyphen);
    }
    return out.toString();
  }
}
