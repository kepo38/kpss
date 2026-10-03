import 'package:flutter/painting.dart';

/// Soft hyphen (U+00AD): Flutter satırı burada kırabilir ama tire ÇİZMEZ.
const int _kSoftHyphen = 0x00AD;

/// Hece tirelerinin (soft hyphen) sadece gerçekten satır sonuna düşenlerini
/// görünür `-` yapar; geri kalanını kaldırır.
///
/// Neden ayrı bir çözücü?
/// Görünür `-` eklemek satır kırılmasını değiştirir (tire genişliği). Bu yüzden
/// tek geçişli "ölç → dönüştür" yaklaşımı, dönüştürmeden sonra tire satır
/// ortasında kalabilir. Burada her soft hyphen üç durumdan birindedir:
///
///  * soft   – henüz karar verilmedi (görünmez, kırılabilir)
///  * dash   – görünür `-` (satır sonuna düşmeli)
///  * removed – hiç yok (kelime bütün kalır)
///
/// Durumlar tek yönlü ilerler (soft → dash → removed), bu yüzden döngü
/// mutlaka biter. Ölçüm, ekranda çizilecek TextSpan ağacının birebir
/// kopyasıyla yapılır (bold/italic/altı çizili parçalar, kök stil, yerel ayar,
/// yazı ölçeği dahil).
class LineBreakHyphens {
  const LineBreakHyphens._();

  static const int _stateSoft = 0;
  static const int _stateDash = 1;
  static const int _stateRemoved = 2;

  static const int _maxIterations = 24;

  /// [children] içindeki soft hyphen'leri çözer ve ekranda çizilecek yeni
  /// span listesini döner.
  ///
  /// [rootStyle] gerçek `RichText` kök stilidir (DefaultTextStyle + gerekiyorsa
  /// kalın metin ayarı ile birleşmiş hâli).
  static List<InlineSpan> resolve({
    required List<InlineSpan> children,
    required TextStyle rootStyle,
    required double maxWidth,
    required TextDirection textDirection,
    TextAlign textAlign = TextAlign.start,
    TextScaler textScaler = TextScaler.noScaling,
    Locale? locale,
    StrutStyle? strutStyle,
    TextHeightBehavior? textHeightBehavior,
    TextWidthBasis textWidthBasis = TextWidthBasis.parent,
  }) {
    final counter = _Counter();
    _count(children, counter);
    final n = counter.softCount;
    if (n == 0) return children;

    // Ölçemediğimiz durumlar: tireleri tamamen kaldır (güvenli).
    if (counter.hasPlaceholder || !maxWidth.isFinite || maxWidth <= 0) {
      return _rebuild(children, List<int>.filled(n, _stateRemoved)).spans;
    }

    List<int> measure(_Built built) {
      final painter = TextPainter(
        text: TextSpan(style: rootStyle, children: built.spans),
        textAlign: textAlign,
        textDirection: textDirection,
        textScaler: textScaler,
        locale: locale,
        strutStyle: strutStyle,
        textHeightBehavior: textHeightBehavior,
        textWidthBasis: textWidthBasis,
      );
      try {
        painter.layout(maxWidth: maxWidth);
        return _lineEnds(painter, built.length);
      } finally {
        painter.dispose();
      }
    }

    final states = List<int>.filled(n, _stateSoft);

    for (var iter = 0; iter < _maxIterations; iter++) {
      final built = _rebuild(children, states);
      final lineEnds = measure(built);
      final atLineEnd = <int>{for (final e in lineEnds) e - 1};

      var changed = false;
      built.offsetToIndex.forEach((offset, k) {
        final isEnd = atLineEnd.contains(offset);
        if (states[k] == _stateSoft && isEnd) {
          states[k] = _stateDash;
          changed = true;
        } else if (states[k] == _stateDash && !isEnd) {
          states[k] = _stateRemoved;
          changed = true;
        }
      });
      if (changed) continue;

      // Yakınsadı. Kullanılmayan soft hyphen'leri de kaldır (erişilebilirlik /
      // kopyalama için temiz metin); kırılma değişmiyorsa bunu kullan.
      final stripped = [
        for (final s in states) s == _stateSoft ? _stateRemoved : s,
      ];
      final cleaned = _rebuild(children, stripped);
      final cleanedEnds = measure(cleaned);
      if (_sameEnds(cleanedEnds, lineEnds, built, cleaned)) {
        return cleaned.spans;
      }
      return built.spans;
    }

    // Yakınsamadı (beklenmez): kelimeleri bölmeden bırak.
    return _rebuild(children, List<int>.filled(n, _stateRemoved)).spans;
  }

