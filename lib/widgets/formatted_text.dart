import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../theme/exam_typography.dart';

/// Markdown + LaTeX: **kalın**, *italik*, __altı çizili__, {green}renk{/green}, $...$ / $$...$$.
/// Panel ile uyumlu paragraf düzeni ve HTML etiket yedek desteği.
class FormattedText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final bool preserveLineBreaks;
  final bool paragraphLayout;
  final bool forceDisplayMath;

  /// ÖSYM sınav düzeni: tüm satırlar aynı punto, kalın yalnızca **…** ile.
  final bool examLayout;

  /// false → metin/formül sabit punto; taşan satır yatay kayar (çözüm metni).
  final bool examScaleDown;

  /// true → metin satırları softWrap (panel gibi); FittedBox yok.
  final bool examWrap;

  /// true → çözüm metni pipeline'ı (Google yapıştırma, madde listesi).
  final bool solutionMode;

  const FormattedText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.preserveLineBreaks = false,
    this.paragraphLayout = false,
    this.forceDisplayMath = false,
    this.examLayout = false,
    this.examScaleDown = true,
    this.examWrap = false,
    this.solutionMode = false,
  });

  static bool _isStructuralLine(String line) {
    final t = line.trim();
    if (t.isEmpty) return false;
    return RegExp(
          r'^(?:#{1,3}\s+|[-•*◦○–—]\s+|(?:I|II|III|IV|V|VI|VII|VIII|IX|X)\.\s+|\*\*|---|\*\*\*|___)',
        ).hasMatch(t);
  }

  static String examFormat(String input) {
    if (input.isEmpty) return input;

    final buffer = StringBuffer();
    final displayRe = RegExp(r'\$\$[\s\S]+?\$\$');
    var cursor = 0;

    void appendFormattedText(String chunk) {
      if (chunk.trim().isEmpty) return;
      final blocks = chunk
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n')
          .split(RegExp(r'\n\s*\n+'));
      for (final block in blocks) {
        final kept = <String>[];
        final buf = StringBuffer();
        void flushSoft() {
          final t = buf
              .toString()
              .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
              .trim();
          if (t.isNotEmpty) kept.add(t);
          buf.clear();
        }

        for (final raw in block.split('\n')) {
          final line = raw.trim();
          if (line.isEmpty) continue;
          if (_isStructuralLine(line)) {
            flushSoft();
            kept.add(line);
          } else {
            if (buf.isNotEmpty) buf.write(' ');
            buf.write(line);
          }
        }
        flushSoft();
        for (final p in kept) {
          if (buffer.isNotEmpty) buffer.write('\n\n');
          buffer.write(p);
        }
      }
    }

    for (final m in displayRe.allMatches(input)) {
      appendFormattedText(input.substring(cursor, m.start));
      if (buffer.isNotEmpty) buffer.write('\n\n');
      buffer.write(m.group(0)!);
      cursor = m.end;
    }
    appendFormattedText(input.substring(cursor));

    return buffer.toString();
  }

  /// Soru gövdesi justify için: soft satır kırılımlarını boşluğa çevirir,
  /// çoklu whitespace'i tek boşluğa indirger; `$$…$$` ve madde satırları korunur.
  static String prepareExamJustifyText(String input) {
    if (input.isEmpty) return input;
    return examFormat(normalizeMarkup(joinOrphanRomanNumeralLines(input)))
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .trim();
  }

  /// `I.Fidan,` gibi yapışık Romen etiketlerini `I. Fidan,` biçimine çevirir.
  static String glueRomanNumeralLabels(String input) {
    if (input.isEmpty) return input;
    return input.replaceAllMapped(
      RegExp(r'\b(I|II|III|IV|V|VI|VII|VIII|IX|X)\.(?=[A-ZÇĞİÖŞÜÂÎÛ])'),
      (m) => '${m.group(1)!}. ',
    );
  }

  /// OCR'da ayrı satıra düşen `I.` + `Fidan,` gibi Romen madde parçalarını birleştirir.
  static String joinOrphanRomanNumeralLines(String input) {
    if (input.isEmpty) return input;
    final lines = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    final out = <String>[];
    final orphanRoman = RegExp(r'^(I|II|III|IV|V|VI|VII|VIII|IX|X)\.\s*$');

    for (var i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trim();
      if (orphanRoman.hasMatch(trimmed) && i + 1 < lines.length) {
        final next = lines[i + 1].trim();
        if (next.isNotEmpty &&
            !orphanRoman.hasMatch(next) &&
            !RegExp(r'^(?:I|II|III|IV|V|VI|VII|VIII|IX|X)\.\s')
                .hasMatch(next)) {
          out.add('$trimmed $next');
          i += 1;
          continue;
        }
      }
      out.add(lines[i]);
    }
    return out.join('\n');
  }

  static bool usesDisplayMath(String tex) {
    final t = tex;
    return t.contains(r'\frac') ||
        t.contains(r'\dfrac') ||
        t.contains(r'\tfrac') ||
        t.contains(r'\displaystyle') ||
        RegExp(r'\\over(?![a-zA-Z])').hasMatch(t) ||
        t.contains(r'\sqrt') ||
        t.contains(r'\left') ||
        t.contains(r'\sum') ||
        t.contains(r'\int') ||
        t.contains(r'\begin{') ||
        t.contains(r'\hline');
  }

  /// Tam denklem (`=`, dizi, toplam). Basit `x/y` kesiri cümlede kalır.
  static bool isStandaloneDisplayEquation(String tex) {
    final t = tex.trim();
    if (t.isEmpty) return false;
    if (t.contains(r'\begin{') ||
        t.contains(r'\sum') ||
        t.contains(r'\int') ||
        t.contains(r'\hline')) {
      return true;
    }
    // `$x = 5$` cümlede kalsın; kök/kesirli denklem ayrı satır olsun.
    return t.contains('=') && usesDisplayMath(t);
  }

  static TextStyle mathTextStyle(TextStyle base, {required bool display}) {
    final size = base.fontSize ?? 16;
    return ExamTypography.mathFrom(
      base.copyWith(
        // x, y, z ve diğer harfler gövde ile aynı punto.
        fontSize: size,
        height: display ? 1.35 : base.height,
        color: base.color,
        fontStyle: FontStyle.normal,
      ),
    );
  }

  /// Soru kökü / şık: satır yüksekliği alt/üst indeksleri kesmesin.
  static const TextHeightBehavior examTextHeightBehavior = TextHeightBehavior(
    applyHeightToFirstAscent: true,
    applyHeightToLastDescent: true,
  );

  static StrutStyle examStrutStyle(TextStyle base) {
    final size = base.fontSize ?? 16;
    final lineHeight = base.height ?? 1.35;
    return StrutStyle(
      fontFamily: base.fontFamily,
      fontFamilyFallback: base.fontFamilyFallback,
      fontSize: size,
      height: lineHeight * 1.12,
      forceStrutHeight: true,
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  /// Çözüm outline pipeline'ı soru/şık metnine uygulanmaz.
  static String prepareExamDisplayText(String input) {
    if (input.isEmpty) return input;
    return normalizeLatex(
      examFormat(normalizeMarkup(joinOrphanRomanNumeralLines(input))),
    );
  }

  /// Tek harfli değişken ($x$, $y$, $z$…) → Math değil gövde TextSpan.
  static final RegExp _plainMathLetterRe = RegExp(
    r'^[A-Za-zÇçĞğİıÖöŞşÜü]$',
  );

  static bool isPlainMathLetter(String tex) =>
      _plainMathLetterRe.hasMatch(tex.trim());

  static String _uprightBareLetters(String s) {
    return s.replaceAllMapped(
      RegExp(r'[A-Za-zÇçĞğİıÖöŞşÜü]'),
      (m) => '\\mathrm{${m.group(0)}}',
    );
  }

  static String _wrapLettersUpright(String s) {
    final holders = <String>[];
    String hold(String raw) {
      holders.add(raw);
      return '§§@${holders.length - 1}@§§';
    }

    var t = s.replaceAllMapped(
      RegExp(r'\\mathrm\{[^{}]*\}'),
      (m) => hold(m.group(0)!),
    );
    t = _uprightBareLetters(t);
    return _expandHolders(t, holders, r'§§@(\d+)@§§');
  }

  /// Latin / Türkçe harfleri dik (\mathrm). Array/matrix ortamlarına dokunma.
  static String uprightMathLetters(String tex) {
    if (tex.isEmpty) return tex;
    // array/matrix sütun spec ve hücreleri bozulmasın.
    if (RegExp(r'\\begin\{').hasMatch(tex)) return tex;

    final holders = <String>[];
    // Placeholder'da Latin harf OLMAMALI: aksi halde aşağıdaki
    // \mathrm sarmalayıcı placeholder içindeki harfi bozup expand'i kırar →
    // ekranda §§ sızıntısı (örn. \cdot yerine).
    String hold(String raw) {
      holders.add(raw);
      return '§§#${holders.length - 1}#§§';
    }

    var t = tex;

    // \text{…} / \mathrm{…} içeriğine dokunma.
    t = t.replaceAllMapped(
      RegExp(r'\\(?:text|mathrm|mathbf)\*?(?:\[[^\]]*\])?\{[^{}]*\}'),
      (m) => hold(m.group(0)!),
    );

    t = t.replaceAllMapped(RegExp(r'\\[a-zA-Z]+\*?'), (m) => hold(m.group(0)!));

    // Basit {4xy}, {a} gruplarında harfleri dik yap; `\mathrm{…}` iç {x} eşleşmesin.
    for (var pass = 0; pass < 12 && t.contains('{'); pass++) {
      t = t.replaceAllMapped(
        RegExp(r'\\mathrm\{[^{}]*\}'),
        (m) => hold(m.group(0)!),
      );

      var changed = false;
      t = t.replaceAllMapped(RegExp(r'\{([^{}]*)\}'), (m) {
        final inner = m.group(1)!;
        if (inner.contains('\\')) {
          changed = true;
          return hold(m.group(0)!);
        }
        if (RegExp(r'^[clr]$').hasMatch(inner)) {
          return m.group(0)!;
        }
        final upright = _uprightBareLetters(inner);
        if (upright == inner) return m.group(0)!;
        changed = true;
        final wrapped = '{$upright}';
        return hold(wrapped);
      });
      if (!changed) break;
    }

    t = _wrapLettersUpright(t);
    t = _expandHolders(t, holders, r'§§#(\d+)#§§');

    return t;
  }

  /// İç içe placeholder'ları tamamen aç (tek geçişte içtekiler kaçmasın).
  static String _expandHolders(
    String src,
    List<String> holders,
    String pattern,
  ) {
    if (holders.isEmpty) return src;
    final re = RegExp(pattern);
    var out = src;
    for (var guard = 0; guard < holders.length + 4; guard++) {
      if (!re.hasMatch(out)) break;
      out = out.replaceAllMapped(re, (m) {
        final i = int.tryParse(m.group(1)!) ?? -1;
        if (i < 0 || i >= holders.length) return m.group(0)!;
        return holders[i];
      });
    }
    return out;
  }

  /// flutter_math_fork \\hline siyah çizer; \\rule metin rengini kullanır.
  static String replaceHlineWithColoredRule(String tex) {
    if (!tex.contains(r'\hline')) return tex;
    var t = tex;
    t = t.replaceAllMapped(
      RegExp(r'\\\\\s*\\hline\s*'),
      (_) => r'\\ \rule{5em}{0.05em} \\ ',
    );
    t = t.replaceAllMapped(
      RegExp(r'(?<!\\begin\{[^}]*\})\s*\\hline\s*(?=\\\\|\\end)'),
      (_) => r'\rule{5em}{0.05em} \\ ',
    );
    return t;
  }

  static Widget buildMathWidget(
    String tex, {
    required TextStyle base,
    required bool display,
  }) {
    // Kesir/kök cümle içinde de gövde puntosunda kalsın (\dfrac + display).
    final fullSize = display || usesDisplayMath(tex);
    final sized = prepareTex(tex, forceDisplayStyle: fullSize);
    final upright = uprightMathLetters(sized);
    return Math.tex(
      upright,
      textStyle: mathTextStyle(base, display: fullSize),
      mathStyle: fullSize ? MathStyle.display : MathStyle.text,
      onErrorFallback: (err) => Text(
        display ? '\$\$$tex\$\$' : '\$$tex\$',
        style: base,
      ),
    );
  }

  static String _decodeEntities(String input) {
    return input
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAllMapped(
          RegExp(r'&#(\d+);'),
          (m) {
            final code = int.tryParse(m.group(1)!);
            if (code == null) return m.group(0)!;
            return String.fromCharCode(code);
          },
        )
        .replaceAllMapped(
          RegExp(r'&#x([0-9a-fA-F]+);'),
          (m) {
            final code = int.tryParse(m.group(1)!, radix: 16);
            if (code == null) return m.group(0)!;
            return String.fromCharCode(code);
          },
        );
  }

  static String _replaceHtmlTag(String text, String tag, String marker) {
    final re = RegExp(
      '<$tag\\b[^>]*>([\\s\\S]*?)</$tag\\s*>',
      caseSensitive: false,
    );
    return text.replaceAllMapped(re, (m) {
      final raw = m.group(1) ?? '';
      final lead = RegExp(r'^[ \t]+').firstMatch(raw)?.group(0) ?? '';
      final trail = RegExp(r'[ \t]+$').firstMatch(raw)?.group(0) ?? '';
      final inner = raw.substring(lead.length, raw.length - trail.length);
      if (inner.isEmpty) return raw;
      return '$lead$marker$inner$marker$trail';
    });
  }

  static const Color _greenText = Color(0xFF4ADE80);
  static const Color _redText = Color(0xFFF87171);
  static const Color _blueText = Color(0xFF60A5FA);

  static String? _namedColor(String raw) {
    final value = raw.trim().toLowerCase();
    if (RegExp(r'^(#22c55e|#16a34a|#4ade80|#34d399|green|lime|yeşil|yesil)\b')
        .hasMatch(value)) {
      return 'green';
    }
    if (RegExp(r'^(#ef4444|#dc2626|#f87171|#fb7185|red|kırmızı|kirmizi)\b')
        .hasMatch(value)) {
      return 'red';
    }
    if (RegExp(r'^(#3b82f6|#2563eb|#60a5fa|#38bdf8|blue|mavi)\b').hasMatch(value)) {
      return 'blue';
    }
    return null;
  }

  static String _wrapColor(String inner, String color) {
    final core = inner.trim();
    if (core.isEmpty) return '';
    return '{$color}$core{/$color}';
  }

  static String _wrapMd(String inner, {bool bold = false, bool italic = false, bool underline = false}) {
    final raw = inner;
    final lead = RegExp(r'^[ \t]+').firstMatch(raw)?.group(0) ?? '';
    final trail = RegExp(r'[ \t]+$').firstMatch(raw)?.group(0) ?? '';
    var core = raw.substring(lead.length, raw.length - trail.length).trim();
    if (core.isEmpty) return raw;
    if (bold && italic) {
      core = '***$core***';
    } else if (bold) {
      core = '**$core**';
    } else if (italic) {
      core = '*$core*';
    }
    if (underline) core = '__${core}__';
    return '$lead$core$trail';
  }

  static String _convertStyledSpans(String text) {
    final re = RegExp(
      r'''<span\b([^>]*)>([\s\S]*?)</span\s*>''',
      caseSensitive: false,
    );
    var current = text;
    for (var i = 0; i < 8; i++) {
      final next = current.replaceAllMapped(re, (m) {
        final attrs = m.group(1) ?? '';
        final inner = (m.group(2) ?? '').trim();
        if (inner.isEmpty) return '';
        final style = RegExp(
              r'''style\s*=\s*["']([^"']*)["']''',
              caseSensitive: false,
            ).firstMatch(attrs)?.group(1)?.toLowerCase() ??
            '';
        final cls = RegExp(
              r'''class\s*=\s*["']([^"']*)["']''',
              caseSensitive: false,
            ).firstMatch(attrs)?.group(1)?.toLowerCase() ??
            '';
        final bold = RegExp(r'font-weight\s*:\s*(bold|[7-9]00)').hasMatch(style) ||
            cls.contains('bold') ||
            cls.contains('strong');
        final italic =
            RegExp(r'font-style\s*:\s*italic').hasMatch(style) ||
            cls.contains('italic') ||
            cls.contains('emphasis');
        final underline =
            RegExp(r'text-decoration\s*:[^;]*underline').hasMatch(style) ||
            cls.contains('underline');
        final colorName = _namedColor(
          RegExp(r'color\s*:\s*([^;]+)', caseSensitive: false)
                  .firstMatch(style)
                  ?.group(1) ??
              '',
        );
        var converted = inner;
        if (bold || italic || underline) {
          converted = _wrapMd(inner, bold: bold, italic: italic, underline: underline);
        }
        if (colorName != null) {
          return _wrapColor(converted, colorName);
        }
        if (!bold && !italic && !underline) return inner;
        return converted;
      });
      if (next == current) break;
      current = next;
    }
    return current;
  }

  /// `** metin **` / `__ metin __` — iç boşluğu dışarı taşı (yutma).
  static String _tightenMarkdownMarkers(String text) {
    var t = text;
    var prev = '';
    String peel(String open, String close, String full, String inner) {
      final lead = RegExp('^${RegExp.escape(open)}([ \\t]+)')
              .firstMatch(full)
              ?.group(1) ??
          '';
      final trail = RegExp('([ \\t]+)${RegExp.escape(close)}\$')
              .firstMatch(full)
              ?.group(1) ??
          '';
      if (inner.contains('\n')) {
        return '$lead$open$inner$close$trail';
      }
      return '$lead$open${inner.trim()}$close$trail';
    }

    while (prev != t) {
      prev = t;
      t = t.replaceAllMapped(
        RegExp(r'\*\*__\*\*([^*]+)\*\*__\*\*', dotAll: true),
        (m) => '**__${m.group(1)!.trim()}__**',
      );
      t = t.replaceAllMapped(
        RegExp(r'__\*\*__([^_]+)__\*\*__', dotAll: true),
        (m) => '__**${m.group(1)!.trim()}**__',
      );
      t = t.replaceAllMapped(
        RegExp(r'\*\*\s*\*\*([^*]+)\*\*\s*\*\*', dotAll: true),
        (m) => '**${m.group(1)!.trim()}**',
      );
      t = t.replaceAllMapped(
        RegExp(r'__\s*__([^_]+)__\s*__', dotAll: true),
        (m) => '__${m.group(1)!.trim()}__',
      );
      t = t.replaceAllMapped(
        RegExp(r'\*{4,}([^*\n]+)\*{4,}'),
        (m) => '**${m.group(1)!.trim()}**',
      );
      t = t.replaceAllMapped(
        RegExp(r'_{4,}([^_\n]+)_{4,}'),
        (m) => '__${m.group(1)!.trim()}__',
      );
    }
    t = t.replaceAllMapped(
      RegExp(r'\*\*[ \t]+(.+?)[ \t]+\*\*', dotAll: true),
      (m) => peel('**', '**', m.group(0)!, m.group(1)!),
    );
    t = t.replaceAllMapped(
      RegExp(r'__[ \t]+(.+?)[ \t]+__', dotAll: true),
      (m) => peel('__', '__', m.group(0)!, m.group(1)!),
    );
    t = t.replaceAllMapped(
      RegExp(r'(?<!\*)\*[ \t]+(.+?)[ \t]+\*(?!\*)', dotAll: true),
      (m) => peel('*', '*', m.group(0)!, m.group(1)!),
    );
    t = t.replaceAllMapped(
      RegExp(r'\*\*(.+?)[ \t]+\*\*', dotAll: true),
      (m) => peel('**', '**', m.group(0)!, m.group(1)!),
    );
    t = t.replaceAllMapped(
      RegExp(r'__(.+?)[ \t]+__', dotAll: true),
      (m) => peel('__', '__', m.group(0)!, m.group(1)!),
    );
    return t;
  }

  /// Harf/`**` bitişikse araya boşluk koy (span DIŞI; içerik dokunulmaz).
  static String _ensureMarkdownExteriorSpaces(String text) {
    if (text.isEmpty) return text;
    var src = text;
    final holders = <String>[];
    String hold(String raw) {
      holders.add(raw);
      return '§§E${holders.length - 1}§§';
    }

    // Math ve markdown span'larını koru; boşluk yalnızca dışarıda eklenir.
    src = src.replaceAllMapped(
      RegExp(r'\$\$[\s\S]+?\$\$|\$[^$\n]+\$'),
      (m) => hold(m.group(0)!),
    );
    src = src.replaceAllMapped(
      RegExp(r'\*\*[\s\S]+?\*\*|__[\s\S]+?__|(?<!\*)\*(?!\*)[^*\n]+?(?<!\*)\*(?!\*)'),
      (m) => hold(m.group(0)!),
    );

    const letter =
        r"0-9A-Za-zÀ-ÖØ-öø-ÿĀ-ſĞğİıŞşÜüÇç";
    // letter + placeholder / placeholder + letter
    src = src.replaceAllMapped(
      RegExp('([$letter\'’])(§§E\\d+§§)'),
      (m) => '${m.group(1)} ${m.group(2)}',
    );
    src = src.replaceAllMapped(
      RegExp('(§§E\\d+§§)([$letter])'),
      (m) => '${m.group(1)} ${m.group(2)}',
    );

    return _expandHolders(src, holders, r'§§E(\d+)§§');
  }

  static String _repairSplitBoldLines(String text) {
    return text.replaceAllMapped(
      RegExp(r'\*\*([^\n*][^\n]*?)\n\s+([^\n*][^\n]*?)\*\*'),
      (m) => '**${m.group(1)}${m.group(2)}**',
    );
  }

  static String normalizeMarkup(String input) {
    if (input.isEmpty) return input;
    var text = _decodeEntities(input)
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        // Görünmez / tam genişlik biçim karakterlerini temizle
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
        .replaceAll('＊', '*')
        .replaceAll('＿', '_')
        .replaceAll(RegExp(r'\$\\(?:long)?rightarrow\$'), '→')
        .replaceAll(r'$\to$', '→')
        .replaceAllMapped(
          RegExp(r'[ \t]*->[ \t]*'),
          (_) => ' → ',
        )
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<p\b[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'</div\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<div\b[^>]*>', caseSensitive: false), '');

    // Kalın + altı çizili birlikte (özellikli etiketler dahil)
    text = text.replaceAllMapped(
      RegExp(
        r'''<strong\b[^>]*>\s*<u\b[^>]*>([\s\S]*?)</u\s*>\s*</strong\s*>|<u\b[^>]*>\s*<strong\b[^>]*>([\s\S]*?)</strong\s*>\s*</u\s*>|<b\b[^>]*>\s*<u\b[^>]*>([\s\S]*?)</u\s*>\s*</b\s*>|<u\b[^>]*>\s*<b\b[^>]*>([\s\S]*?)</b\s*>\s*</u\s*>''',
        caseSensitive: false,
      ),
      (m) {
        final inner =
            (m.group(1) ?? m.group(2) ?? m.group(3) ?? m.group(4) ?? '').trim();
        return inner.isEmpty ? '' : '__**${inner}**__';
      },
    );

    text = _replaceHtmlTag(text, 'strong', '**');
    text = _replaceHtmlTag(text, 'b', '**');
    text = _replaceHtmlTag(text, 'em', '*');
    text = _replaceHtmlTag(text, 'i', '*');
    text = _replaceHtmlTag(text, 'u', '__');
    text = _convertStyledSpans(text);

    // Dönüştürülemeyen HTML etiketlerini kaldır (metni düz bırakma)
    text = text.replaceAll(RegExp(r'</?[a-zA-Z][^>]*>'), '');
    text = _tightenMarkdownMarkers(text);
    text = _ensureMarkdownExteriorSpaces(text);
    text = _repairSplitBoldLines(text);
    // Sınav metninde otomatik negatif/pozitif renk yok.
    text = text.replaceAll(RegExp(r'^\s*\*\*\s*$', multiLine: true), '');
    text = text.replaceAll(RegExp(r'^\s*__\s*$', multiLine: true), '');

    return text;
  }

  /// Eski API uyumu — sınav gövdesinde işaret rengi uygulanmaz.
  static String emphasizeSignWords(String input) => input;

  static String stripMarkup(String input) {
    var text = normalizeMarkup(input);
    for (final pattern in [
      RegExp(r'\{green\}([\s\S]+?)\{/green\}', caseSensitive: false),
      RegExp(r'\{red\}([\s\S]+?)\{/red\}', caseSensitive: false),
      RegExp(r'\{blue\}([\s\S]+?)\{/blue\}', caseSensitive: false),
      RegExp(r'\*\*\*(.+?)\*\*\*', dotAll: true),
      RegExp(r'\*\*(.+?)\*\*', dotAll: true),
      RegExp(r'__(.+?)__', dotAll: true),
      RegExp(r'(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)', dotAll: true),
    ]) {
      text = text.replaceAllMapped(pattern, (m) => m.group(1) ?? '');
    }
    return text;
  }

  static String _repairLatexEscapes(String text) {
    if (text.isEmpty) return text;
    var out = repairGoogleDocsVertBars(text)
        .replaceAll('\x0crac', r'\frac')
        .replaceAll('\x08eta', r'\beta')
        .replaceAll('\x08egin', r'\begin')
        .replaceAll('\x09ext{', r'\text{')
        .replaceAll('\x09imes', r'\times')
        .replaceAll('\x09heta', r'\theta')
        .replaceAll('\x09an', r'\tan')
        .replaceAll('\x0dight', r'\right')
        .replaceAll('\x0aeq', r'\neq')
        .replaceAll(r'$rac{', r'$\frac{')
        .replaceAll(r'$sqrt{', r'$\sqrt{');
    out = out.replaceAllMapped(
      RegExp(r'\\vert\s*\{([^{}]*?)\\vert(?:\{\})?\}'),
      (m) {
        final inner = m.group(1)!.trim();
        return inner.isEmpty ? r'\vert' : '\\lvert $inner \\rvert';
      },
    );
    if (out.contains('frac') && !out.contains(r'\frac')) {
      out = out.replaceAllMapped(
        RegExp(r'(^|[^\\A-Za-z])frac\{'),
        (m) => '${m.group(1)}\\frac{',
      );
    }
    return out;
  }

  /// Google Docs / Telegram `\(\vert{}-3\vert{}\)` → `\lvert -3 \rvert`.
  static String repairGoogleDocsVertBars(String input) {
    if (input.isEmpty) return input;
    var out = input
        .replaceAllMapped(
          RegExp(r'\\\(\s*\\vert\{\}\s*\\\)'),
          (_) => '|',
        )
        .replaceAll('(\\vert{})', '|');

    out = out.replaceAllMapped(
      RegExp(r'\\vert\{\}([^\\]*?)\\vert\{\}'),
      (m) {
        final inner = m.group(1)!.trim();
        if (inner.isEmpty) return r'\vert';
        return '\\lvert $inner \\rvert';
      },
    );
    return out;
  }

  static String mergeSplitInlineDollarMath(String input) {
    if (input.isEmpty) return input;
    var src = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final display = <String>[];
    src = src.replaceAllMapped(RegExp(r'\$\$[\s\S]+?\$\$'), (m) {
      display.add(m.group(0)!);
      return '§§D${display.length - 1}§§';
    });
    var prev = '';
    while (prev != src) {
      prev = src;
      src = src.replaceAllMapped(
        RegExp(r'\$([^$\n]*)\n(\s*[^$\n]+)\$'),
        (m) {
          final a = m.group(1)!.trim();
          final b = m.group(2)!.trim();
          if (a.isEmpty) return '\$$b\$';
          return '\$$a $b\$';
        },
      );
    }
    src = src.replaceAllMapped(RegExp(r'§§D(\d+)§§'), (m) {
      return display[int.parse(m.group(1)!)];
    });
    return src;
  }

  /// Çözüm metni — markup + LaTeX + satır kırılımları (madde yapısı hariç).
  static String normalizeForSolutionDisplay(String input) {
    if (input.isEmpty) return input;
    var text = normalizeMarkup(joinOrphanRomanNumeralLines(input));
    text = mergeSplitInlineDollarMath(text);
    text = normalizeLatex(text);
    return restoreCollapsedBreaks(text);
  }

  /// Tam çözüm pipeline (panel + uygulama).
  static String prepareSolutionText(String input) {
    if (input.isEmpty) return input;
    return structureSolutionOutline(normalizeForSolutionDisplay(input));
  }

  static bool looksLikeMath(String input) {
    final t = input.trim();
    if (t.isEmpty) return false;
    return RegExp(
          r'\\(?:frac|dfrac|tfrac|sqrt|cdot|times|left|right|text|overline|'
          r'underline|begin|infty|pm|neq|leq|geq|displaystyle|hline|'
          r'vert|lvert|rvert|implies)\b',
        ).hasMatch(t) ||
        t.contains(r'^') ||
        t.contains(r'_') ||
        t.contains('{') ||
        RegExp(r'(^|[^\\A-Za-z])frac\{').hasMatch(t) ||
        // $A + B + C$ / $a < b < 0$ gibi basit cebir (Yalnız I düz metin kalsın)
        RegExp(r'[A-Za-z0-9]\s*[+\-=≠≤≥<>×·]\s*[A-Za-z0-9]').hasMatch(t);
  }

  static String wrapBareLatex(String input) {
    var src = normalizeSlashFractions(_repairLatexEscapes(input.trim()));
    if (src.isEmpty) return src;
    final display = RegExp(r'^\$\$([\s\S]+)\$\$$').firstMatch(src);
    if (display != null) {
      final inner = display.group(1)!.trim();
      return looksLikeMath(inner) ? src : inner;
    }
    // Yalnızca metnin tamamı tek `$…$` ise veya önde gelen blok math değilse
    // sarmalayıcıyı aç. `$a$ sıfırdan…` gibi gövdelerde kalan metni ASLA atma.
    final wrapped = RegExp(r'^\$([^$]+)\$').firstMatch(src);
    if (wrapped != null) {
      final inner = wrapped.group(1)!.trim();
      final rest = src.substring(wrapped.end);
      if (looksLikeMath(inner)) return src;
      if (rest.trim().isEmpty) return inner;
      return '$inner$rest';
    }
    if (src.contains(r'$') || src.contains(r'\(') || src.contains(r'\[')) {
      return src;
    }
    // Şık: -1/2, 3/4 → $-\frac{1}{2}$ / $\frac{3}{4}$
    final slashFrac = RegExp(r'^(-?)(\d+)\s*/\s*(\d+)$').firstMatch(src);
    if (slashFrac != null) {
      final sign = slashFrac.group(1)!;
      final num = slashFrac.group(2)!;
      final den = slashFrac.group(3)!;
      if (sign.isEmpty) {
        return '\$\\frac{$num}{$den}\$';
      }
      return '\$-\\frac{$num}{$den}\$';
    }
    if (looksLikeMath(src)) return '\$${src}\$';
    return src;
  }

  /// `x/y`, `$x$/$y$` ve OCR satır kırıklı `x↵y` → `$\frac{x}{y}$`.
  /// Mevcut `$…$` / `$$…$$` blokları korunur; sayısal kesirler ayrıca işlenir.
  static String normalizeSlashFractions(String input) {
    if (input.isEmpty) return input;
    var src = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    src = src.replaceAllMapped(
      RegExp(r'\$([^$]+)\$\s*/\s*\$([^$]+)\$'),
      (m) => r'$\frac{' + m.group(1)!.trim() + '}{' + m.group(2)!.trim() + r'}$',
    );

    final holders = <String>[];
    src = src.replaceAllMapped(
      RegExp(r'\$\$[\s\S]+?\$\$|\$[^$\n]+\$'),
      (m) {
        holders.add(m.group(0)!);
        return '§§F${holders.length - 1}§§';
      },
    );

    src = src.replaceAllMapped(
      RegExp(r'(?<![\\$A-Za-z0-9/])([A-Za-z])\s*/\s*([A-Za-z])(?![A-Za-z0-9/])'),
      (m) => r'$\frac{' + m.group(1)! + '}{' + m.group(2)! + r'}$',
    );

    src = src.replaceAllMapped(
      RegExp(
        r'(?<![A-Za-z0-9])([A-Za-z])\s*\n\s*/?\s*([A-Za-z])(?![A-Za-z0-9])\s*(?=oranı|oran[ıi]|değeri|kaçtır)',
        caseSensitive: false,
      ),
      (m) => r'$\frac{' + m.group(1)! + '}{' + m.group(2)! + r'}$',
    );

    src = src.replaceAllMapped(
      RegExp(
        r'(?<![A-Za-z0-9])([A-Za-z])\s+([A-Za-z])\s+(oran[ıi]|orani)\s',
        caseSensitive: false,
      ),
      (m) => r'$\frac{' + m.group(1)! + '}{' + m.group(2)! + r'}$ ${m.group(3)!} ',
    );

    return _expandHolders(src, holders, r'§§F(\d+)§§');
  }

  /// ÖSYM kitapçığı: tüm kesirler display boyutu.
  ///
  /// TeX kuralı: dış `\frac` içindeki iç `\frac` scriptstyle (küçük) olur.
  /// Bu yüzden `\frac` / `\tfrac` → `\dfrac` (iç içe 1/4 de gövde puntosunda kalır).
  static String forceDisplaySizeAll(String tex, {bool forceDisplayStyle = true}) {
    var t = tex.trim();
    if (t.isEmpty) return t;
    t = t.replaceAll(r'\ttfrac', r'\frac');
    t = t.replaceAll(r'\ddfrac', r'\frac');
    t = t.replaceAllMapped(
      RegExp(r'\{([^{}]+)\\over\s*([^{}]+)\}'),
      (m) => '\\frac{${m.group(1)!.trim()}}{${m.group(2)!.trim()}}',
    );
    if (forceDisplayStyle) {
      // \dfrac / \tfrac koru, düz \frac → \dfrac (iç içe küçülmeyi kes)
      t = t.replaceAll(r'\dfrac', '§§DFRAC§§');
      t = t.replaceAll(r'\tfrac', '§§DFRAC§§');
      t = t.replaceAll(r'\frac', r'\dfrac');
      t = t.replaceAll('§§DFRAC§§', r'\dfrac');
      final isTabular = t.contains(r'\begin{array}') ||
          t.contains(r'\begin{matrix}') ||
          t.contains(r'\begin{pmatrix}');
      if (!isTabular && !RegExp(r'\\displaystyle\b').hasMatch(t)) {
        t = r'\displaystyle ' + t;
      }
    }
    return t;
  }

  static String prepareTex(String tex, {bool forceDisplayStyle = true}) {
    // Soft hyphen (heceleme) LaTeX komutlarını bozar → önce temizle.
    var t = _repairLatexEscapes(tex.replaceAll('\u00AD', '').trim());
    t = t.replaceAllMapped(
      RegExp(
        r'\\+(sqrt|frac|dfrac|tfrac|cdot|times|left|right|text|overline|underline|pi|alpha|beta|gamma|theta|leq|geq|neq|pm|mp|infty|sum|int|log|sin|cos|tan|begin|end|array|hline|matrix|displaystyle|rule)',
      ),
      (m) => '\\${m.group(1)}',
    );
    t = replaceHlineWithColoredRule(t);
    return forceDisplaySizeAll(t, forceDisplayStyle: forceDisplayStyle);
  }

  static String normalizeLatex(String input) {
    if (input.isEmpty) return input;
    String inlineBodyToDollars(String body) {
      var cleaned = repairGoogleDocsVertBars(body.trim());
      if (cleaned.contains('\n')) {
        cleaned = cleaned.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();
      }
      if (RegExp(r'\\begin\{(?:array|matrix|pmatrix|cases)\}').hasMatch(cleaned)) {
        return r'$$' + cleaned + r'$$';
      }
      return '\$$cleaned\$';
    }

    var text = mergeSplitInlineDollarMath(
      repairGoogleDocsVertBars(_repairLatexEscapes(input)),
    )
        .replaceAllMapped(
          RegExp(r'\\\[([\s\S]+?)\\\]'),
          (m) => r'$$' + m.group(1)!.trim() + r'$$',
        )
        .replaceAllMapped(
          RegExp(r'\\\(([\s\S]+?)\\\)'),
          (m) => inlineBodyToDollars(m.group(1)!),
        );
    return text;
  }

  static String restoreCollapsedBreaks(String input) {
    if (input.isEmpty) return input;
    var src = mergeSplitInlineDollarMath(
      input.replaceAll('\r\n', '\n').replaceAll('\r', '\n'),
    );
    final holders = <String>[];
    src = src.replaceAllMapped(
      RegExp(
        r'\$\$[\s\S]+?\$\$|'
        r'\$[^$\n]+\$|'
        r'\\\([\s\S]+?\\\)|'
        r'\\\[[\s\S]+?\\\]',
      ),
      (m) {
        holders.add(m.group(0)!);
        return '§§M${holders.length - 1}§§';
      },
    );
    final mdHolders = <String>[];
    src = src.replaceAllMapped(
      RegExp(r'\*\*[\s\S]+?\*\*|__[\s\S]+?__'),
      (m) {
        mdHolders.add(m.group(0)!);
        return '§§K${mdHolders.length - 1}§§';
      },
    );
    src = glueRomanNumeralLabels(src);
    // Google günlük çözüm yapıştırması: 10.06.2024, Sonu:, Ayrımı:
    src = src.replaceAllMapped(
      RegExp(
        r'(Çözüm Adımları)(?!\n)(?=\d{1,2}\.\d{1,2}\.\d{4})',
        caseSensitive: false,
      ),
      (m) => '${m.group(1)}\n',
    );
    src = src.replaceAllMapped(
      RegExp(r'(?<=[a-zçğıöşüâîû])(?=\d{1,2}\.\d{1,2}\.\d{4})'),
      (_) => '\n',
    );
    src = src.replaceAllMapped(
      RegExp(r'([.!?])(?!\n)(?=\d{1,2}\.\d{1,2}\.\d{4})'),
      (m) => '${m.group(1)}\n',
    );
    final dateHolders = <String>[];
    src = src.replaceAllMapped(
      RegExp(r'(?<!\d)(\d{1,2}\.\d{1,2}\.\d{4})(?!\d)'),
      (m) {
        dateHolders.add(m.group(1)!);
        return '§§D${dateHolders.length - 1}§§';
      },
    );
    src = src.replaceAllMapped(
      RegExp(
        r'(Sonu:|Ayrımı:|Sonuç:|Başlangıcı ve Ayrımı:|Değerinin Bulunması:)(?!\n)(?=\S)',
        caseSensitive: false,
      ),
      (m) => '${m.group(1)}\n',
    );
    src = src.replaceAllMapped(
      RegExp(r'([.!?])(?!\n)(?=[A-ZÇĞİÖŞÜÂÎÛ])'),
      (m) => '${m.group(1)}\n',
    );
    src = src.replaceAllMapped(
      RegExp(r':(?!\n)(?=[A-ZÇĞİÖŞÜÂÎÛ])'),
      (m) => ':\n',
    );
    src = src.replaceAllMapped(
      RegExp(r'([.!?])(?!\n)(?=\d+\.\s)'),
      (m) => '${m.group(1)}\n',
    );
    src = src.replaceAllMapped(
      RegExp(r':(?!\n)(?=\d+\.\s)'),
      (m) => ':\n',
    );
    src = src.replaceAllMapped(
      RegExp(r';(?!\n)(?=§§M|[\$A-ZÇĞİÖŞÜÂÎÛ])'),
      (m) => ';\n',
    );
    // Google mantık çözümü: A Seçeneği: / B Seçeneği:
    src = src.replaceAllMapped(
      RegExp(r'(?<!\n)(?=[A-E]\s+Seçeneği\s*:)', caseSensitive: false),
      (_) => '\n',
    );
    // Adım Adım Çözüm: yapışık başlık
    src = src.replaceAllMapped(
      RegExp(r'(Adım Adım Çözüm:)(?!\n)(?=\S)', caseSensitive: false),
      (m) => '${m.group(1)}\n',
    );
    // şartlar şunlardır:Rakamlar
    src = src.replaceAllMapped(
      RegExp(r'(şunlardır:)(?!\n)(?=Rakamlar)', caseSensitive: false),
      (m) => '${m.group(1)}\n',
    );
    // §§M)Rakamlar — parantez + yeni madde
    src = src.replaceAllMapped(
      RegExp(r'(§§M\d+§§\))(?!\n)(?=[A-ZÇĞİÖŞÜ])'),
      (m) => '${m.group(1)}\n',
    );
    src = src.replaceAllMapped(
      RegExp(r'(§§M\d+§§)(?=§§M\d+§§)'),
      (m) => '${m.group(1)}\n',
    );
    src = src.replaceAllMapped(
      RegExp(r'(§§M\d+§§)(?!\n)(?=[A-ZÇĞİÖŞÜ])'),
      (m) => '${m.group(1)}\n',
    );
    src = src.replaceAllMapped(
      RegExp(r'(?<=[a-zçğıöşüâîû])(?=§§M)'),
      (_) => '\n',
    );
    // §§M sonrası liste etiketi / yeni cümle
    src = src.replaceAllMapped(
      RegExp(
        r'(§§M\d+§§)(?!\n)(?=(?:Rakamlar|Kendisi|Son maddede|Elde edilen|Kağıda|Şimdi |Bulduğumuz|Görüldüğü|Now:|Çarpım ))',
        caseSensitive: false,
      ),
      (m) => '${m.group(1)}\n',
    );
    // Numaralı bölüm: 1. Tek/ … 2. Kağıttaki
    src = src.replaceAllMapped(
      RegExp(r'(?<!\n)(?=\d+\.\s+(?:Tek/|Kağıttaki))', caseSensitive: false),
      (_) => '\n',
    );
    // Mutlak değer denemesi: ...edelim:A) / ❌B) / C) 5'in...
    src = src.replaceAllMapped(
      RegExp(
        r'(?<!\n)(?=[A-E]\)\s+(?:\d|[\u0027\u2019]|[A-Za-zÇĞİÖŞÜçğıöşü]))',
      ),
      (_) => '\n',
    );
    src = src.replaceAllMapped(
      RegExp(r'([❌✅])(?!\n)(?=[A-E]\))'),
      (m) => '${m.group(1)}\n',
    );
    src = src.replaceAllMapped(
      RegExp(r'(olsaydı:)(?!\n)(?=[\$\\\(])', caseSensitive: false),
      (m) => '${m.group(1)}\n',
    );
    src = src.replaceAllMapped(
      RegExp(
        r'(?<!\n)(?=(?:Kendisi|Rakamlar(?:ı|ları|ın)\s+(?:toplamı|çarpımı|farkı|oranı))\s*:)',
        caseSensitive: false,
      ),
      (_) => '\n',
    );
    src = src.replaceAllMapped(
      RegExp(r'(\((?:Çift|Tek)\))(?!\n)(?=Rakamlar)', caseSensitive: false),
      (m) => '${m.group(1)}\n',
    );
    src = src.replaceAllMapped(
      RegExp(r'(\(Tek\))(?!\n)(?=Görüldüğü)', caseSensitive: false),
      (m) => '${m.group(1)}\n',
    );
    src = src.replaceAllMapped(
      RegExp(r'(\d+\.\s+[^:]+:)(\s*)(?=\\\(|\$|§§M)'),
      (m) => '${m.group(1)}\n',
    );
    src = src.replaceAllMapped(
      RegExp(r'([a-zçğıöşüâîû]:)(?!\n)(?=\$)', caseSensitive: false),
      (m) => '${m.group(1)}\n',
    );
    src = src.replaceAllMapped(
      RegExp(r'(\$)(?!\n)(?=[A-ZÇĞİÖŞÜ])'),
      (m) => '${m.group(1)}\n',
    );
    src = src.replaceAllMapped(
      RegExp(
        r'(\$[^$\n]+\$)(?!\n)\s*(?=İlk|Now:|Sonra|Bu )',
        caseSensitive: false,
      ),
      (m) => '${m.group(1)}\n',
    );
    src = src.replaceAllMapped(
      RegExp(r'([.!?])(?!\n)(?=\d+\s)'),
      (m) => '${m.group(1)}\n',
    );
    // camelCase: GösterimKitabın — 5A/pH/iPhone bölünmez (rich_text_common.py ile aynı)
    src = src.replaceAllMapped(
      RegExp(r'(?<=[a-zçğıöşüâîû]{2})(?=[A-ZÇĞİÖŞÜÂÎÛ][a-zçğıöşüâîû])'),
      (_) => '\n',
    );
    src = _restoreCollapsedPresenceTable(src);
    src = src.replaceAllMapped(
      RegExp(r'(?<!\n)(\d+\.\s+Adım)'),
      (m) => '\n${m.group(1)}',
    );
    src = src.replaceAllMapped(
      RegExp(r'(göre\*{0,2})(?!\n)(?=\s+(?:I|II|III|IV|V)\.)'),
      (m) => '${m.group(1)}\n',
    );
    // Pay / Payda / Kesrin değeri — formül yanına yapışmasın.
    src = src.replaceAllMapped(
      RegExp(
        r'(?<!\n)\s*(?=(?:\*\*)?(?:Payda|Pay|Kesrin değeri)\s*:)',
        caseSensitive: false,
      ),
      (_) => '\n',
    );
    // Yalnızca gerçek madde listesi: en az iki FARKLI Romen (I. + II. …).
    final romanMatches = RegExp(r'\b(I|II|III|IV|V|VI|VII|VIII|IX|X)\.\s')
        .allMatches(src)
        .map((m) => m.group(0)!.trimRight())
        .toSet();
    if (romanMatches.length >= 2) {
      src = src.replaceAllMapped(
        RegExp(r'(?<!\n)(?=\b(?:I|II|III|IV|V|VI|VII|VIII|IX|X)\.\s)'),
        (m) => '\n',
      );
    }
    src = _expandHolders(src, mdHolders, r'§§K(\d+)§§');
    src = src.replaceAllMapped(
      RegExp(r'(§§M\d+§§)\s*(?=\*\*(?:\d+\.\s+Adım|[a-zçğıöşüâîû]))'),
      (m) => '${m.group(1)}\n',
    );
    src = src.replaceAllMapped(
      RegExp(
        r'(§§M\d+§§)\s+(?=(?:ifadelerinden|hangileri|yukarıdakilerden))',
      ),
      (m) => '${m.group(1)}\n',
    );
    src = src.replaceAllMapped(
      RegExp(r'(§§M\d+§§)(?=\d+\.\s)'),
      (m) => '${m.group(1)}\n',
    );
    src = src.replaceAllMapped(
      RegExp(r'([.!?])(?!\n)(?=§§M\d+§§)'),
      (m) => '${m.group(1)}\n',
    );
    src = src.replaceAllMapped(
      RegExp(
        r'(§§M\d+§§)(?!\n)(?=(?:Değerinin Bulunması|Sonuç)\s*:)',
        caseSensitive: false,
      ),
      (m) => '${m.group(1)}\n',
    );
    src = _expandHolders(src, dateHolders, r'§§D(\d+)§§');
    src = _expandHolders(src, holders, r'§§M(\d+)§§');
    // Tam denklem / $$ bloğu ayrı satır. Cümle içi $\frac{x}{y}$ kopmasın.
    src = src.replaceAllMapped(
      RegExp(r'\$\$([\s\S]+?)\$\$|\$([^$\n]+)\$'),
      (m) {
        final full = m.group(0)!;
        final inner = (m.group(1) ?? m.group(2) ?? '').trim();
        if (m.group(1) != null || isStandaloneDisplayEquation(inner)) {
          return '\n$full\n';
        }
        return full;
      },
    );
    return src.replaceAll(RegExp(r'\n{3,}'), '\n\n').replaceFirst(RegExp(r'^\n+'), '');
  }

  static final _presenceCellRe = RegExp(
    r'^(Yok|Var)\s*\(\s*[01]\s*\)$',
    caseSensitive: false,
  );
  static final _allCapsNameRe = RegExp(r'^[A-ZÇĞİÖŞÜÂÎÛ]{3,}$');
  static final _binCodeRe = RegExp(r'^[01]{3}$');

  static String _restoreCollapsedPresenceTable(String src) {
    src = src.replaceAllMapped(
      RegExp(r'(Öğrenci)(?=[A-ZÇĞİÖŞÜÂÎÛ]\s+Harfi)', caseSensitive: false),
      (m) => '${m.group(1)}\n',
    );
    src = src.replaceAllMapped(
      RegExp(r'(Harfi)(?=[A-ZÇĞİÖŞÜÂÎÛ]\s+Harfi)'),
      (m) => '${m.group(1)}\n',
    );
    src = src.replaceAllMapped(
      RegExp(r'(Harfi)(?=Oluşan\s+Benzersiz)'),
      (m) => '${m.group(1)}\n',
    );
    src = src.replaceAllMapped(
      RegExp(r'(?<!\n)(?=Oluşan Benzersiz)'),
      (_) => '\n',
    );
    src = src.replaceAllMapped(
      RegExp(r'(\))(?=[A-ZÇĞİÖŞÜÂÎÛ]{3,})'),
      (m) => ')\n',
    );
    src = src.replaceAllMapped(
      RegExp(r'(?<=[A-ZÇĞİÖŞÜÂÎÛ]{3})(?=(?:Yok|Var)\s*\(\s*[01]\s*\))'),
      (_) => '\n',
    );
    src = src.replaceAllMapped(
      RegExp(r'(\(\s*[01]\s*\))(?=(?:Yok|Var)\s*\()'),
      (m) => '${m.group(1)}\n',
    );
    src = src.replaceAllMapped(
      RegExp(r'(\(\s*[01]\s*\))(?=[01]{3}(?:[A-ZÇĞİÖŞÜÂÎÛ]|$))'),
      (m) => '${m.group(1)}\n',
    );
    src = src.replaceAllMapped(
      RegExp(r'([01]{3})(?=[A-ZÇĞİÖŞÜÂÎÛ])'),
      (m) => '${m.group(1)}\n',
    );
    src = src.replaceAllMapped(
      RegExp(r'(?<=[A-ZÇĞİÖŞÜÂÎÛ]{3})(?=[A-ZÇĞİÖŞÜÂÎÛ][a-zçğıöşüâîû]{3,})'),
      (_) => '\n',
    );
    return src;
  }

  static String _formatPresenceTable(String text) {
    final lines = text.split('\n');
    var start = -1;
    for (var i = 0; i < lines.length; i++) {
      final probe = lines[i].trim();
      if (probe == 'Öğrenci' ||
          RegExp(r'\bHarfi\b').hasMatch(probe) ||
          probe.contains('Benzersiz Kod')) {
        start = i;
        break;
      }
    }
    if (start < 0) return text;

    final headers = <String>[];
    var i = start;
    while (i < lines.length) {
      final s = lines[i].trim();
      if (s.isEmpty) {
        i += 1;
        continue;
      }
      if (_allCapsNameRe.hasMatch(s) || _presenceCellRe.hasMatch(s)) break;
      final gluedHeader = RegExp(
        r'^(Öğrenci)\s*([A-ZÇĞİÖŞÜÂÎÛ]\s+Harfi)$',
        caseSensitive: false,
      ).firstMatch(s);
      if (gluedHeader != null) {
        headers.add(gluedHeader.group(1)!);
        headers.add(gluedHeader.group(2)!);
        i += 1;
        continue;
      }
      headers.add(s);
      i += 1;
    }
    final letterHeaders = [
      for (final header in headers)
        if (header.toLowerCase() != 'öğrenci' &&
            !header.toLowerCase().contains('kod'))
          header.replaceFirst(RegExp(r'\s*Harfi\s*$', caseSensitive: false), '').trim(),
    ];
    final rows = <({String name, List<String> cells, String code})>[];
    while (i < lines.length) {
      final s = lines[i].trim();
      if (s.isEmpty) {
        i += 1;
        continue;
      }
      if (!_allCapsNameRe.hasMatch(s)) break;
      final name = s;
      i += 1;
      final cells = <String>[];
      var code = '';
      while (i < lines.length) {
        final t = lines[i].trim();
        if (_presenceCellRe.hasMatch(t)) {
          cells.add(t);
          i += 1;
        } else if (_binCodeRe.hasMatch(t)) {
          code = t;
          i += 1;
          break;
        } else {
          break;
        }
      }
      if (cells.isEmpty) break;
      rows.add((name: name, cells: cells, code: code));
    }
    if (rows.length < 2) return text;

    final block = <String>['**Harf kodu:**'];
    for (final row in rows) {
      final bits = <String>[];
      for (var c = 0; c < row.cells.length; c++) {
        final label = c < letterHeaders.length
            ? letterHeaders[c]
            : String.fromCharCode(72 + c);
        final kind = row.cells[c].toLowerCase().startsWith('var') ? 'var' : 'yok';
        bits.add('$label $kind');
      }
      final tail = row.code.isNotEmpty ? ' → **${row.code}**' : '';
      block.add('- **${row.name}:** ${bits.join(', ')}$tail');
    }
    final before = lines.sublist(0, start).join('\n').trimRight();
    final after = lines.sublist(i).join('\n').trimLeft();
    return [if (before.isNotEmpty) before, block.join('\n'), if (after.isNotEmpty) after]
        .join('\n\n');
  }

  static final _optionHeaderRe = RegExp(
    r'^(?:[-•*◦○–—]\s+)?(?:\*\*)?'
    r'([A-E])\)\s+'
    r'([A-ZÇĞİÖŞÜÂÎÛİ][A-ZÇĞİÖŞÜÂÎÛİa-zçğıöşüâîû]*)'
    r'\s*:?(?:\*\*)?\s*$',
  );
  static final _optionSecenegiInlineRe = RegExp(
    r'^(?:[-•*◦○–—]\s+)?(?:\*\*)?'
    r'([A-E])\s+Seçeneği'
    r'\s*:\s*(.*)$',
    caseSensitive: false,
  );
  static final _optionSecenegiOnlyRe = RegExp(
    r'^(?:[-•*◦○–—]\s+)?(?:\*\*)?'
    r'([A-E])\s+Seçeneği'
    r'\s*:?\s*(?:\*\*)?\s*$',
    caseSensitive: false,
  );
  /// Google çözümü: `A) 3'ün sağında olsaydı:`
  static final _optionTrialHeaderRe = RegExp(
    r'^(?:[-•*◦○–—]\s+)?(?:\*\*)?'
    r'([A-E])\)\s+(.+\S)\s*:?\s*$',
  );
  static final _bulletStripRe = RegExp(r'^(\s*)[-•*◦○–—]\s+');
  static final _kuralOzetiRe = RegExp(r'^Kural\s+Özeti\s*:?\s*$', caseSensitive: false);
  static final _resultTailRe = RegExp(
    r'(→\s*)(🧍\s*)?(Oturuyor|AYAKTA)\.?\s*$',
    caseSensitive: false,
  );
  static final _formulaListLabelRe = RegExp(
    r'^(Kendisi|Rakamlar(?:ı|ları|ın)\s+(?:toplamı|çarpımı|farkı(?:nın mutlak değeri)?|oranı))\s*:\s*.+',
    caseSensitive: false,
  );
  static final _numberedSectionRe = RegExp(r'^\d+\.\s+.+\S');
  static final _numberedSectionTitleRe = RegExp(
    r'^(\d+\.\s+[^:]+:)(.*)$',
    dotAll: true,
  );
  static final _stepHeaderRe = RegExp(r'^\d+\.\s+Adım:', caseSensitive: false);
  static final _conditionBulletRe = RegExp(
    r'^(?:Rakamlar\s|Son maddede)',
    caseSensitive: false,
  );
  static final _adimAdimHeaderRe = RegExp(
    r'^(.*?Adım Adım Çözüm:)\s*(.*)$',
    caseSensitive: false,
  );

  static bool _isOptionHeaderLine(String line) {
    final s = line.trim();
    if (s.isEmpty) return false;
    if (_optionHeaderRe.hasMatch(s) ||
        _optionSecenegiOnlyRe.hasMatch(s) ||
        _optionSecenegiInlineRe.hasMatch(s)) {
      return true;
    }
    final trial = _optionTrialHeaderRe.firstMatch(s);
    if (trial != null) {
      final body = trial.group(2)!.trim();
      return body.contains(RegExp(r"[\s'\d]"));
    }
    return false;
  }

  static ({String letter, String title, String? inline})? _parseOptionHeader(
    String line,
  ) {
    final s = line.trim();
    var hm = _optionHeaderRe.firstMatch(s);
    if (hm != null) {
      final letter = hm.group(1)!.toUpperCase();
      return (
        letter: letter,
        title: '$letter) ${hm.group(2)!}',
        inline: null,
      );
    }
    hm = _optionSecenegiInlineRe.firstMatch(s);
    if (hm != null) {
      final letter = hm.group(1)!.toUpperCase();
      final body = (hm.group(2) ?? '').trim();
      return (
        letter: letter,
        title: '$letter Seçeneği',
        inline: body.isEmpty ? null : body,
      );
    }
    hm = _optionSecenegiOnlyRe.firstMatch(s);
    if (hm != null) {
      final letter = hm.group(1)!.toUpperCase();
      return (letter: letter, title: '$letter Seçeneği', inline: null);
    }
    hm = _optionTrialHeaderRe.firstMatch(s);
    if (hm != null) {
      final letter = hm.group(1)!.toUpperCase();
      final body = hm.group(2)!.trim();
      return (letter: letter, title: '$letter) $body', inline: null);
    }
    return null;
  }

  static String _stripOuterBold(String text) {
    final src = text.trim();
    if (src.startsWith('**') &&
        src.endsWith('**') &&
        src.indexOf('**', 2) == src.length - 2) {
      return src.substring(2, src.length - 2).trim();
    }
    return src;
  }

  static String _emphasizeResultTail(String line) {
    return line.replaceAllMapped(_resultTailRe, (m) {
      final arrow = m.group(1)!;
      final emoji = m.group(2) ?? '';
      final word = m.group(3)!;
      return '$arrow$emoji**$word**.';
    });
  }

  static List<String> _structurePreambleLines(List<String> lines) {
    final out = <String>[];
    var i = 0;
    while (i < lines.length) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        i += 1;
        continue;
      }
      if (i == 0 && line.contains('Adım Adım')) {
        final hdr = _adimAdimHeaderRe.firstMatch(line);
        if (hdr != null) {
          out.add('**${hdr.group(1)!.trim()}**');
          out.add('');
          final rest = hdr.group(2)!.trim();
          if (rest.isNotEmpty) out.add(rest);
          i += 1;
          continue;
        }
        out.add('**${_stripOuterBold(line)}**');
        out.add('');
        i += 1;
        continue;
      }
      if (i == 0 &&
          (line.startsWith('💡') || line.contains('Adim Adim'))) {
        out.add('**${_stripOuterBold(line)}**');
        out.add('');
        i += 1;
        continue;
      }
      if (_formulaListLabelRe.hasMatch(line)) {
        while (i < lines.length && _formulaListLabelRe.hasMatch(lines[i].trim())) {
          out.add('- ${lines[i].trim()}');
          i += 1;
        }
        out.add('');
        continue;
      }
      if (_conditionBulletRe.hasMatch(line)) {
        while (i < lines.length && _conditionBulletRe.hasMatch(lines[i].trim())) {
          out.add('- ${lines[i].trim()}');
          i += 1;
        }
        out.add('');
        continue;
      }
      if (_stepHeaderRe.hasMatch(line)) {
        final core = line.trim();
        if (core.startsWith('**') &&
            core.endsWith('**') &&
            core.indexOf('**', 2) == core.length - 2) {
          out.add(core);
        } else {
          out.add('**$core**');
        }
        out.add('');
        i += 1;
        continue;
      }
      if (_numberedSectionRe.hasMatch(line)) {
        final title = _numberedSectionTitleRe.firstMatch(line);
        if (title != null && title.group(2)!.trim().isNotEmpty) {
          out.add('**${title.group(1)!.trim()}**');
          out.add('');
          out.add(title.group(2)!.trim());
        } else {
          out.add('**$line**');
        }
        out.add('');
        i += 1;
        continue;
      }
      if (_kuralOzetiRe.hasMatch(line) ||
          line.toLowerCase().startsWith('kural özeti')) {
        out.add('**Kural Özeti:**');
        i += 1;
        while (i < lines.length) {
          final nxt = lines[i].trim();
          if (nxt.isEmpty) {
            i += 1;
            break;
          }
          if (nxt.startsWith('Şimdi ') ||
              nxt.startsWith('Bir öğrenci') ||
              _isOptionHeaderLine(nxt)) {
            break;
          }
          final body = _stripOuterBold(
            nxt.replaceFirst(_bulletStripRe, '').trim(),
          );
          if (body.isNotEmpty) out.add('- $body');
          i += 1;
        }
        out.add('');
        continue;
      }
      out.add(line);
      i += 1;
    }
    return out;
  }

  /// Google çözüm yapısı: madde + A–E iç içe liste (idempotent).
  static String structureSolutionOutline(String input) {
    if (input.isEmpty) return input;
    var src = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    if (src.isEmpty) return src;
    src = _formatPresenceTable(src);
    final lines = src.split('\n');
    final optionIdxs = <int>[];
    for (var i = 0; i < lines.length; i++) {
      if (_isOptionHeaderLine(lines[i].trim())) {
        optionIdxs.add(i);
      }
    }
    if (optionIdxs.length < 2) {
      final preamble = _structurePreambleLines(lines);
      return preamble.isEmpty ? src : preamble.join('\n').trim();
    }

    final out = _structurePreambleLines(lines.sublist(0, optionIdxs.first));
    if (out.isNotEmpty && out.last.isNotEmpty) out.add('');

    for (var oi = 0; oi < optionIdxs.length; oi++) {
      final start = optionIdxs[oi];
      final end =
          oi + 1 < optionIdxs.length ? optionIdxs[oi + 1] : lines.length;
      final block = <String>[];
      for (var j = start; j < end; j++) {
        if (lines[j].trim().isNotEmpty) block.add(lines[j]);
      }
      if (block.isEmpty) continue;
      final parsed = _parseOptionHeader(block.first.trim());
      if (parsed == null) continue;
      out.add('- **${parsed.title}:**');
      if (parsed.inline != null) {
        final body = _stripOuterBold(parsed.inline!);
        if (body.isNotEmpty) {
          out.add('  - ${_emphasizeResultTail(body)}');
        }
      }
      for (var c = 1; c < block.length; c++) {
        var raw = block[c].trim().replaceFirst(_bulletStripRe, '').trim();
        raw = _stripOuterBold(raw);
        if (raw.isEmpty) continue;
        out.add('  - ${_emphasizeResultTail(raw)}');
      }
      out.add('');
    }
    return out.join('\n').trim();
  }

  static TextStyle _emphasis(
    TextStyle base, {
    bool bold = false,
    bool italic = false,
    bool underline = false,
    Color? textColor,
  }) {
    final color = textColor ?? base.color ?? Colors.white;
    // Bazı Android ROM'larda font weight farkı görünmez; gölge ile kalınlık zorlanır.
    return base.copyWith(
      color: color,
      fontWeight: bold ? FontWeight.w700 : base.fontWeight,
      fontStyle: italic ? FontStyle.italic : base.fontStyle,
      letterSpacing: base.letterSpacing,
      shadows: base.shadows,
      decoration: underline
          ? TextDecoration.underline
          : base.decoration,
      decorationColor: underline ? color : base.decorationColor,
      decorationThickness: underline ? 2.4 : base.decorationThickness,
      decorationStyle: underline ? TextDecorationStyle.solid : base.decorationStyle,
    );
  }

  static List<InlineSpan> parseSpans(
    String input,
    TextStyle base, {
    bool forceDisplayMath = false,
  }) =>
      _parse(input, base, forceDisplayMath: forceDisplayMath);

  /// Tek satırı metin + formül parçalarına böler (Row/FittedBox için).
  static List<Widget> lineToRowChildren(String input, TextStyle base) {
    final spans = _parse(input, base);
    final widgets = <Widget>[];
    for (final span in spans) {
      if (span is WidgetSpan) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: span.child ?? const SizedBox.shrink(),
          ),
        );
      } else if (span is TextSpan) {
        if (span.children != null && span.children!.isNotEmpty) {
          widgets.add(
            Text.rich(
              TextSpan(style: span.style ?? base, children: span.children),
              softWrap: false,
            ),
          );
        } else if (span.text != null && span.text!.isNotEmpty) {
          widgets.add(
            Text(span.text!, style: span.style ?? base, softWrap: false),
          );
        }
      }
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final String laidOut;
    if (preserveLineBreaks) {
      laidOut = examLayout && examWrap && !solutionMode
          ? prepareExamDisplayText(data)
          : prepareSolutionText(data);
    } else {
      var text = normalizeMarkup(data);
      text = normalizeLatex(examFormat(text));
      laidOut = examLayout && examWrap
          ? text
          : structureSolutionOutline(restoreCollapsedBreaks(text));
    }
    final useExamLayout = examLayout || preserveLineBreaks;

    if (preserveLineBreaks || laidOut.contains('\n') || examWrap) {
      return _DocumentText(
        text: laidOut,
        base: base,
        textAlign: textAlign,
        examLayout: useExamLayout,
        examScaleDown: examScaleDown,
        examWrap: examWrap,
      );
    }

    if (paragraphLayout) {
      return _ParagraphText(
        text: laidOut,
        base: base,
        textAlign: textAlign,
        forceDisplayMath: forceDisplayMath,
        examLayout: useExamLayout,
        examScaleDown: examScaleDown,
      );
    }

    if (useExamLayout) {
      return _ExamLine(
        line: laidOut,
        base: base,
        textAlign: textAlign,
        scaleDown: examScaleDown,
      );
    }

    return _OverflowSafeLine(
      alignment: _overflowAlignment(textAlign),
      child: Text.rich(
        TextSpan(
          style: base,
          children: _parse(
            laidOut,
            base,
            forceDisplayMath: forceDisplayMath,
          ),
        ),
        textAlign: textAlign,
        softWrap: false,
      ),
    );
  }

  static Alignment _overflowAlignment(TextAlign? align) {
    return switch (align) {
      TextAlign.center => Alignment.center,
      TextAlign.right => Alignment.centerRight,
      TextAlign.end => Alignment.centerRight,
      TextAlign.justify => Alignment.centerLeft,
      _ => Alignment.centerLeft,
    };
  }

  static List<InlineSpan> _parse(
    String input,
    TextStyle base, {
    bool forceDisplayMath = false,
  }) {
    if (input.isEmpty) return [TextSpan(text: '', style: base)];

    final colorRe = RegExp(r'\{(green|red|blue)\}([\s\S]+?)\{\/\1\}');
    if (colorRe.hasMatch(input)) {
      final spans = <InlineSpan>[];
      var i = 0;
      for (final m in colorRe.allMatches(input)) {
        if (m.start > i) {
          spans.addAll(
            _parseMath(
              input.substring(i, m.start),
              base,
              forceDisplayMath: forceDisplayMath,
            ),
          );
        }
        final color = switch (m.group(1)) {
          'green' => _greenText,
          'red' => _redText,
          'blue' => _blueText,
          _ => base.color,
        };
        spans.addAll(
          _parse(
            m.group(2)!,
            _emphasis(base, textColor: color),
            forceDisplayMath: forceDisplayMath,
          ),
        );
        i = m.end;
      }
      if (i < input.length) {
        spans.addAll(
          _parseMath(
            input.substring(i),
            base,
            forceDisplayMath: forceDisplayMath,
          ),
        );
      }
      return spans.isEmpty ? [TextSpan(text: '', style: base)] : spans;
    }

    return _parseMath(input, base, forceDisplayMath: forceDisplayMath);
  }

  static List<InlineSpan> _parseMath(
    String input,
    TextStyle base, {
    bool forceDisplayMath = false,
  }) {
    if (input.isEmpty) return [TextSpan(text: '', style: base)];

    final spans = <InlineSpan>[];
    final re = RegExp(r'\$\$([\s\S]+?)\$\$|\$([^$\n]+?)\$');
    var i = 0;
    for (final m in re.allMatches(input)) {
      if (m.start > i) {
        spans.addAll(_parseMarkdown(input.substring(i, m.start), base));
      }
      final raw = (m.group(1) ?? m.group(2) ?? '').trim();
      if (raw.isNotEmpty) {
        // Tek harf: gövde fontu / punto (Math WidgetSpan şişirmesin).
        if (m.group(1) == null && isPlainMathLetter(raw)) {
          spans.add(TextSpan(text: raw, style: base));
        } else {
          final isBlock = m.group(1) != null;
          // Kesir/kök cümle ortasında da gövde puntosunda (surrounded olsa bile).
          final display = forceDisplayMath ||
              isBlock ||
              usesDisplayMath(raw);
          spans.add(
            WidgetSpan(
              // Display kesir/kök: middle; cümle içi $x \cdot y$: alphabetic baseline.
              alignment: display
                  ? PlaceholderAlignment.middle
                  : PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: display ? 2 : 0),
                child: buildMathWidget(raw, base: base, display: display),
              ),
            ),
          );
        }
      }
      i = m.end;
    }
    if (i < input.length) {
      spans.addAll(_parseMarkdown(input.substring(i), base));
    }
    return spans;
  }

  static List<InlineSpan> _parseMarkdown(String input, TextStyle base) {
    if (input.isEmpty) return [];

    final spans = <InlineSpan>[];
    final re = RegExp(
      r'\{green\}([\s\S]+?)\{/green\}|'
      r'\{red\}([\s\S]+?)\{/red\}|'
      r'\{blue\}([\s\S]+?)\{/blue\}|'
      r'__\*\*\*(.+?)\*\*\*__|'
      r'\*\*__(.+?)__\*\*|'
      r'__\*\*(.+?)\*\*__|'
      r'\*\*\*(.+?)\*\*\*|'
      r'\*\*(.+?)\*\*|'
      r'__(.+?)__|'
      r'(?<!\*)\*(?!\*)\s*(.+?)\s*(?<!\*)\*(?!\*)',
      dotAll: true,
    );
    var i = 0;
    for (final m in re.allMatches(input)) {
      if (m.start > i) {
        spans.add(TextSpan(text: input.substring(i, m.start), style: base));
      }
      if (m.group(1) != null) {
        spans.addAll(
          _parseMarkdown(
            m.group(1)!,
            _emphasis(base, textColor: _greenText),
          ),
        );
      } else if (m.group(2) != null) {
        spans.addAll(
          _parseMarkdown(
            m.group(2)!,
            _emphasis(base, textColor: _redText),
          ),
        );
      } else if (m.group(3) != null) {
        spans.addAll(
          _parseMarkdown(
            m.group(3)!,
            _emphasis(base, textColor: _blueText),
          ),
        );
      } else if (m.group(4) != null) {
        spans.addAll(
          _parseMarkdown(
            m.group(4)!,
            _emphasis(base, bold: true, italic: true, underline: true),
          ),
        );
      } else if (m.group(5) != null || m.group(6) != null) {
        spans.addAll(
          _parseMarkdown(
            m.group(5) ?? m.group(6)!,
            _emphasis(base, bold: true, underline: true),
          ),
        );
      } else if (m.group(7) != null) {
        spans.addAll(
          _parseMarkdown(
            m.group(7)!,
            _emphasis(base, bold: true, italic: true),
          ),
        );
      } else if (m.group(8) != null) {
        spans.addAll(
          _parseMarkdown(
            m.group(8)!,
            _emphasis(base, bold: true),
          ),
        );
      } else if (m.group(9) != null) {
        spans.addAll(
          _parseMarkdown(
            m.group(9)!,
            _emphasis(base, underline: true),
          ),
        );
      } else if (m.group(10) != null) {
        spans.addAll(
          _parseMarkdown(
            m.group(10)!,
            _emphasis(base, italic: true),
          ),
        );
      }
      i = m.end;
    }
    if (i < input.length) {
      spans.add(TextSpan(text: input.substring(i), style: base));
    }
    return spans;
  }
}

