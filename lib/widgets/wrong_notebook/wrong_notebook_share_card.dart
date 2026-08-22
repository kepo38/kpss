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
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _PremiumAtmosphere(),
            const IgnorePointer(child: _ShareBackdropMark()),
            Padding(
              padding: const EdgeInsets.fromLTRB(48, 82, 48, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _ShareHeader(),
                  const SizedBox(height: 14),
                  Expanded(
                    child: _ShareFillScaler(
                      child: bankQuestion != null
                          ? _BankBody(question: bankQuestion!)
                          : _ManualBody(item: manualQuestion!),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _ShareFooter(),
                ],
              ),
            ),
            // İnce şampanya kenar çerçevesi — premium “basılı kâğıt” hissi.
            IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppTheme.champagne.withValues(alpha: 0.28),
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppTheme.champagneLight.withValues(alpha: 0.12),
                      width: 0.8,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumAtmosphere extends StatelessWidget {
  const _PremiumAtmosphere();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0E1829),
                Color(0xFF0A101C),
                Color(0xFF121C30),
                Color(0xFF080D16),
              ],
              stops: [0.0, 0.35, 0.72, 1.0],
            ),
          ),
        ),
        // Üst ışık — marka bölgesini öne çıkarır.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.85),
              radius: 1.15,
              colors: [
                AppTheme.champagne.withValues(alpha: 0.16),
                AppTheme.champagne.withValues(alpha: 0.04),
                Colors.transparent,
              ],
              stops: const [0.0, 0.35, 1.0],
            ),
          ),
        ),
        // Alt vignette.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.18),
                Colors.black.withValues(alpha: 0.45),
              ],
              stops: const [0.55, 0.82, 1.0],
            ),
          ),
        ),
        // Soft köşe ışımaları.
        Positioned(
          left: -120,
          bottom: 180,
          child: Container(
            width: 340,
            height: 340,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF1A2A48).withValues(alpha: 0.55),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: -100,
          top: 420,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.champagne.withValues(alpha: 0.07),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// İçeriği alanın tamamına yayar: kısa soru büyür, uzun soru küçülür.
class _ShareFillScaler extends StatelessWidget {
  final Widget child;

  const _ShareFillScaler({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layoutW = constraints.maxWidth * 0.78;
        return Align(
          alignment: Alignment.topCenter,
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.topCenter,
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
        const SizedBox(height: 10),
        Text(
          '◆',
          style: TextStyle(
            fontSize: 18,
            height: 1,
            color: AppTheme.champagne.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          BrandConstants.brandLine1,
          textAlign: TextAlign.center,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 72,
            fontWeight: FontWeight.w700,
            height: 0.92,
            letterSpacing: 10,
            color: Colors.white.withValues(alpha: 0.98),
          ),
        ),
        Text(
          BrandConstants.brandLine2,
          textAlign: TextAlign.center,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 46,
            fontWeight: FontWeight.w600,
            height: 1.05,
            letterSpacing: 14,
            color: AppTheme.champagneLight,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(child: _OrnamentLine(fadeLeft: true)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'YANLIŞ DEFTERİ',
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3.2,
                  color: AppTheme.champagne.withValues(alpha: 0.78),
                ),
              ),
            ),
            const Expanded(child: _OrnamentLine(fadeLeft: false)),
          ],
        ),
      ],
    );
  }
}

class _OrnamentLine extends StatelessWidget {
  final bool fadeLeft;

  const _OrnamentLine({required this.fadeLeft});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1.2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: fadeLeft
              ? [
                  Colors.transparent,
                  AppTheme.champagne.withValues(alpha: 0.55),
                ]
              : [
                  AppTheme.champagne.withValues(alpha: 0.55),
                  Colors.transparent,
                ],
        ),
      ),
    );
  }
}

class _ShareFooter extends StatelessWidget {
  const _ShareFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: _OrnamentLine(fadeLeft: true)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(
                Icons.auto_awesome,
                size: 14,
                color: AppTheme.champagne.withValues(alpha: 0.7),
              ),
            ),
            const Expanded(child: _OrnamentLine(fadeLeft: false)),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          BrandConstants.shareHashtag,
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: AppTheme.champagneLight.withValues(alpha: 0.92),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'KPSS hazırlık · ${BrandConstants.appName}',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.8,
            color: Colors.white.withValues(alpha: 0.42),
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
    ].join(' · ');

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.07),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        border: Border.all(
          color: AppTheme.champagne.withValues(alpha: 0.32),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (meta.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: AppTheme.champagne.withValues(alpha: 0.12),
                    border: Border.all(
                      color: AppTheme.champagne.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    meta.toUpperCase(),
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: AppTheme.champagneLight,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
            ],
            QuestionStemContent(
              stem: question.soruMetni,
              imageUrl: question.imageUrl,
              sekilKodu: question.sekilKodu,
              watermarkOnText: false,
              style: ExamTypography.body(
                color: Colors.white.withValues(alpha: 0.97),
                fontSize: 34,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (keys.isNotEmpty) ...[
              const SizedBox(height: 26),
              Container(
                height: 1,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppTheme.champagne.withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              for (final key in keys) ...[
                _OptionRow(label: key, text: question.siklar[key] ?? ''),
                const SizedBox(height: 14),
              ],
            ],
          ],
        ),
      ),
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
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.champagne.withValues(alpha: 0.22),
                AppTheme.champagne.withValues(alpha: 0.06),
              ],
            ),
            border: Border.all(
              color: AppTheme.champagneLight.withValues(alpha: 0.7),
              width: 1.5,
            ),
          ),
          child: Text(
            label.toUpperCase(),
            style: GoogleFonts.manrope(
              fontSize: 20,
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
                fontSize: 30,
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
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.07),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        border: Border.all(
          color: AppTheme.champagne.withValues(alpha: 0.32),
          width: 1.3,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: AppTheme.champagne.withValues(alpha: 0.12),
                  border: Border.all(
                    color: AppTheme.champagne.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  '${item.subjectLabel} · ${item.topicLabel}'.toUpperCase(),
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: AppTheme.champagneLight,
                  ),
                ),
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
        ),
      ),
    );
  }
}

/// Tek, büyük, soluk merkez filigran.
class _ShareBackdropMark extends StatelessWidget {
  const _ShareBackdropMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.rotate(
        angle: -math.pi / 4,
        child: Opacity(
          opacity: 0.055,
          child: Image.asset(
            WatermarkWidget.logoAsset,
            width: 620,
            height: 620,
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
