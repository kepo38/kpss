import 'package:flutter/material.dart';

import '../../models/question_model.dart';
import '../../theme/app_theme.dart';
import '../question_stem_content.dart';
import 'wrong_notebook_guest_frost.dart';
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
          Flexible(
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
          const SizedBox(width: 8),
          Container(
            constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              color: accent.withValues(alpha: 0.16),
              border: Border.all(color: accent.withValues(alpha: 0.4)),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                height: 1,
                color: on.withValues(alpha: 0.85),
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
  final bool frostStem;
  final VoidCallback onToggleFavorite;
  final VoidCallback onSimilar;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback? onShare;
  final VoidCallback? onSignIn;

  const WrongNotebookQuestionCard({
    super.key,
    required this.question,
    required this.isFavorite,
    required this.similarLoading,
    required this.showProBadge,
    this.frostStem = false,
    required this.onToggleFavorite,
    required this.onSimilar,
    required this.onTap,
    required this.onRemove,
    this.onShare,
    this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    final on = AppTheme.onPage(context);
    final card = AppTheme.surfaceCard(context);
    final accent = wrongNotebookSubjectAccent(question.dersAdi);

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 10),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: frostStem ? (onSignIn ?? onTap) : onTap,
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
                            // Üst boşluk: ortadaki BENZER rozeti ile ikonlar çakışmasın.
                            padding: const EdgeInsets.fromLTRB(14, 28, 10, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _TopicChip(label: question.konuAdi),
                                    const Spacer(),
                                    // Paylaş / favori / sil — sağa yaslı küme.
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (onShare != null) ...[
                                          _ShareButton(onTap: onShare!),
                                          const SizedBox(width: 4),
                                        ],
                                        _FavoriteButton(
                                          isFavorite: isFavorite,
                                          onTap: onToggleFavorite,
                                        ),
                                        const SizedBox(width: 4),
                                        _RemoveButton(onTap: onRemove),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                WrongNotebookGuestFrost(
                                  locked: frostStem,
                                  child: Text(
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
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'SORUYA TEKRAR GÖZ AT',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
          // BENZER — panel üst kenarının ortasına oturan rozet.
          Positioned(
            top: -11,
            child: _SimilarChip(
              loading: similarLoading,
              locked: showProBadge,
              onTap: similarLoading ? null : onSimilar,
            ),
          ),
        ],
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

class _ShareButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ShareButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.mutedOnPage(context);
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: 'WhatsApp / paylaş',
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF25D366).withValues(alpha: 0.12),
            border: Border.all(
              color: const Color(0xFF25D366).withValues(alpha: 0.4),
            ),
          ),
          child: Icon(
            Icons.share_rounded,
            size: 16,
            color: muted.withValues(alpha: 0.85),
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

class _RemoveButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RemoveButton({required this.onTap});

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
          color: AppTheme.ink.withValues(alpha: 0.04),
          border: Border.all(color: AppTheme.ink.withValues(alpha: 0.06)),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          size: 16,
          color: muted.withValues(alpha: 0.55),
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
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: loading ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: loading ? 0.85 : 1,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1E2F4A),
                  const Color(0xFF152238).withValues(alpha: 0.98),
                ],
              ),
              border: Border.all(
                color: locked
                    ? const Color(0xFFD4AF6A)
                    : AppTheme.champagne.withValues(alpha: 0.55),
                width: locked ? 1.1 : 0.9,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.ink.withValues(alpha: 0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
                if (locked)
                  BoxShadow(
                    color: AppTheme.champagne.withValues(alpha: 0.28),
                    blurRadius: 8,
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(11, 7, 11, 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (loading)
                        const SizedBox(
                          width: 12,
                          height: 12,
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
                          size: 13,
                          color: AppTheme.champagneLight,
                        ),
                      const SizedBox(width: 5),
                      const Text(
                        'BENZER',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: AppTheme.champagneLight,
                        ),
                      ),
                    ],
                  ),
                ),
                if (locked)
                  Container(
                    padding: const EdgeInsets.fromLTRB(7, 7, 9, 7),
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
                        fontSize: 9,
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
      ),
    );
  }
}
