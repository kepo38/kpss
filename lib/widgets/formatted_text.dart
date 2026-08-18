import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

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

  static String examFormat(String input) {
    if (input.isEmpty) return input;

    final buffer = StringBuffer();
    final displayRe = RegExp(r'\$\$[\s\S]+?\$\$');
    var cursor = 0;

    void appendFormattedText(String chunk) {
      if (chunk.trim().isEmpty) return;
      final paras = chunk
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n')
          .split(RegExp(r'\n\s*\n+'))
          .map(
            (p) => p
                .replaceAll(RegExp(r'[ \t]*\n[ \t]*'), ' ')
                .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
                .trim(),
          )
          .where((p) => p.isNotEmpty);
      for (final p in paras) {
        if (buffer.isNotEmpty) buffer.write('\n\n');
        buffer.write(p);
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
    final size = base.fontSize ?? 16;
    final scale = display ? 1.55 : 1.48;
    return base.copyWith(fontSize: size * scale);
  }

  static Widget buildMathWidget(
    String tex, {
    required TextStyle base,
    required bool display,
  }) {
    final sized = forceDisplaySizeAll(tex);
    return Math.tex(
      sized,
      textStyle: mathTextStyle(base, display: true),
      mathStyle: MathStyle.display,
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

    return text;
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

  static String wrapBareLatex(String input) {
    var src = _repairLatexEscapes(input.trim());
    if (src.isEmpty) return src;
    if (src.contains(r'$') || src.contains(r'\(') || src.contains(r'\[')) {
      return src;
    }
    return '\$${src}\$';
  }

  /// ÖSYM kitapçığı: \tfrac / \over → \frac, tüm formüle \displaystyle.
  /// Dolar işaretine replaceAll uygulanmaz; kapanış $ bozulur.
  static String forceDisplaySizeAll(String tex) {
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
    if (!RegExp(r'\\displaystyle\b').hasMatch(t)) {
      t = r'\displaystyle ' + t;
    }
    return t;
  }

  static String prepareTex(String tex) {
    var t = _repairLatexEscapes(tex.trim());
    t = t.replaceAllMapped(
      RegExp(
        r'\\+(sqrt|frac|dfrac|tfrac|cdot|times|left|right|text|overline|underline|pi|alpha|beta|gamma|theta|leq|geq|neq|pm|mp|infty|sum|int|log|sin|cos|tan|begin|end|array|hline|matrix|displaystyle)',
      ),
      (m) => '\\${m.group(1)}',
    );
    return forceDisplaySizeAll(t);
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
    return src.replaceAll(RegExp(r'\n{3,}'), '\n\n');
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
    final laidOut =
        preserveLineBreaks ? restoreCollapsedBreaks(normalized) : normalized;

    if (preserveLineBreaks) {
      return _DocumentText(
        text: laidOut,
        base: base,
        textAlign: textAlign,
      );
    }

    if (paragraphLayout) {
      return _ParagraphText(
        text: normalized,
        base: base,
        textAlign: textAlign,
        forceDisplayMath: forceDisplayMath,
      );
    }

    return Text.rich(
      TextSpan(
        style: base,
        children: _parse(
          normalized,
          base,
          forceDisplayMath: forceDisplayMath,
        ),
      ),
      textAlign: textAlign,
    );
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
        final display =
            forceDisplayMath || m.group(1) != null || usesDisplayMath(tex);
        spans.add(
          WidgetSpan(
            alignment: display
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
        child: Center(
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
              child: Center(
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
                ),
              ),
          ],
        );
      }
    }

    return Text.rich(
      TextSpan(
        style: base,
        children: FormattedText._parse(
          paragraph,
          base,
          forceDisplayMath: forceDisplayMath,
        ),
      ),
      textAlign: textAlign,
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
            child: Center(
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

      final bullet = RegExp(r'^[-•*–—]\s+(.+)').firstMatch(trimmed);
      if (bullet != null) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: base),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: base,
                      children: FormattedText._parse(bullet.group(1)!, base),
                    ),
                    textAlign: textAlign,
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
          child: Text.rich(
            TextSpan(style: base, children: FormattedText._parse(trimmed, base)),
            textAlign: textAlign,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
