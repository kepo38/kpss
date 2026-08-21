import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/brand_constants.dart';
import '../../models/manual_question_model.dart';
import '../../models/question_model.dart';
import '../../theme/app_theme.dart';
import '../../theme/exam_typography.dart';
import '../formatted_text.dart';
import '../question_stem_content.dart';
import '../watermark_widget.dart';

/// WhatsApp / hikâye paylaşımı için **tam ekran 9:16** filigranlı kare.
class WrongNotebookShareCard extends StatelessWidget {
  /// Hikâye / tam ekran paylaşım oranı (1080×1920).
  static const cardWidth = 1080.0;
  static const cardHeight = 1920.0;

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
      child: SizedBox(
        width: cardWidth,
        height: cardHeight,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0B1220),
                Color(0xFF121A2C),
                Color(0xFF0A101C),
              ],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const IgnorePointer(child: _ShareBackdropMark()),
              Padding(
                padding: const EdgeInsets.fromLTRB(44, 40, 44, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _ShareHeader(),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _ShareFillScaler(
                        child: bankQuestion != null
                            ? _BankBody(question: bankQuestion!)
                            : _ManualBody(item: manualQuestion!),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _ShareFooter(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// İçeriği alanın tamamına yayar: kısa soru büyür, uzun soru küçülür.
///
/// Sabit tam genişlik + FittedBox.contain ölçeği ~1’de kilitliyordu;
/// burada içerik biraz dar dizilip sonra alana sığacak şekilde büyütülür.
class _ShareFillScaler extends StatelessWidget {
  final Widget child;

  const _ShareFillScaler({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Dar layout → FittedBox yükseklik doldurana kadar büyütebilir.
        final layoutW = constraints.maxWidth * 0.72;
        return Center(
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.center,
            child: SizedBox(
              width: layoutW,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _ShareHeader extends StatelessWidget {
  const _ShareHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'HEDEF Kamu',
          textAlign: TextAlign.center,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 64,
            fontWeight: FontWeight.w700,
            height: 1.05,
            letterSpacing: 1.2,
            color: AppTheme.champagneLight,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          height: 1.2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                AppTheme.champagne.withValues(alpha: 0.55),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ShareFooter extends StatelessWidget {
  const _ShareFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 1,
          margin: const EdgeInsets.only(bottom: 12),
          color: Colors.white.withValues(alpha: 0.1),
        ),
        Text(
          BrandConstants.shareHashtag,
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: AppTheme.champagne.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          BrandConstants.appName,
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }
}

class _BankBody extends StatelessWidget {
  final QuestionModel question;

  const _BankBody({required this.question});

  @override
  Widget build(BuildContext context) {
    final keys = question.siklar.keys.toList()..sort();
    final meta = [
      if (question.dersAdi.trim().isNotEmpty) question.dersAdi.trim(),
      if (question.konuAdi.trim().isNotEmpty) question.konuAdi.trim(),
      if (question.altKonuAdi.trim().isNotEmpty) question.altKonuAdi.trim(),
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (meta.isNotEmpty) ...[
          Text(
            meta,
            style: GoogleFonts.manrope(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: AppTheme.champagne.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 20),
        ],
        QuestionStemContent(
          stem: question.soruMetni,
          imageUrl: question.imageUrl,
          sekilKodu: question.sekilKodu,
          watermarkOnText: false,
          style: ExamTypography.body(
            color: Colors.white.withValues(alpha: 0.97),
            fontSize: 36,
            height: 1.42,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (keys.isNotEmpty) ...[
          const SizedBox(height: 28),
          for (final key in keys) ...[
            _OptionRow(label: key, text: question.siklar[key] ?? ''),
            const SizedBox(height: 16),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.champagne.withValues(alpha: 0.6),
              width: 1.6,
            ),
            color: Colors.white.withValues(alpha: 0.05),
          ),
          child: Text(
            label.toUpperCase(),
            style: GoogleFonts.manrope(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.champagneLight,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FormattedText(
              text,
              textAlign: TextAlign.start,
              style: ExamTypography.option(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 32,
              ),
            ),
          ),
        ),
      ],
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${item.subjectLabel} · ${item.topicLabel}',
          style: GoogleFonts.manrope(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppTheme.champagne.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 3 / 4,
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
                    fontSize: 24,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (item.hasNote) ...[
          const SizedBox(height: 18),
          Text(
            item.noteText,
            style: GoogleFonts.manrope(
              fontSize: 26,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
        ],
      ],
    );
  }
}

/// Tek, büyük, soluk merkez filigran — dense mesh yok.
class _ShareBackdropMark extends StatelessWidget {
  const _ShareBackdropMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.rotate(
        angle: -math.pi / 4,
        child: Opacity(
          opacity: 0.07,
          child: Image.asset(
            WatermarkWidget.logoAsset,
            width: 560,
            height: 560,
            fit: BoxFit.contain,
            color: AppTheme.champagneLight,
            colorBlendMode: BlendMode.srcIn,
            errorBuilder: (_, __, ___) => Text(
              BrandConstants.appName,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 72,
                fontWeight: FontWeight.w700,
                color: AppTheme.champagneLight,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
