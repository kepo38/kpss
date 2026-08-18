import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';
import '../theme/exam_typography.dart';
import 'cached_remote_image.dart';
import 'formatted_text.dart';

/// Soru kökünde `[HARITA]` ile görseli metnin ortasına yerleştirir.
class QuestionStemContent extends StatelessWidget {
  static const inlineImagePlaceholder = '[HARITA]';

  final String stem;
  final String? imageUrl;
  final String? sekilKodu;
  final TextStyle? style;

  const QuestionStemContent({
    super.key,
    required this.stem,
    this.imageUrl,
    this.sekilKodu,
    this.style,
  });

  static bool hasInlineImage(String stem) {
    return stem.contains(inlineImagePlaceholder);
  }

  /// Liste önizlemelerinde yer tutucuyu ve biçim işaretlerini gizler.
  static String previewText(String stem) {
    return FormattedText.stripMarkup(
      stem
          .replaceAll(inlineImagePlaceholder, ' ')
          .replaceAll(RegExp(r'[ \t]+\n'), '\n')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim(),
    );
  }

  bool get _hasSvg => sekilKodu != null && sekilKodu!.isNotEmpty;
  bool get _hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ??
        ExamTypography.body(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w500,
          height: 1.5,
        );

    final parts = stem.split(inlineImagePlaceholder);
    final inline = _hasImage && parts.length > 1;

    if (!inline) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FormattedText(
            stem,
            preserveLineBreaks: true,
            textAlign: TextAlign.start,
            style: baseStyle,
          ),
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
        children.add(
          FormattedText(
            chunk,
            preserveLineBreaks: true,
            textAlign: TextAlign.start,
            style: baseStyle,
          ),
        );
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: ColoredBox(
          color: Colors.white,
          child: CachedRemoteImage(
            imageUrl: url,
            width: double.infinity,
            height: 220,
            fit: BoxFit.contain,
            semanticLabel: 'Soru haritası veya görseli',
          ),
        ),
      ),
    );
  }
}
