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

  const FormattedText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.preserveLineBreaks = false,
    this.paragraphLayout = false,
    this.forceDisplayMath = false,
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
    return ExamTypography.mathFrom(
      base.copyWith(
        fontSize: base.fontSize ?? 16,
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
      final inner = (m.group(1) ?? '').trim();
      return inner.isEmpty ? '' : '$marker$inner$marker';
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
    var core = inner.trim();
    if (core.isEmpty) return '';
    if (bold && italic) {
      core = '***$core***';
    } else if (bold) {
      core = '**$core**';
    } else if (italic) {
      core = '*$core*';
    }
    if (underline) core = '__${core}__';
    return core;
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

  /// `** metin **` / `__ metin __` gibi boşluklu işaretleri sıkılaştırır.
  static String _tightenMarkdownMarkers(String text) {
    var t = text;
    t = t.replaceAllMapped(
      RegExp(r'\*\*\s+(.+?)\s+\*\*', dotAll: true),
      (m) => '**${m.group(1)!.trim()}**',
    );
    t = t.replaceAllMapped(
      RegExp(r'__\s+(.+?)\s+__', dotAll: true),
      (m) => '__${m.group(1)!.trim()}__',
    );
    t = t.replaceAllMapped(
      RegExp(r'(?<!\*)\*\s+(.+?)\s+\*(?!\*)', dotAll: true),
      (m) => '*${m.group(1)!.trim()}*',
    );
    // Kapanıştan önce tek boşluk: **metin **
    t = t.replaceAllMapped(
      RegExp(r'\*\*(.+?)\s+\*\*', dotAll: true),
      (m) => '**${m.group(1)!.trim()}**',
    );
    t = t.replaceAllMapped(
      RegExp(r'__(.+?)\s+__', dotAll: true),
      (m) => '__${m.group(1)!.trim()}__',
    );
    return t;
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
    text = emphasizeSignWords(text);

    return text;
  }

  static String emphasizeSignWords(String input) {
    if (input.isEmpty) return input;
    var src = input;
    final holders = <String>[];
    src = src.replaceAllMapped(
      RegExp(r'\{(green|red|blue)\}([\s\S]+?)\{\/\1\}'),
      (m) {
        holders.add(m.group(0)!);
        return '§§C${holders.length - 1}§§';
      },
    );
    src = src.replaceAllMapped(
      RegExp(r'\bnegatif\b', caseSensitive: false),
      (m) => '{red}${m.group(0)}{/red}',
    );
    src = src.replaceAllMapped(
      RegExp(r'\bpozitif\b', caseSensitive: false),
      (m) => '{green}${m.group(0)}{/green}',
    );
    return src.replaceAllMapped(RegExp(r'§§C(\d+)§§'), (m) {
      final i = int.tryParse(m.group(1)!) ?? -1;
      if (i < 0 || i >= holders.length) return m.group(0)!;
      return holders[i];
    });
  }

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
          r'underline|begin|infty|pm|neq|leq|geq)\b',
        ).hasMatch(t) ||
        t.contains(r'^') ||
        t.contains(r'_') ||
        t.contains('{') ||
        RegExp(r'(^|[^\\A-Za-z])frac\{').hasMatch(t);
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
    var t = _repairLatexEscapes(tex.trim());
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
    src = src.replaceAllMapped(
      RegExp(r'(?<!\n)(?=\b(?:I|II|III|IV|V|VI|VII|VIII|IX|X)\.\s)'),
      (m) => '\n',
    );
    src = src.replaceAllMapped(
      RegExp(r'(§§M\d+§§)\s*(?=\*\*[a-zçğıöşüâîû])'),
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
    final fakeBold = bold
        ? <Shadow>[
            Shadow(color: color.withValues(alpha: 0.85), offset: const Offset(0.55, 0)),
            Shadow(color: color.withValues(alpha: 0.55), offset: const Offset(0.25, 0)),
          ]
        : null;

    return base.copyWith(
      color: color,
      fontWeight: bold ? FontWeight.w900 : base.fontWeight,
      fontStyle: italic ? FontStyle.italic : base.fontStyle,
      letterSpacing: bold ? (base.letterSpacing ?? 0) + 0.15 : base.letterSpacing,
      shadows: fakeBold ?? base.shadows,
      decoration: underline
          ? TextDecoration.underline
          : base.decoration,
      decorationColor: underline ? color : base.decorationColor,
      decorationThickness: underline ? 2.4 : base.decorationThickness,
      decorationStyle: underline ? TextDecorationStyle.solid : base.decorationStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final markup = normalizeMarkup(data);
    final normalized = normalizeLatex(
      preserveLineBreaks ? markup : examFormat(markup),
    );
    final laidOut = restoreCollapsedBreaks(normalized);

    if (preserveLineBreaks || laidOut.contains('\n')) {
      return _DocumentText(
        text: laidOut,
        base: base,
        textAlign: textAlign,
      );
    }

    if (paragraphLayout) {
      return _ParagraphText(
        text: laidOut,
        base: base,
        textAlign: textAlign,
        forceDisplayMath: forceDisplayMath,
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
      final tex = prepareTex((m.group(1) ?? m.group(2) ?? '').trim());
      if (tex.isNotEmpty) {
        final isBlock = m.group(1) != null;
        final display =
            forceDisplayMath || usesDisplayMath(tex);
        spans.add(
          WidgetSpan(
            alignment: isBlock && display
                ? PlaceholderAlignment.middle
                : PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: buildMathWidget(tex, base: base, display: display),
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
        spans.add(
          TextSpan(
            text: m.group(4)!,
            style: _emphasis(base, bold: true, italic: true, underline: true),
          ),
        );
      } else if (m.group(5) != null || m.group(6) != null) {
        final text = m.group(5) ?? m.group(6)!;
        spans.add(
          TextSpan(
            text: text,
            style: _emphasis(base, bold: true, underline: true),
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

  const _ParagraphText({
    required this.text,
    required this.base,
    this.textAlign,
    this.forceDisplayMath = false,
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
                child: _OverflowSafeLine(
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

/// Uzun formül satırlarını ekrana sığdırır (taşma şeridi önlenir).
class _OverflowSafeLine extends StatelessWidget {
  final Widget child;
  final Alignment alignment;

  const _OverflowSafeLine({
    required this.child,
    this.alignment = Alignment.centerLeft,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var maxW = constraints.maxWidth;
        if (!maxW.isFinite || maxW <= 0) {
          maxW = MediaQuery.sizeOf(context).width - 40;
        }
        return Align(
          alignment: alignment,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
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

class _DocumentText extends StatelessWidget {
  final String text;
  final TextStyle base;
  final TextAlign? textAlign;

  const _DocumentText({
    required this.text,
    required this.base,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final lines =
        text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    final children = <Widget>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        children.add(const SizedBox(height: 8));
        continue;
      }

      if (RegExp(r'^\$\$[\s\S]+\$\$$').hasMatch(trimmed)) {
        final tex =
            FormattedText.prepareTex(trimmed.substring(2, trimmed.length - 2));
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _OverflowSafeLine(
              alignment: Alignment.center,
              child: FormattedText.buildMathWidget(
                tex,
                base: base,
                display: true,
              ),
            ),
          ),
        );
        continue;
      }

      final displayInline =
          RegExp(r'^\$([^$\n]+)\$$').firstMatch(trimmed);
      if (displayInline != null) {
        final tex = FormattedText.prepareTex(displayInline.group(1)!.trim());
        if (FormattedText.usesDisplayMath(tex)) {
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _OverflowSafeLine(
                alignment: Alignment.center,
                child: FormattedText.buildMathWidget(
                  tex,
                  base: base,
                  display: true,
                ),
              ),
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

      final headingMd = RegExp(r'^#{1,3}\s+(.+)').firstMatch(trimmed);
      final questionLike = RegExp(r'\?\s*\**$').hasMatch(trimmed) ||
          RegExp(
            r'\b(?:ifadelerinden|hangileri|yukarıdakilerden)\b',
            caseSensitive: false,
          ).hasMatch(trimmed);
      final wholeBold = !questionLike &&
          RegExp(r'^\*\*[^*][\s\S]*\*\*$').hasMatch(trimmed) &&
          trimmed.indexOf('**', 2) == trimmed.length - 2;
      final headingText = headingMd?.group(1) ?? (wholeBold ? trimmed : null);
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

      final bullet = RegExp(r'^(\s*)[-•*◦○–—]\s+(.+)').firstMatch(line);
      if (bullet != null) {
        final nested = bullet.group(1)!.replaceAll('\t', '  ').length >= 2;
        children.add(
          Padding(
            padding: EdgeInsets.only(left: nested ? 16 : 0, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nested ? '◦ ' : '• ', style: base),
                Expanded(
                  child: _OverflowSafeLine(
                    alignment: FormattedText._overflowAlignment(textAlign),
                    child: Text.rich(
                      TextSpan(
                        style: base,
                        children: FormattedText._parse(bullet.group(2)!, base),
                      ),
                      textAlign: textAlign,
                      softWrap: false,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _OverflowSafeLine(
            alignment: FormattedText._overflowAlignment(textAlign),
            child: Text.rich(
              TextSpan(
                style: base,
                children: FormattedText._parse(trimmed, base),
              ),
              textAlign: textAlign,
              softWrap: false,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
