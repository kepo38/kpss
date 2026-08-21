import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';
import 'exam_text/exam_stem_view.dart';
import 'exam_text/option_column_layout.dart';
import 'cached_remote_image.dart';
import 'formatted_text.dart';
import 'watermark_widget.dart';

/// Soru kökünde `[HARITA]` ile görseli metnin ortasına yerleştirir.
class QuestionStemContent extends StatelessWidget {
  static const inlineImagePlaceholder = '[HARITA]';

  final String stem;
  final String? imageUrl;
  final String? sekilKodu;
  final TextStyle? style;

  /// Metin bloklarına (harita öncesi/sonrası) filigran uygula.
  /// Harita/SVG kendi overlay filigranını ayrı tutar.
  final bool watermarkOnText;

  const QuestionStemContent({
    super.key,
    required this.stem,
    this.imageUrl,
    this.sekilKodu,
    this.style,
    this.watermarkOnText = true,
  });

  static bool hasInlineImage(String stem) {
    return stem.contains(inlineImagePlaceholder);
  }

  /// Liste önizlemelerinde yer tutucuyu ve biçim işaretlerini gizler.
  static String previewText(String stem) {
    return FormattedText.stripMarkup(
      OptionColumnLayout.visibleStem(stem)
          .replaceAll(inlineImagePlaceholder, ' ')
          .replaceAll(RegExp(r'[ \t]+\n'), '\n')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim(),
    );
  }

  bool get _hasSvg => sekilKodu != null && sekilKodu!.isNotEmpty;
  bool get _hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  Widget _stemText(String text) {
    final view = ExamStemView(text: text);
    if (!watermarkOnText) return view;
    // Harita ile aynı marka; metnin arkasında ortalanmış (overlay değil).
    return WatermarkWidget(
      fitToChild: true,
      centered: true,
      child: view,
    );
  }

  @override
  Widget build(BuildContext context) {
    final parts = stem.split(inlineImagePlaceholder);
    final inline = _hasImage && parts.length > 1;

    if (!inline) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stemText(stem),
          if (_hasSvg) ...[
            const SizedBox(height: 16),
            _QuestionSvgFigure(svg: sekilKodu!),
          ] else if (_hasImage) ...[
            const SizedBox(height: 16),
            _QuestionImage(url: imageUrl!),
          ],
        ],
      );
    }

    final children = <Widget>[];
    for (var i = 0; i < parts.length; i++) {
      final chunk = parts[i].trim();
      if (chunk.isNotEmpty) {
        if (children.isNotEmpty) {
          children.add(const SizedBox(height: 12));
        }
        children.add(_stemText(chunk));
      }
      if (i < parts.length - 1) {
        if (children.isNotEmpty) {
          children.add(const SizedBox(height: 16));
        }
        children.add(_QuestionImage(url: imageUrl!));
        children.add(const SizedBox(height: 16));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _QuestionSvgFigure extends StatelessWidget {
  final String svg;

  const _QuestionSvgFigure({required this.svg});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      child: WatermarkWidget(
        overlay: true,
        fitToChild: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: ColoredBox(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SvgPicture.string(
                svg,
                width: double.infinity,
                fit: BoxFit.contain,
                semanticsLabel: 'Geometri şekli',
                placeholderBuilder: (context) => const AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.champagne),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestionImage extends StatelessWidget {
  final String url;

  const _QuestionImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      child: WatermarkWidget(
        overlay: true,
        fitToChild: true,
        child: ColoredBox(
          color: const Color(0xFFF8FAFC),
          child: AspectRatio(
            aspectRatio: 16 / 7,
            child: CachedRemoteImage(
              imageUrl: url,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.contain,
              semanticLabel: 'Soru haritası veya görseli',
            ),
          ),
        ),
      ),
    );
  }
}