class _ParagraphText extends StatelessWidget {
  final String text;
  final TextStyle base;
  final TextAlign? textAlign;
  final bool forceDisplayMath;
  final bool examLayout;
  final bool examScaleDown;

  const _ParagraphText({
    required this.text,
    required this.base,
    this.textAlign,
    this.forceDisplayMath = false,
    this.examLayout = false,
    this.examScaleDown = true,
  });

  @override
  Widget build(BuildContext context) {
    final paragraphs = text
        .split(RegExp(r'\n\n+'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (paragraphs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < paragraphs.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _buildParagraphWidget(paragraphs[i]),
        ],
      ],
    );
  }

  Widget _buildParagraphWidget(String paragraph) {
    final displayOnly = RegExp(r'^\$\$([\s\S]+)\$\$$').firstMatch(paragraph);
    if (displayOnly != null) {
      final tex = FormattedText.prepareTex(displayOnly.group(1)!.trim());
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: _OverflowSafeLine(
          alignment: Alignment.center,
          scaleDown: examScaleDown,
          child: FormattedText.buildMathWidget(
            tex,
            base: base,
            display: true,
          ),
        ),
      );
    }

    final leadingInline = RegExp(r'^\$([^$\n]+)\$\s*(.*)$').firstMatch(paragraph);
    if (leadingInline != null) {
      final tex = FormattedText.prepareTex(leadingInline.group(1)!.trim());
      if (forceDisplayMath || FormattedText.usesDisplayMath(tex)) {
        final rest = (leadingInline.group(2) ?? '').trim();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _OverflowSafeLine(
                alignment: Alignment.center,
                scaleDown: examScaleDown,
                child: FormattedText.buildMathWidget(
                  tex,
                  base: base,
                  display: true,
                ),
              ),
            ),
            if (rest.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: examLayout
                    ? _ExamLine(
                        line: rest,
                        base: base,
                        textAlign: textAlign,
                        scaleDown: examScaleDown,
                      )
                    : _OverflowSafeLine(
                        alignment: FormattedText._overflowAlignment(textAlign),
                        child: Text.rich(
                          TextSpan(
                            style: base,
                            children: FormattedText._parse(
                              rest,
                              base,
                              forceDisplayMath: forceDisplayMath,
                            ),
                          ),
                          textAlign: textAlign,
                          softWrap: false,
                        ),
                      ),
              ),
          ],
        );
      }
    }

    if (examLayout) {
      return _ExamLine(
        line: paragraph,
        base: base,
        textAlign: textAlign,
        scaleDown: examScaleDown,
      );
    }

    return _OverflowSafeLine(
      alignment: FormattedText._overflowAlignment(textAlign),
      child: Text.rich(
        TextSpan(
          style: base,
          children: FormattedText._parse(
            paragraph,
            base,
            forceDisplayMath: forceDisplayMath,
          ),
        ),
        textAlign: textAlign,
        softWrap: false,
      ),
    );
  }
}

