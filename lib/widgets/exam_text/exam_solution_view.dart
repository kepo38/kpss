import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/exam_typography.dart';
import '../cached_remote_image.dart';
import '../formatted_text.dart';
import '../question_stem_content.dart';

/// Çözüm metni — 15pt, wrap (yatay kesilme yok).
class ExamSolutionView extends StatelessWidget {
  final String text;

  const ExamSolutionView({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return FormattedText(
      text,
      preNormalized: true,
      preserveLineBreaks: true,
      examLayout: true,
      examWrap: true,
      examScaleDown: false,
      solutionMode: true,
      style: ExamTypography.solution(
        color: Colors.white.withValues(alpha: 0.92),
        fontSize: 15,
      ),
    );
  }
}

/// Çözüm metni + isteğe bağlı annotasyon görseli (`cozumImageUrl`).
///
/// Soru gövdesiyle aynı kural: `sekilKodu` (SVG) varsa PNG üstte gösterilmez;
/// `[ŞEKİL]` yoksa SVG metnin altında gelir.
class ExamSolutionBlock extends StatelessWidget {
  final String text;
  final String? imageUrl;
  final String? sekilKodu;

  const ExamSolutionBlock({
    super.key,
    required this.text,
    this.imageUrl,
    this.sekilKodu,
  });

  bool get _hasImage {
    final url = imageUrl?.trim();
    return url != null && url.isNotEmpty;
  }

  bool get _hasSvg {
    final svg = sekilKodu?.trim();
    return svg != null && svg.isNotEmpty;
  }

  Future<void> _openImageViewer(BuildContext context, String url) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (dialogContext) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ),
                Expanded(
                  child: InteractiveViewer(
                    minScale: 0.75,
                    maxScale: 4,
                    child: Center(
                      child: CachedRemoteImage(
                        imageUrl: url,
                        fit: BoxFit.contain,
                        semanticLabel: 'Çözüm görseli büyütülmüş',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _annotatedImage(BuildContext context, String url) {
    final width = MediaQuery.sizeOf(context).width;
    final imageMaxHeight = (width * 0.72).clamp(220.0, 420.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Şekil üzerinde işaretli çözüm',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            color: AppTheme.champagne.withValues(alpha: 0.88),
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openImageViewer(context, url),
            borderRadius: BorderRadius.circular(10),
            child: Ink(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.champagne.withValues(alpha: 0.22),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: width - 72,
                        maxHeight: imageMaxHeight,
                      ),
                      child: CachedRemoteImage(
                        imageUrl: url,
                        fit: BoxFit.contain,
                        borderRadius: BorderRadius.circular(8),
                        semanticLabel: 'Çözüm görseli',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.zoom_in_rounded,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Büyütmek için dokun',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.white.withValues(alpha: 0.62),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _solutionBody() {
    final svg = sekilKodu?.trim();
    final placeholder = QuestionStemContent.inlineFigurePlaceholder;
    final inlineFigure = _hasSvg && text.contains(placeholder);
    if (!inlineFigure) {
      final children = <Widget>[];
      final trimmed = text.trim();
      if (trimmed.isNotEmpty) {
        children.add(ExamSolutionView(text: trimmed));
      }
      // Stem ile aynı: [ŞEKİL] yoksa SVG metnin altında.
      if (_hasSvg) {
        if (children.isNotEmpty) {
          children.add(const SizedBox(height: 16));
        }
        children.add(QuestionSvgFigure(svg: svg!));
      }
      if (children.isEmpty) {
        return const SizedBox.shrink();
      }
      if (children.length == 1) {
        return children.first;
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    }

    final parts = text.split(placeholder);
    final children = <Widget>[];
    for (var i = 0; i < parts.length; i++) {
      final chunk = parts[i].trim();
      if (chunk.isNotEmpty) {
        if (children.isNotEmpty) {
          children.add(const SizedBox(height: 12));
        }
        children.add(ExamSolutionView(text: chunk));
      }
      if (i < parts.length - 1) {
        if (children.isNotEmpty) {
          children.add(const SizedBox(height: 16));
        }
        children.add(QuestionSvgFigure(svg: svg!));
        children.add(const SizedBox(height: 16));
      }
    }
    if (children.isEmpty) {
      return QuestionSvgFigure(svg: svg!);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    // Vektör şekil varken eski OCR annotasyon PNG'sini gösterme (soru/çözüm uyumsuzluğu).
    final showAnnotatedPng = _hasImage && url != null && !_hasSvg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showAnnotatedPng) ...[
          _annotatedImage(context, url),
          if (text.trim().isNotEmpty || _hasSvg) const SizedBox(height: 14),
        ],
        _solutionBody(),
      ],
    );
  }
}
