import 'package:flutter/painting.dart';

/// Türkçe satır sonu heceleme — TDK kuralları + soft hyphen (U+00AD).
///
/// Soft hyphen görünmezdir; yalnızca satır kırılınca `-` olarak çizilmelidir.
/// Flutter (3.44 ve öncesi) U+00AD noktasında satırı kırar ama tireyi
/// çizmez ([flutter#18443](https://github.com/flutter/flutter/issues/18443)).
/// [applyVisibleLineBreakHyphens] bu boşluğu doldurur.
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

  /// Soft hyphen ile kırılan satır sonlarına görünür `-` koyar.
  ///
  /// Flutter soft hyphen'i kırılma fırsatı sayar ama tireyi boyamaz.
  /// İlk ölçümde satır sonu sanılan soft hyphen'ler hard `-` yapıldığında
  /// metin yeniden akar ve tire satır ortasında kalabilir — bu yüzden
  /// ikinci (ve gerekirse üçüncü) geçişte satır sonunda olmayan
  /// hece tireleri budanır. Metindeki gerçek tireler (ör. `zarf-fiil`)
  /// yalnızca soft hyphen'den üretilen indeksler budandığı için korunur.
  static String applyVisibleLineBreakHyphens(
    String input, {
    required double maxWidth,
    required TextStyle style,
    TextAlign textAlign = TextAlign.start,
    TextDirection textDirection = TextDirection.ltr,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    if (input.isEmpty || maxWidth <= 0 || !input.contains(softHyphen)) {
      return input;
    }

    TextPainter painterFor(String text) => TextPainter(
          text: TextSpan(text: text, style: style),
          textAlign: textAlign,
          textDirection: textDirection,
          textScaler: textScaler,
        )..layout(maxWidth: maxWidth);

    final softCode = softHyphen.codeUnitAt(0);

    Set<int> softHyphensAtLineEnds(String text, TextPainter painter) {
      final breakAt = <int>{};
      var offset = 0;
      var guard = 0;
      while (offset < text.length && guard++ < text.length + 4) {
        final boundary = painter.getLineBoundary(TextPosition(offset: offset));
        final end = boundary.end;
        if (end <= offset) break;
        // Yalnızca satırın son karakteri soft hyphen ise — `end` konumundaki
        // soft hyphen (sonraki satır başı) false-positive üretir.
        if (end < text.length &&
            end > 0 &&
            text.codeUnitAt(end - 1) == softCode) {
          breakAt.add(end - 1);
        }
        offset = end;
      }
      return breakAt;
    }

    Set<int> hardHyphensAtLineEnds(
      String text,
      TextPainter painter,
      Set<int> candidates,
    ) {
      if (candidates.isEmpty) return {};
      final keep = <int>{};
      var offset = 0;
      var guard = 0;
      while (offset < text.length && guard++ < text.length + 4) {
        final boundary = painter.getLineBoundary(TextPosition(offset: offset));
        final end = boundary.end;
        if (end <= offset) break;
        if (end < text.length &&
            end > 0 &&
            text[end - 1] == '-' &&
            candidates.contains(end - 1)) {
          keep.add(end - 1);
        }
        offset = end;
      }
      return keep;
    }

    final initialBreaks = softHyphensAtLineEnds(input, painterFor(input));

    // Soft → hard (yalnızca aday satır sonları); diğer soft hyphen'ler silinir.
    final built = StringBuffer();
    var hardIdx = <int>{};
    for (var i = 0; i < input.length; i++) {
      if (input.codeUnitAt(i) == softCode) {
        if (initialBreaks.contains(i)) {
          hardIdx.add(built.length);
          built.write('-');
        }
      } else {
        built.write(input[i]);
      }
    }
    var out = built.toString();
    if (hardIdx.isEmpty) return out;

    // Reflow sonrası satır ortasında kalan hece tirelerini buda.
    for (var pass = 0; pass < 3; pass++) {
      final keep = hardHyphensAtLineEnds(out, painterFor(out), hardIdx);
      if (keep.length == hardIdx.length) break;

      final next = StringBuffer();
      final nextHard = <int>{};
      for (var i = 0; i < out.length; i++) {
        if (out[i] == '-' && hardIdx.contains(i) && !keep.contains(i)) {
          continue;
        }
        if (out[i] == '-' && hardIdx.contains(i)) {
          nextHard.add(next.length);
        }
        next.write(out[i]);
      }
      out = next.toString();
      hardIdx = nextHard;
      if (hardIdx.isEmpty) break;
    }

    return out;
  }

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