/// Uzun formül satırlarını ekrana sığdırır veya yatay kaydırır.
class _OverflowSafeLine extends StatelessWidget {
  final Widget child;
  final Alignment alignment;
  final bool scaleDown;

  const _OverflowSafeLine({
    required this.child,
    this.alignment = Alignment.centerLeft,
    this.scaleDown = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var maxW = constraints.maxWidth;
        if (!maxW.isFinite || maxW <= 0) {
          maxW = MediaQuery.sizeOf(context).width - 40;
        }
        if (!scaleDown) {
          return SizedBox(
            width: maxW,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: child,
            ),
          );
        }
        return SizedBox(
          width: maxW,
          child: ClipRect(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: alignment,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Metin satırı — panel gibi softWrap, punto sabit.
class _WrappedExamLine extends StatelessWidget {
  final String line;
  final TextStyle base;
  final TextAlign? textAlign;

  const _WrappedExamLine({
    required this.line,
    required this.base,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();

    return Text.rich(
      TextSpan(
        style: base,
        children: FormattedText.parseSpans(trimmed, base),
      ),
      textAlign: textAlign ?? TextAlign.start,
      softWrap: true,
      textWidthBasis: TextWidthBasis.parent,
      strutStyle: FormattedText.examStrutStyle(base),
      textHeightBehavior: FormattedText.examTextHeightBehavior,
    );
  }
}

/// Tek satır: parçalı Row + FittedBox ile yatay taşmayı önler.
class _ExamLine extends StatelessWidget {
  final String line;
  final TextStyle base;
  final TextAlign? textAlign;
  final bool scaleDown;

  const _ExamLine({
    required this.line,
    required this.base,
    this.textAlign,
    this.scaleDown = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var maxW = constraints.maxWidth;
        if (!maxW.isFinite || maxW <= 0) {
          maxW = MediaQuery.sizeOf(context).width - 48;
        }

        final trimmed = line.trim();
        if (trimmed.isEmpty) return const SizedBox.shrink();

        final children = FormattedText.lineToRowChildren(trimmed, base);
        if (children.isEmpty) return const SizedBox.shrink();

        final row = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: children,
        );

        if (!scaleDown) {
          return SizedBox(
            width: maxW,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: row,
            ),
          );
        }

        return SizedBox(
          width: maxW,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: FormattedText._overflowAlignment(textAlign),
            child: row,
          ),
        );
      },
    );
  }
}

class _DocumentText extends StatelessWidget {
  final String text;
  final TextStyle base;
  final TextAlign? textAlign;
  final bool examLayout;
  final bool examScaleDown;
  final bool examWrap;

