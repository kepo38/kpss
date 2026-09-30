import 'package:flutter/material.dart';

import '../utils/line_break_hyphens.dart';

/// Hece sınırı işaretli (U+00AD) metni çizer; görünür `-` yalnızca gerçekten
/// satır sonuna düşen hecelerde çıkar.
///
/// Ölçüm, ekrandaki `Text.rich` ile aynı parametrelerle yapılır:
///  * kök stil = `DefaultTextStyle` (+ "kalın yazı" erişilebilirlik ayarı)
///  * yazı ölçeği, yerel ayar, hizalama, strut, yükseklik davranışı
///  * gerçek `TextSpan` ağacı (kalın / altı çizili parçalar dahil)
///
/// Yazı tipi çalışma anında yüklenen bir yazı tipiyse (GoogleFonts) ilk
/// karelerde yedek yazı tipiyle ölçülür; yazı tipi yüklendiğinde satır
/// kırılmaları değişir. Bu yüzden sistem yazı tipi değişimi dinlenir ve
/// çözüm yeniden hesaplanır — aksi halde eski ölçümden kalan tireler
/// satır ortasında kalırdı.
class LineBreakHyphenText extends StatefulWidget {
  const LineBreakHyphenText({
    super.key,
    required this.style,
    required this.children,
    this.textAlign = TextAlign.start,
    this.strutStyle,
    this.textHeightBehavior,
    this.textWidthBasis = TextWidthBasis.parent,
  });

  /// `TextSpan(style: style, children: children)` olarak çizilir.
  final TextStyle style;
  final List<InlineSpan> children;
  final TextAlign textAlign;
  final StrutStyle? strutStyle;
  final TextHeightBehavior? textHeightBehavior;
  final TextWidthBasis textWidthBasis;

  @override
  State<LineBreakHyphenText> createState() => _LineBreakHyphenTextState();
}

class _LineBreakHyphenTextState extends State<LineBreakHyphenText> {
  int _fontEpoch = 0;

  // Son çözümün girdisi ve sonucu (aynı girdide tekrar ölçmemek için).
  String? _cacheKey;
  List<InlineSpan>? _cacheResult;

  @override
  void initState() {
    super.initState();
    PaintingBinding.instance.systemFonts.addListener(_onFontsChanged);
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_onFontsChanged);
    super.dispose();
  }

  void _onFontsChanged() {
    if (!mounted) return;
    setState(() {
      _fontEpoch++;
      _cacheKey = null;
    });
  }

  static String _plain(List<InlineSpan> spans) =>
      TextSpan(children: spans).toPlainText(includeSemanticsLabels: false);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var maxW = constraints.maxWidth;
        if (!maxW.isFinite || maxW <= 0) {
          maxW = MediaQuery.sizeOf(context).width - 48;
        }

        // Text.rich'in kök stili: DefaultTextStyle.merge(null) + kalın metin.
        final defaults = DefaultTextStyle.of(context);
        var rootStyle = defaults.style;
        if (MediaQuery.boldTextOf(context)) {
          rootStyle = rootStyle.merge(
            const TextStyle(fontWeight: FontWeight.bold),
          );
        }
        final scaler = MediaQuery.textScalerOf(context);
        final locale = Localizations.maybeLocaleOf(context);
        final direction = Directionality.of(context);

        // Ölçülen ağaç, çizilecek ağaçla aynı olmalı: iç TextSpan(style: base).
        final source = <InlineSpan>[
          TextSpan(style: widget.style, children: widget.children),
        ];

        final key = [
          _plain(source),
          maxW,
          scaler,
          locale,
          direction,
          widget.textAlign,
          widget.textWidthBasis,
          widget.style,
          rootStyle,
          widget.strutStyle,
          widget.textHeightBehavior,
          _fontEpoch,
        ].join('|');

        List<InlineSpan> resolved;
        if (_cacheKey == key && _cacheResult != null) {
          resolved = _cacheResult!;
        } else {
          resolved = LineBreakHyphens.resolve(
            children: source,
            rootStyle: rootStyle,
            maxWidth: maxW,
            textDirection: direction,
            textAlign: widget.textAlign,
            textScaler: scaler,
            locale: locale,
            strutStyle: widget.strutStyle,
            textHeightBehavior: widget.textHeightBehavior,
            textWidthBasis: widget.textWidthBasis,
          );
          _cacheKey = key;
          _cacheResult = resolved;
        }

        return Text.rich(
          resolved.first,
          textAlign: widget.textAlign,
          softWrap: true,
          textWidthBasis: widget.textWidthBasis,
          strutStyle: widget.strutStyle,
          textHeightBehavior: widget.textHeightBehavior,
        );
      },
    );
  }
}

