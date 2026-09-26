import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';
import 'exam_text/exam_stem_view.dart';
import 'exam_text/option_column_layout.dart';
import 'cached_remote_image.dart';
import 'formatted_text.dart';
import 'watermark_widget.dart';

/// Soru kökünde `[HARITA]` / `[ŞEKİL]` ile görseli metnin ortasına yerleştirir.
class QuestionStemContent extends StatelessWidget {
  static const inlineImagePlaceholder = '[HARITA]';
  static const inlineFigurePlaceholder = '[ŞEKİL]';

  final String stem;
  final String? imageUrl;
  final String stemImagePosition;
  final String? sekilKodu;
  final TextStyle? style;

  /// Metin bloklarına (harita öncesi/sonrası) filigran uygula.
  /// Harita/SVG kendi overlay filigranını ayrı tutar.
  final bool watermarkOnText;

  const QuestionStemContent({
    super.key,
    required this.stem,
    this.imageUrl,
    this.stemImagePosition = 'below',
    this.sekilKodu,
    this.style,
    this.watermarkOnText = true,
  });

  static bool hasInlineImage(String stem) {
    return stem.contains(inlineImagePlaceholder);
  }

  static bool hasInlineFigure(String text) {
    return text.contains(inlineFigurePlaceholder);
  }

  /// Liste önizlemelerinde yer tutucuyu ve biçim işaretlerini gizler.
  static String previewText(String stem) {
    return FormattedText.stripMarkup(
      OptionColumnLayout.visibleStem(stem)
          .replaceAll(inlineImagePlaceholder, ' ')
          .replaceAll(inlineFigurePlaceholder, ' ')
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

  bool get _imageAbove => stemImagePosition == 'above';

  /// Bir metin parçasını `[HARITA]` ile (varsa) böler.
  List<Widget> _widgetsForTextChunk(String chunk) {
    final parts = chunk.split(inlineImagePlaceholder);
    final inlineMap = _hasImage && parts.length > 1;
    final out = <Widget>[];

    if (!inlineMap) {
      final trimmed = chunk.trim();
      if (trimmed.isNotEmpty) {
        out.add(_stemText(trimmed));
      }
      return out;
    }

    for (var i = 0; i < parts.length; i++) {
      final text = parts[i].trim();
      if (text.isNotEmpty) {
        if (out.isNotEmpty) {
          out.add(const SizedBox(height: 12));
        }
        out.add(_stemText(text));
      }
      if (i < parts.length - 1) {
        if (out.isNotEmpty) {
          out.add(const SizedBox(height: 16));
        }
        out.add(_QuestionImage(url: imageUrl!));
        out.add(const SizedBox(height: 16));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final figureParts = stem.split(inlineFigurePlaceholder);
    final inlineFigure = _hasSvg && figureParts.length > 1;

    if (inlineFigure) {
      final children = <Widget>[];
      for (var i = 0; i < figureParts.length; i++) {
        final chunkWidgets = _widgetsForTextChunk(figureParts[i]);
        if (chunkWidgets.isNotEmpty) {
          if (children.isNotEmpty) {
            children.add(const SizedBox(height: 12));
          }
          children.addAll(chunkWidgets);
        }
        if (i < figureParts.length - 1) {
          if (children.isNotEmpty) {
            children.add(const SizedBox(height: 16));
          }
          children.add(QuestionSvgFigure(svg: sekilKodu!));
          children.add(const SizedBox(height: 16));
        }
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    }

    final mapParts = stem.split(inlineImagePlaceholder);
    final inlineMap = _hasImage && mapParts.length > 1;
    final showSvgBelow =
        _hasSvg && !stem.contains(inlineFigurePlaceholder);

    if (!inlineMap) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_imageAbove && _hasImage) _QuestionImage(url: imageUrl!),
          if (_imageAbove && _hasImage) const SizedBox(height: 16),
          _stemText(stem),
          if (showSvgBelow) ...[
            const SizedBox(height: 16),
            QuestionSvgFigure(svg: sekilKodu!),
          ] else if (!_imageAbove && _hasImage) ...[
            const SizedBox(height: 16),
            _QuestionImage(url: imageUrl!),
          ],
        ],
      );
    }

    final children = <Widget>[];
    for (var i = 0; i < mapParts.length; i++) {
      final chunk = mapParts[i].trim();
      if (chunk.isNotEmpty) {
        if (children.isNotEmpty) {
          children.add(const SizedBox(height: 12));
        }
        children.add(_stemText(chunk));
      }
      if (i < mapParts.length - 1) {
        if (children.isNotEmpty) {
          children.add(const SizedBox(height: 16));
        }
        children.add(_QuestionImage(url: imageUrl!));
        children.add(const SizedBox(height: 16));
      }
    }
    if (showSvgBelow) {
      children.add(const SizedBox(height: 16));
      children.add(QuestionSvgFigure(svg: sekilKodu!));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

/// Geometri SVG şekli (soru kökü veya çözüm içinde).
class QuestionSvgFigure extends StatelessWidget {
  final String svg;

  const QuestionSvgFigure({super.key, required this.svg});

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
