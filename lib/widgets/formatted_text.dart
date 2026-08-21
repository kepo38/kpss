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
    return examFormat(normalizeMarkup(input))
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .trim();
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

  static TextStyle mathTextStyle(TextStyle base, {required bool display}) {
    final size = base.fontSize ?? 16;
    return ExamTypography.mathFrom(
      base.copyWith(
        fontSize: display ? size * 1.18 : size,
        height: display ? 1.28 : base.height,
        color: base.color,
      ),
    );
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
    final sized = prepareTex(tex, forceDisplayStyle: display);
    return Math.tex(
      sized,
      textStyle: mathTextStyle(base, display: display),
      mathStyle: display ? MathStyle.display : MathStyle.text,
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

    src = src.replaceAllMapped(
      RegExp(r'§§E(\d+)§§'),
      (m) {
        final i = int.tryParse(m.group(1)!) ?? -1;
        if (i < 0 || i >= holders.length) return m.group(0)!;
        return holders[i];
      },
    );
    return src;
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
    var out = text
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
    if (out.contains('frac') && !out.contains(r'\frac')) {
      out = out.replaceAllMapped(
        RegExp(r'(^|[^\\A-Za-z])frac\{'),
        (m) => '${m.group(1)}\\frac{',
      );
    }
    return out;
  }

  static bool looksLikeMath(String input) {
    final t = input.trim();
    if (t.isEmpty) return false;
    return RegExp(
          r'\\(?:frac|dfrac|tfrac|sqrt|cdot|times|left|right|text|overline|'
          r'underline|begin|infty|pm|neq|leq|geq|displaystyle|hline)\b',
        ).hasMatch(t) ||
        t.contains(r'^') ||
        t.contains(r'_') ||
        t.contains('{') ||
        RegExp(r'(^|[^\\A-Za-z])frac\{').hasMatch(t) ||
        // $A + B + C$ gibi basit cebir (Yalnız I düz metin kalsın)
        RegExp(r'[A-Za-z0-9]\s*[+\-=≠≤≥×·]\s*[A-Za-z0-9]').hasMatch(t);
  }

  static String wrapBareLatex(String input) {
    var src = _repairLatexEscapes(input.trim());
    if (src.isEmpty) return src;
    final display = RegExp(r'^\$\$([\s\S]+)\$\$$').firstMatch(src);
    if (display != null) {
      final inner = display.group(1)!.trim();
      return looksLikeMath(inner) ? src : inner;
    }
    final wrapped = RegExp(r'^\$([^$]+)\$').firstMatch(src);
    if (wrapped != null) {
      final inner = wrapped.group(1)!.trim();
      return looksLikeMath(inner) ? src : inner;
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

  /// ÖSYM kitapçığı: \\tfrac / \\over → \\frac; displaystyle yalnızca kesir vb. için.
  static String forceDisplaySizeAll(String tex, {bool forceDisplayStyle = true}) {
    var t = tex.trim();
    if (t.isEmpty) return t;
    t = t.replaceAll(r'\tfrac', r'\frac');
    t = t.replaceAll(r'\dfrac', r'\frac');
    t = t.replaceAll(r'\ttfrac', r'\frac');
    t = t.replaceAll(r'\ddfrac', r'\frac');
    t = t.replaceAllMapped(
      RegExp(r'\{([^{}]+)\\over\s*([^{}]+)\}'),
      (m) => '\\frac{${m.group(1)!.trim()}}{${m.group(2)!.trim()}}',
    );
    final isTabular = t.contains(r'\begin{array}') ||
        t.contains(r'\begin{matrix}') ||
        t.contains(r'\begin{pmatrix}');
    if (forceDisplayStyle &&
        !isTabular &&
        !RegExp(r'\\displaystyle\b').hasMatch(t)) {
      t = r'\displaystyle ' + t;
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
    var text = input
        .replaceAllMapped(
          RegExp(r'\\\[([\s\S]+?)\\\]'),
          (m) => r'$$' + m.group(1)!.trim() + r'$$',
        )
        .replaceAllMapped(
          RegExp(r'\\\((.+?)\\\)'),
          (m) => r'$' + m.group(1)!.trim() + r'$',
        );
    return text;
  }

  static String restoreCollapsedBreaks(String input) {
    if (input.isEmpty) return input;
    var src = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final holders = <String>[];
    src = src.replaceAllMapped(
      RegExp(r'\$\$[\s\S]+?\$\$|\$[^$\n]+\$'),
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
      RegExp(r'(?<!\n)(\d+\.\s+Adım)'),
      (m) => '\n${m.group(1)}',
    );
    src = src.replaceAllMapped(
      RegExp(r'(göre\*{0,2})(?!\n)(?=\s+(?:I|II|III|IV|V)\.)'),
      (m) => '${m.group(1)}\n',
    );
    // Yalnızca gerçek madde listesi: en az iki FARKLI Romen (I. + II. …).
    // "III. Selim … III. Selim Dönemi" gibi aynı rakam tekrarına dokunma.
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
    src = src.replaceAllMapped(
      RegExp(r'§§K(\d+)§§'),
      (m) {
        final i = int.tryParse(m.group(1)!) ?? -1;
        if (i < 0 || i >= mdHolders.length) return m.group(0)!;
        return mdHolders[i];
      },
    );
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
      RegExp(r'§§M(\d+)§§'),
      (m) {
        final i = int.tryParse(m.group(1)!) ?? -1;
        if (i < 0 || i >= holders.length) return m.group(0)!;
        return holders[i];
      },
    );
    src = src.replaceAllMapped(
      RegExp(r'(\$)(?=[A-ZÇĞİÖŞÜÂÎÛ][a-zçğıöşüâîû])'),
      (m) => '${m.group(1)}\n',
    );
    src = src.replaceAllMapped(
      RegExp(r'(\$)\s*(?=\*\*[a-zçğıöşüâîû])'),
      (m) => '${m.group(1)}\n',
    );
    return src.replaceAll(RegExp(r'\n{3,}'), '\n\n').replaceFirst(RegExp(r'^\n+'), '');
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
    final markup = normalizeMarkup(data);
    final normalized = normalizeLatex(
      preserveLineBreaks ? markup : examFormat(markup),
    );
    final laidOut = restoreCollapsedBreaks(normalized);
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
        final isBlock = m.group(1) != null;
        final display =
            forceDisplayMath || isBlock || usesDisplayMath(raw);
        spans.add(
          WidgetSpan(
            alignment: isBlock && display
                ? PlaceholderAlignment.middle
                : PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: buildMathWidget(raw, base: base, display: display),
          ),
        );
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
          crossAxisAlignment: CrossAxisAlignment.center,
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

    void flushSoftParagraph() {
      final joined = softBuf
          .toString()
          .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
          .trim();
      softBuf.clear();
      if (joined.isEmpty) return;
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _lineWidget(joined),
        ),
      );
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
