import 'package:flutter/material.dart';

import '../../models/question_model.dart';
import '../../theme/app_theme.dart';
import '../question_stem_content.dart';
import 'wrong_notebook_utils.dart';

class WrongNotebookSubjectHeader extends StatelessWidget {
  final String subject;
  final int count;

  const WrongNotebookSubjectHeader({
    super.key,
    required this.subject,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final on = AppTheme.onPage(context);
    final accent = wrongNotebookSubjectAccent(subject);

    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  accent,
                  accent.withValues(alpha: 0.45),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              subject,
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: on,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: accent.withValues(alpha: 0.12),
              border: Border.all(color: accent.withValues(alpha: 0.28)),
            ),
            child: Text(
              '$count soru',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: on.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WrongNotebookQuestionCard extends StatelessWidget {
  final QuestionModel question;
  final bool isFavorite;
  final bool similarLoading;
  final bool showProBadge;
  final VoidCallback onToggleFavorite;
  final VoidCallback onSimilar;
  final VoidCallback onTap;

  const WrongNotebookQuestionCard({
    super.key,
    required this.question,
    required this.isFavorite,
    required this.similarLoading,
    required this.showProBadge,
    required this.onToggleFavorite,
    required this.onSimilar,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final on = AppTheme.onPage(context);
    final card = AppTheme.surfaceCard(context);
    final accent = wrongNotebookSubjectAccent(question.dersAdi);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: card.withValues(alpha: 0.9),
              border: Border.all(color: AppTheme.hairline(context)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.ink.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 4,
                      color: accent,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              QuestionStemContent.previewText(
                                question.soruMetni,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: on,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _TopicChip(label: question.konuAdi),
                                const Spacer(),
                                _SimilarChip(
                                  loading: similarLoading,
                                  locked: showProBadge,
                                  onTap: similarLoading ? null : onSimilar,
                                ),
                                const SizedBox(width: 6),
                                _FavoriteButton(
                                  isFavorite: isFavorite,
                                  onTap: onToggleFavorite,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'SORUYA TEKRAR GÖZ AT',
                              style: TextStyle(
                                color: AppTheme.mutedOnPage(context)
                                    .withValues(alpha: 0.7),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopicChip extends StatelessWidget {
  final String label;

  const _TopicChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.mutedOnPage(context);
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: AppTheme.ink.withValues(alpha: 0.04),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: muted,
          ),
        ),
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  final bool isFavorite;
  final VoidCallback onTap;

  const _FavoriteButton({
    required this.isFavorite,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.mutedOnPage(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isFavorite
              ? AppTheme.champagne.withValues(alpha: 0.14)
              : AppTheme.ink.withValues(alpha: 0.04),
          border: Border.all(
            color: isFavorite
                ? AppTheme.champagne.withValues(alpha: 0.45)
                : AppTheme.ink.withValues(alpha: 0.06),
          ),
        ),
        child: Icon(
          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: 16,
          color: isFavorite ? AppTheme.champagne : muted.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class WrongNotebookSimilarChip extends StatelessWidget {
  final VoidCallback? onTap;
  final bool loading;
  final bool locked;

  const WrongNotebookSimilarChip({
    super.key,
    required this.onTap,
    this.loading = false,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) => _SimilarChip(
        loading: loading,
        locked: locked,
        onTap: onTap,
      );
}

class _SimilarChip extends StatelessWidget {
  final VoidCallback? onTap;
  final bool loading;
  final bool locked;

  const _SimilarChip({
    required this.onTap,
    this.loading = false,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: loading ? 0.85 : 1,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: const Color(0xFF1A2740),
            border: Border.all(
              color: locked
                  ? const Color(0xFFD4AF6A)
                  : AppTheme.champagne.withValues(alpha: 0.35),
              width: locked ? 1 : 0.5,
            ),
            boxShadow: locked
                ? [
                    BoxShadow(
                      color: AppTheme.champagne.withValues(alpha: 0.28),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (loading)
                      const SizedBox(
                        width: 11,
                        height: 11,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: AppTheme.champagneLight,
                        ),
                      )
                    else
                      Icon(
                        locked
                            ? Icons.lock_rounded
                            : Icons.auto_awesome_rounded,
                        size: 11,
                        color: AppTheme.champagneLight,
                      ),
                    const SizedBox(width: 4),
                    const Text(
                      'BENZER',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppTheme.champagneLight,
                      ),
                    ),
                  ],
                ),
              ),
              if (locked)
                Container(
                  padding: const EdgeInsets.fromLTRB(6, 6, 7, 6),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFF6E4),
                        Color(0xFFE8CF98),
                        Color(0xFFC9A86C),
                      ],
                    ),
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: Color(0xFF3A2A10),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
