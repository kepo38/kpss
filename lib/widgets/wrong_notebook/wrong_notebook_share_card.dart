import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/brand_constants.dart';
import '../../models/manual_question_model.dart';
import '../../models/question_model.dart';
import '../../theme/app_theme.dart';
import '../brand_mark.dart';
import '../formatted_text.dart';
import '../question_stem_content.dart';
import '../watermark_widget.dart';

/// Paylaşım için render edilen filigranlı soru kartı (ekran görüntüsü kaynağı).
class WrongNotebookShareCard extends StatelessWidget {
  static const cardWidth = 720.0;

  final QuestionModel? bankQuestion;
  final ManualQuestionModel? manualQuestion;

  const WrongNotebookShareCard.bank({
    super.key,
    required QuestionModel question,
  })  : bankQuestion = question,
        manualQuestion = null;

  const WrongNotebookShareCard.manual({
    super.key,
    required ManualQuestionModel item,
  })  : manualQuestion = item,
        bankQuestion = null;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: cardWidth,
        decoration: BoxDecoration(
          color: const Color(0xFF0E1524),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppTheme.champagne.withValues(alpha: 0.42),
            width: 1.2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
              child: Stack(
                children: [
                  bankQuestion != null
                      ? _BankBody(question: bankQuestion!)
                      : _ManualBody(item: manualQuestion!),
                  const Positioned.fill(
                    child: IgnorePointer(child: _ShareWatermarkMesh()),
                  ),
                ],
              ),
            ),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.champagne.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.04),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.champagne.withValues(alpha: 0.28),
          ),
        ),
      ),
      child: Row(
        children: [
          const BrandMark(dark: true, logoSize: 36, compact: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  BrandConstants.appName.toUpperCase(),
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: AppTheme.champagneLight,
                  ),
                ),
                Text(
                  'Yanlış defteri · paylaşım',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppTheme.champagne.withValues(alpha: 0.22),
          ),
        ),
      ),
      child: Text(
        '${BrandConstants.appName}  ·  ${BrandConstants.shareHashtag}',
        textAlign: TextAlign.center,
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: AppTheme.champagne.withValues(alpha: 0.72),
        ),
      ),
    );
  }
}

class _BankBody extends StatelessWidget {
  final QuestionModel question;

  const _BankBody({required this.question});

  @override
  Widget build(BuildContext context) {
    final keys = question.siklar.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (question.dersAdi.trim().isNotEmpty ||
            question.konuAdi.trim().isNotEmpty) ...[
          Text(
            [
              if (question.dersAdi.trim().isNotEmpty) question.dersAdi.trim(),
              if (question.konuAdi.trim().isNotEmpty) question.konuAdi.trim(),
            ].join(' · '),
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.champagne.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 10),
        ],
        QuestionStemContent(
          stem: question.soruMetni,
          imageUrl: question.imageUrl,
          sekilKodu: question.sekilKodu,
          watermarkOnText: false,
          style: GoogleFonts.manrope(
            fontSize: 16.5,
            height: 1.45,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.96),
          ),
        ),
        if (keys.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final key in keys) ...[
            _OptionRow(label: key, text: question.siklar[key] ?? ''),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

class _OptionRow extends StatelessWidget {
  final String label;
  final String text;

  const _OptionRow({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label)',
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.champagneLight,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FormattedText(
              text,
              style: GoogleFonts.manrope(
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualBody extends StatelessWidget {
  final ManualQuestionModel item;

  const _ManualBody({required this.item});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${item.subjectLabel} · ${item.topicLabel}',
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.champagne.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Image.file(
              File(item.imagePath),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.white.withValues(alpha: 0.06),
                alignment: Alignment.center,
                child: Text(
                  'Görsel yüklenemedi',
                  style: GoogleFonts.manrope(
                    color: Colors.white54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (item.hasNote) ...[
          const SizedBox(height: 12),
          Text(
            item.noteText,
            style: GoogleFonts.manrope(
              fontSize: 14,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
        ],
      ],
    );
  }
}

/// Paylaşım görselinde kopyalamayı zorlaştıran tekrarlı filigran ağı.
class _ShareWatermarkMesh extends StatelessWidget {
  const _ShareWatermarkMesh();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        if (!box.hasBoundedWidth ||
            !box.hasBoundedHeight ||
            box.maxWidth <= 0 ||
            box.maxHeight <= 0) {
          return const SizedBox.shrink();
        }
        const mark = 110.0;
        final cols = math.max(2, (box.maxWidth / 160).ceil());
        final rows = math.max(2, (box.maxHeight / 140).ceil());
        return Stack(
          children: [
            for (var r = 0; r < rows; r++)
              for (var c = 0; c < cols; c++)
                Positioned(
                  left: c * (box.maxWidth / cols) + (r.isOdd ? 28 : 0),
                  top: r * (box.maxHeight / rows) + 8,
                  child: Transform.rotate(
                    angle: -math.pi / 4,
                    child: Opacity(
                      opacity: 0.16,
                      child: Image.asset(
                        WatermarkWidget.logoAsset,
                        width: mark,
                        height: mark,
                        fit: BoxFit.contain,
                        color: AppTheme.champagneLight,
                        colorBlendMode: BlendMode.srcIn,
                        errorBuilder: (_, __, ___) => Text(
                          BrandConstants.appName,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.champagneLight,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}