  const _DocumentText({
    required this.text,
    required this.base,
    this.textAlign,
    this.examLayout = false,
    this.examScaleDown = true,
    this.examWrap = false,
  });

  Widget _lineWidget(String content) {
    if (examWrap) {
      return _WrappedExamLine(
        line: content,
        base: base,
        textAlign: textAlign,
      );
    }
    if (examLayout) {
      return _ExamLine(
        line: content,
        base: base,
        textAlign: textAlign,
        scaleDown: examScaleDown,
      );
    }
    return _OverflowSafeLine(
      alignment: FormattedText._overflowAlignment(textAlign),
      child: Text.rich(
        TextSpan(
          style: base,
          children: FormattedText.parseSpans(content, base),
        ),
        textAlign: textAlign,
        softWrap: false,
      ),
    );
  }

  Widget _displayMathBlock(String tex) {
    final widget = FormattedText.buildMathWidget(
      tex,
      base: base,
      display: true,
    );
    if (examWrap) {
      return LayoutBuilder(
        builder: (context, constraints) {
          var maxW = constraints.maxWidth;
          if (!maxW.isFinite || maxW <= 0) {
            maxW = MediaQuery.sizeOf(context).width - 48;
          }
          return Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: widget,
              ),
            ),
          );
        },
      );
    }
    return _OverflowSafeLine(
      alignment: Alignment.center,
      scaleDown: examScaleDown,
      child: widget,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Çok satırlı $$…$$ bloklarını tek satıra birleştir (satır satır bölünmesin).
    final lines = _coalesceDisplayMathLines(
      text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n'),
    );
    final children = <Widget>[];
    final softBuf = StringBuffer();
    var firstSoftParagraph = true;

    void flushSoftParagraph() {
      final joined = softBuf
          .toString()
          .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
          .trim();
      softBuf.clear();
      if (joined.isEmpty) return;
      children.add(
        Padding(
          padding: EdgeInsets.only(
            top: examWrap && firstSoftParagraph ? 4 : 0,
            bottom: 6,
          ),
          child: _lineWidget(joined),
        ),
      );
      firstSoftParagraph = false;
    }

    bool isHardBreakLine(String trimmed) {
      if (RegExp(r'^\$\$[\s\S]+\$\$$').hasMatch(trimmed)) return true;
      final displayInline = RegExp(r'^\$([^$\n]+)\$$').firstMatch(trimmed);
      if (displayInline != null) {
        final raw = displayInline.group(1)!.trim();
        if (FormattedText.usesDisplayMath(raw)) return true;
      }
      if (RegExp(r'^(---|\*\*\*|___)$').hasMatch(trimmed)) return true;
      if (RegExp(r'^#{1,3}\s+').hasMatch(trimmed)) return true;
      if (FormattedText._isStructuralLine(trimmed)) return true;
      if (RegExp(r'^\*\*\s*\d+\.\s+Adım:.+\*\*$').hasMatch(trimmed)) {
        return true;
      }
      if (RegExp(
        r'^(?:\*\*)?(?:Payda|Pay|Kesrin değeri)\s*:',
        caseSensitive: false,
      ).hasMatch(trimmed)) {
        return true;
      }
      if (RegExp(r'^(?:\s*)(?:[-•*◦○–—]\s+)+').hasMatch(trimmed)) {
        return true;
      }
      return false;
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        flushSoftParagraph();
        children.add(const SizedBox(height: 8));
        continue;
      }

      // examWrap: soft satırları tek paragrafta birleştir → TextAlign.justify çalışır.
      if (examWrap && !isHardBreakLine(trimmed)) {
        if (softBuf.isNotEmpty) softBuf.write(' ');
        softBuf.write(trimmed);
        continue;
      }

      flushSoftParagraph();

      if (RegExp(r'^\$\$[\s\S]+\$\$$').hasMatch(trimmed)) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _displayMathBlock(
              FormattedText.prepareTex(trimmed.substring(2, trimmed.length - 2)),
            ),
          ),
        );
        continue;
      }

      final displayInline =
          RegExp(r'^\$([^$\n]+)\$$').firstMatch(trimmed);
      if (displayInline != null) {
        final raw = displayInline.group(1)!.trim();
        if (FormattedText.usesDisplayMath(raw)) {
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _displayMathBlock(FormattedText.prepareTex(raw)),
            ),
          );
          continue;
        }
      }

      if (RegExp(r'^(---|\*\*\*|___)$').hasMatch(trimmed)) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(
              height: 1,
              color: (base.color ?? Colors.white).withValues(alpha: 0.22),
            ),
          ),
        );
        continue;
      }

      if (!examLayout) {
        final headingMd = RegExp(r'^#{1,3}\s+(.+)').firstMatch(trimmed);
        final questionLike = RegExp(r'\?\s*\**$').hasMatch(trimmed) ||
            RegExp(
              r'\b(?:ifadelerinden|hangileri|yukarıdakilerden)\b',
              caseSensitive: false,
            ).hasMatch(trimmed);
        final wholeBold = !questionLike &&
            RegExp(r'^\*\*[^*][\s\S]*\*\*$').hasMatch(trimmed) &&
            trimmed.indexOf('**', 2) == trimmed.length - 2;
        final headingText =
            headingMd?.group(1) ?? (wholeBold ? trimmed : null);
        if (headingText != null) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: _OverflowSafeLine(
                alignment: FormattedText._overflowAlignment(textAlign),
                child: Text.rich(
                  TextSpan(
                    style: base.copyWith(
                      fontSize: (base.fontSize ?? 14) + 1.5,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                    children: FormattedText._parse(headingText, base),
                  ),
                  textAlign: textAlign,
                  softWrap: false,
                ),
              ),
            ),
          );
          continue;
        }
      } else {
        final headingMd = RegExp(r'^#{1,3}\s+(.+)').firstMatch(trimmed);
        if (headingMd != null) {
          var title = headingMd.group(1)!.trim();
          if (!title.startsWith('**')) title = '**$title**';
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _lineWidget(title),
            ),
          );
          continue;
        }
      }

      if (RegExp(r'^[-•*◦○–—]+$').hasMatch(line.trim())) {
        continue;
      }

      if (examLayout || examWrap) {
        final stepHdr =
            RegExp(r'^\*\*\s*\d+\.\s+Adım:.+\*\*$').hasMatch(trimmed);
        if (stepHdr) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: base),
                  Expanded(child: _lineWidget(trimmed)),
                ],
              ),
            ),
          );
          continue;
        }
      }

      final bullet = RegExp(r'^(\s*)(?:[-•*◦○–—]\s+)+(.+)').firstMatch(line);
      if (bullet != null) {
        final nested = bullet.group(1)!.replaceAll('\t', '  ').length >= 2;
        children.add(
          Padding(
            padding: EdgeInsets.only(left: nested ? 16 : 0, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nested ? '◦ ' : '• ', style: base),
                Expanded(child: _lineWidget(bullet.group(2)!)),
              ],
            ),
          ),
        );
        continue;
      }

      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _lineWidget(trimmed),
        ),
      );
    }

    flushSoftParagraph();

    if (children.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  /// Açık `$$` ile kapanış `$$` arasındaki satırları tek satırda birleştirir.
  static List<String> _coalesceDisplayMathLines(List<String> lines) {
    final out = <String>[];
    final buf = StringBuffer();
    var inDisplay = false;

    void flush() {
      if (buf.isEmpty) return;
      out.add(buf.toString());
      buf.clear();
    }

    for (final raw in lines) {
      final line = raw;
      if (!inDisplay) {
        final open = line.indexOf(r'$$');
        if (open < 0) {
          out.add(line);
          continue;
        }
        final after = line.substring(open + 2);
        final close = after.indexOf(r'$$');
        if (close >= 0) {
          out.add(line);
          continue;
        }
        inDisplay = true;
        buf.write(line.trimRight());
        continue;
      }

      buf.write(' ');
      buf.write(line.trim());
      if (line.contains(r'$$')) {
        inDisplay = false;
        flush();
      }
    }
    flush();
    return out;
  }
}
