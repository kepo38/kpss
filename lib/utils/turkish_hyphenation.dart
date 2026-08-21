/// Türkçe satır sonu heceleme — TDK kuralları + soft hyphen (U+00AD).
///
/// Soft hyphen görünmezdir; yalnızca satır kırılınca `-` olarak çizilir.
///
/// Kurallar:
/// - Her hecede bir ünlü vardır; heceler bölünmez.
/// - İki ünlü arası 1 ünsüz → sonraki heceye (a-ra-ba).
/// - 2 ünsüz → ilki önceki, ikincisi sonraki heceye (An-ka-ra).
/// - 3 ünsüz → ilk ikisi önceki, üçüncüsü sonraki (Türk-çe, alt-lık).
/// - 4+ ünsüz → ilk ikisi önceki, son ikisi sonraki.
/// - Bitişik kelimeler tek sözcük gibi (ulama): ilkokul → il-ko-kul.
/// - Satır sonunda veya başında tek harf bırakılmaz (≥2 + ≥2).
class TurkishHyphenation {
  TurkishHyphenation._();

  static const softHyphen = '\u00AD';

  static const _vowels = 'aeıioöuüAEIİOÖUÜâêîôûÂÊÎÔÛ';

  static final _wordRe = RegExp(r"[A-Za-zÇĞİÖŞÜçğıöşüÂâÎîÛû]+");

  static bool _isVowel(String ch) => _vowels.contains(ch);

  /// [minWordLength] altındaki sözcüklere dokunulmaz (en az 4: 2+2 kuralı).
  ///
  /// `$…$` / `$$…$$` / `\(...\)` / `\[…\]` bölgelerine soft hyphen eklenmez;
  /// aksi halde `displaystyle` / `begin` / `array` gibi LaTeX komutları
  /// bozulur ve flutter_math ham metne düşer.
  static String hyphenate(String input, {int minWordLength = 4}) {
    if (input.isEmpty) return input;
    final holders = <String>[];
    final masked = input.replaceAllMapped(
      RegExp(r'\$\$[\s\S]+?\$\$|\$[^$\n]+\$|\\\([\s\S]+?\\\)|\\\[[\s\S]+?\\\]'),
      (m) {
        holders.add(m.group(0)!);
        return '§§H${holders.length - 1}§§';
      },
    );
    final hyphenated = masked.replaceAllMapped(_wordRe, (match) {
      final word = match.group(0)!;
      if (word.length < minWordLength) return word;
      // Zaten soft hyphen varsa yeniden işlemeyelim.
      if (word.contains(softHyphen)) return word;
      return _hyphenateWord(word);
    });
    if (holders.isEmpty) return hyphenated;
    return hyphenated.replaceAllMapped(RegExp(r'§§H(\d+)§§'), (m) {
      final i = int.tryParse(m.group(1)!) ?? -1;
      if (i < 0 || i >= holders.length) return m.group(0)!;
      return holders[i];
    });
  }

  /// Test / debug için: soft hyphen'leri `-` ile göster.
  static String visibleBreaks(String input) =>
      hyphenate(input).replaceAll(softHyphen, '-');

  static String _hyphenateWord(String word) {
    final breaks = _breakOffsets(word);
    if (breaks.isEmpty) return word;

    final out = StringBuffer();
    var cursor = 0;
    for (final b in breaks) {
      out.write(word.substring(cursor, b));
      out.write(softHyphen);
      cursor = b;
    }
    out.write(word.substring(cursor));
    return out.toString();
  }

  /// Soft hyphen'in ekleneceği indeksler (kırılma öncesi harf sayısı).
  static List<int> _breakOffsets(String word) {
    final vowelIdx = <int>[];
    for (var i = 0; i < word.length; i++) {
      if (_isVowel(word[i])) vowelIdx.add(i);
    }
    if (vowelIdx.length < 2) return const [];

    final raw = <int>[];
    for (var v = 0; v < vowelIdx.length - 1; v++) {
      final leftV = vowelIdx[v];
      final rightV = vowelIdx[v + 1];
      final cons = rightV - leftV - 1;

      // Kırılma noktası: sonraki hecenin ilk harfinin indeksi.
      late final int breakAt;
      if (cons == 0) {
        // sa-at → ikinci ünlünün başı
        breakAt = rightV;
      } else if (cons == 1) {
        // a-ra → ünsüz sonraki heceye
        breakAt = leftV + 1;
      } else if (cons == 2 || cons == 3) {
        // An-ka / Türk-çe → sonraki heceye 1 ünsüz
        breakAt = rightV - 1;
      } else {
        // 4+ → sonraki heceye son 2 ünsüz
        breakAt = rightV - 2;
      }

      // Satır sonunda/başında tek harf yok: her iki taraf ≥ 2.
      if (breakAt >= 2 && word.length - breakAt >= 2) {
        raw.add(breakAt);
      }
    }

    // Tekrarları temizle, sıralı tut.
    return raw.toSet().toList()..sort();
  }
}