  /// Temizlenmiş ve ham ağacın satır sonlarının aynı metin konumlarına
  /// düştüğünü (soft hyphen sayısı farkı düzeltilerek) doğrular.
  static bool _sameEnds(
    List<int> cleanedEnds,
    List<int> rawEnds,
    _Built raw,
    _Built cleaned,
  ) {
    if (cleanedEnds.length != rawEnds.length) return false;
    // raw'daki her ofseti, silinen soft hyphen sayısı kadar geri kaydır.
    final removedBefore = raw.softOffsets;
    int shift(int end) {
      var d = 0;
      for (final o in removedBefore) {
        if (o < end) d++;
      }
      return end - d;
    }

    for (var i = 0; i < rawEnds.length; i++) {
      if (shift(rawEnds[i]) != cleanedEnds[i]) return false;
    }
    return true;
  }
  /// Kırılan her satırın son karakter ofsetlerini (bitiş - 1 mantığıyla
  /// kullanılmak üzere "bitiş" olarak) döner. Son satır dahil değildir.
  static List<int> _lineEnds(TextPainter painter, int length) {
    final ends = <int>[];
    var offset = 0;
    var guard = 0;
    while (offset < length && guard++ <= length + 2) {
      final range = painter.getLineBoundary(TextPosition(offset: offset));
      var end = range.end;
      if (end <= offset) break;
      if (end >= length) break; // son satır
      // Satır sonundaki boşluklar tireden sonra gelmez; yine de güvenli ol.
      ends.add(end);
      offset = end;
    }
    return ends;
  }

  static void _count(List<InlineSpan> spans, _Counter c) {
    for (final s in spans) {
      if (s is TextSpan) {
        final t = s.text;
        if (t != null) {
          for (var i = 0; i < t.length; i++) {
            if (t.codeUnitAt(i) == _kSoftHyphen) c.softCount++;
          }
        }
        final kids = s.children;
        if (kids != null) _count(kids, c);
      } else {
        c.hasPlaceholder = true;
      }
    }
  }

  static _Built _rebuild(List<InlineSpan> spans, List<int> states) {
    final b = _Built();
    var k = 0;

    List<InlineSpan> walk(List<InlineSpan> input) {
      final out = <InlineSpan>[];
      for (final s in input) {
        if (s is TextSpan) {
          String? newText;
          final t = s.text;
          if (t != null) {
            final sb = StringBuffer();
            for (var i = 0; i < t.length; i++) {
              final cu = t.codeUnitAt(i);
              if (cu != _kSoftHyphen) {
                sb.writeCharCode(cu);
                b.plainBuf.writeCharCode(cu);
                b.length++;
                continue;
              }
              final idx = k++;
              final st = idx < states.length ? states[idx] : _stateRemoved;
              if (st == _stateRemoved) continue;
              final ch = st == _stateDash ? '-' : '\u00AD';
              b.offsetToIndex[b.length] = idx;
              if (st == _stateSoft) b.softOffsets.add(b.length);
              sb.write(ch);
              b.plainBuf.write(ch);
              b.length++;
            }
            newText = sb.toString();
          }
          final kids = s.children;
          out.add(
            TextSpan(
              text: newText,
              children: kids == null ? null : walk(kids),
              style: s.style,
              recognizer: s.recognizer,
              mouseCursor: s.mouseCursor,
              onEnter: s.onEnter,
              onExit: s.onExit,
              semanticsLabel: s.semanticsLabel,
              locale: s.locale,
              spellOut: s.spellOut,
            ),
          );
        } else {
          out.add(s);
        }
      }
      return out;
    }

    b.spans = walk(spans);
    return b;
  }
}

class _Counter {
  int softCount = 0;
  bool hasPlaceholder = false;
}

class _Built {
  List<InlineSpan> spans = const [];
  final StringBuffer plainBuf = StringBuffer();
  int length = 0;
  final Map<int, int> offsetToIndex = <int, int>{};
  /// Bu ağaçta hâlâ soft (görünmez) duran hece işaretlerinin ofsetleri.
  final List<int> softOffsets = <int>[];
  String get plain => plainBuf.toString();
}
