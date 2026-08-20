import 'package:flutter/material.dart';

import '../../data/kpss_curriculum.dart';
import '../../screens/study_hub_screen.dart';
import '../../theme/app_theme.dart';
import '../../theme/subject_neon_palette.dart';
import '../countdown_widget.dart';
import '../scale_button.dart';

/// Yanlış Defterim — premium boş durum.
class WrongNotebookEmptyState extends StatelessWidget {
  final KpssType kpssType;

  const WrongNotebookEmptyState({
    super.key,
    this.kpssType = KpssType.lisans,
  });

  Future<void> _openStudyHub(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudyHubScreen(kpssType: kpssType),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final on = AppTheme.onPage(context);
    final muted = AppTheme.mutedOnPage(context);
    final card = AppTheme.surfaceCard(context);
    final subjects = KpssCurriculum.subjectsFor(kpssType);
    final suggested = subjects.isNotEmpty ? subjects.first : null;
    final accent = suggested != null
        ? SubjectNeonPalette.forSubject(suggested.id)
        : AppTheme.champagne;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        children: [
          const SizedBox(height: 12),
          _HeroCard(accent: accent, on: on, muted: muted, card: card),
          const SizedBox(height: 22),
          _HowItWorksRow(muted: muted, on: on, card: card),
          if (suggested != null) ...[
            const SizedBox(height: 28),
            ScaleButton(
              onPressed: () => _openStudyHub(context),
              child: _PrimaryCta(
                accent: accent,
                label: 'Derslerden test çöz',
                subtitle: 'Yanlış yaptığın sorular otomatik burada toplanır',
                onTap: () => _openStudyHub(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final Color accent;
  final Color on;
  final Color muted;
  final Color card;

  const _HeroCard({
    required this.accent,
    required this.on,
    required this.muted,
    required this.card,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: card.withValues(alpha: 0.96),
        border: Border.all(
          color: AppTheme.champagne.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.ink.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 32,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  accent.withValues(alpha: 0.18),
                  accent.withValues(alpha: 0.04),
                ],
              ),
              border: Border.all(
                color: AppTheme.champagne.withValues(alpha: 0.45),
                width: 1.5,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.menu_book_rounded,
                  size: 36,
                  color: on.withValues(alpha: 0.85),
                ),
                Positioned(
                  right: 18,
                  bottom: 16,
                  child: Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE85D4C),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE85D4C).withValues(alpha: 0.35),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Henüz yanlış soru yok',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: on,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Konu testlerini bitirdiğinizde yanlış yaptığınız sorular '
            'burada toplanır. Testten erken çıkarsanız kaydedilmez.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.55,
              color: muted,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppTheme.champagne.withValues(alpha: 0.1),
              border: Border.all(
                color: AppTheme.champagne.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: AppTheme.champagne.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Yanlış defteriyle deneme oluşturabilirsin',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: on.withValues(alpha: 0.72),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorksRow extends StatelessWidget {
  final Color muted;
  final Color on;
  final Color card;

  const _HowItWorksRow({
    required this.muted,
    required this.on,
    required this.card,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StepTile(
            step: '1',
            icon: Icons.play_circle_outline_rounded,
            label: 'Test çöz',
            muted: muted,
            on: on,
            card: card,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StepTile(
            step: '2',
            icon: Icons.error_outline_rounded,
            label: 'Yanlış kaydedilir',
            muted: muted,
            on: on,
            card: card,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StepTile(
            step: '3',
            icon: Icons.replay_rounded,
            label: 'Buradan tekrar et',
            muted: muted,
            on: on,
            card: card,
          ),
        ),
      ],
    );
  }
}

class _StepTile extends StatelessWidget {
  final String step;
  final IconData icon;
  final String label;
  final Color muted;
  final Color on;
  final Color card;

  const _StepTile({
    required this.step,
    required this.icon,
    required this.label,
    required this.muted,
    required this.on,
    required this.card,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: card.withValues(alpha: 0.72),
        border: Border.all(color: AppTheme.hairline(context)),
      ),
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.champagne.withValues(alpha: 0.14),
            ),
            child: Text(
              step,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: on.withValues(alpha: 0.8),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Icon(icon, size: 18, color: muted),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              height: 1.25,
              color: on.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryCta extends StatelessWidget {
  final Color accent;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _PrimaryCta({
    required this.accent,
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF8E7C0),
                Color(0xFFE2C998),
                Color(0xFFC9A86C),
              ],
            ),
            border: Border.all(color: const Color(0xFFD4AF6A)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.champagne.withValues(alpha: 0.28),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.menu_book_outlined, color: accent, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.ink,
                      ),
                    ),
                  ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.ink.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
