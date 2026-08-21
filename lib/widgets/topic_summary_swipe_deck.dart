import 'package:flutter/material.dart';

import '../models/content_models.dart';
import '../services/summary_card_progress_service.dart';
import '../theme/app_theme.dart';
import 'favorite_heart_button.dart';

/// Konu detayında Tinder tarzı özet kart destesi.
class TopicSummarySwipeDeck extends StatefulWidget {
  final List<TopicSummaryCardModel> cards;
  /// true: Konuyu öğren bölümünün içinde — ayrı büyük başlık yok.
  final bool embedded;
  /// AppBar dışı ince konu etiketi (tam ekran çalışmada).
  final String? topicLabel;

  const TopicSummarySwipeDeck({
    super.key,
    required this.cards,
    this.embedded = false,
    this.topicLabel,
  });

  @override
  State<TopicSummarySwipeDeck> createState() => _TopicSummarySwipeDeckState();
}

class _TopicSummarySwipeDeckState extends State<TopicSummarySwipeDeck>
    with SingleTickerProviderStateMixin {
  double _dragDx = 0;
  bool _busy = false;

  List<TopicSummaryCardModel> get _queue {
    final progress = SummaryCardProgressService.instance;
    final pending = widget.cards
        .where((c) => !progress.isKnown(c.id))
        .toList();
    if (pending.isNotEmpty) return pending;
    return widget.cards;
  }

  TopicSummaryCardModel? get _top =>
      _queue.isEmpty ? null : _queue.first;

  Future<void> _resolve({required bool known}) async {
    final card = _top;
    if (card == null || _busy) return;
    setState(() {
      _busy = true;
      _dragDx = known ? 420 : -420;
    });
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final progress = SummaryCardProgressService.instance;
    if (known) {
      await progress.markKnown(card.id);
    } else {
      await progress.markWeak(card.id);
    }
    if (!mounted) return;
    setState(() {
      _dragDx = 0;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SummaryCardProgressService.instance,
      builder: (context, _) {
        final card = _top;
        if (widget.cards.isEmpty) {
          return const SizedBox.shrink();
        }
        if (card == null) {
          return _EmptyDeck(total: widget.cards.length);
        }

        final progress = (_dragDx / 140).clamp(-1.0, 1.0);
        final bottomInset = MediaQuery.paddingOf(context).bottom;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.embedded)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 14,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        color: AppTheme.champagne,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ÖZET',
                      style: TextStyle(
                        fontSize: 10.5,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.champagne.withValues(alpha: 0.95),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_queue.length} / ${widget.cards.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    if (widget.topicLabel != null &&
                        widget.topicLabel!.trim().isNotEmpty)
                      Expanded(
                        child: Text(
                          widget.topicLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    Text(
                      '${_queue.length} / ${widget.cards.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.champagne.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: GestureDetector(
                onHorizontalDragUpdate: _busy
                    ? null
                    : (d) => setState(() => _dragDx += d.delta.dx),
                onHorizontalDragEnd: _busy
                    ? null
                    : (d) {
                        if (_dragDx > 110 ||
                            (d.primaryVelocity ?? 0) > 700) {
                          unawaitedResolve(known: true);
                        } else if (_dragDx < -110 ||
                            (d.primaryVelocity ?? 0) < -700) {
                          unawaitedResolve(known: false);
                        } else {
                          setState(() => _dragDx = 0);
                        }
                      },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (_queue.length > 1)
                      Positioned.fill(
                        child: Transform.translate(
                          offset: const Offset(0, 8),
                          child: Opacity(
                            opacity: 0.45,
                            child: SummaryCardFace(
                              card: _queue[1],
                              showHeart: false,
                            ),
                          ),
                        ),
                      ),
                    Positioned.fill(
                      child: Transform.translate(
                        offset: Offset(_dragDx, 0),
                        child: Transform.rotate(
                          angle: progress * 0.08,
                          child: Stack(
                            children: [
                              SummaryCardFace(card: card),
                              if (progress > 0.15)
                                _SwipeStamp(
                                  label: 'BİLİYORUM',
                                  color: const Color(0xFF34D399),
                                  alignment: Alignment.topLeft,
                                  opacity: progress,
                                ),
                              if (progress < -0.15)
                                _SwipeStamp(
                                  label: 'UNUTTUM',
                                  color: const Color(0xFFF87171),
                                  alignment: Alignment.topRight,
                                  opacity: -progress,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: EdgeInsets.only(bottom: bottomInset + 12),
              child: _ActionBar(
                busy: _busy,
                onForgot: () => _resolve(known: false),
                onKnow: () => _resolve(known: true),
              ),
            ),
          ],
        );
      },
    );
  }

  void unawaitedResolve({required bool known}) {
    _resolve(known: known);
  }
}

class _ActionBar extends StatelessWidget {
  final bool busy;
  final VoidCallback onForgot;
  final VoidCallback onKnow;

  const _ActionBar({
    required this.busy,
    required this.onForgot,
    required this.onKnow,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF243048).withValues(alpha: 0.95),
                const Color(0xFF162033).withValues(alpha: 0.98),
              ],
            ),
            border: Border.all(
              color: AppTheme.champagne.withValues(alpha: 0.35),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.neonEdge.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, -2),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onForgot,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF87171),
                    side: BorderSide(
                      color: const Color(0xFFF87171).withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text('Unuttum'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy ? null : onKnow,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.champagne,
                    foregroundColor: AppTheme.ink,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Biliyorum'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sola kaydır: Tekrar Et · Sağa kaydır: Biliyorum',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}

class _EmptyDeck extends StatelessWidget {
  final int total;
  const _EmptyDeck({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(
        total == 0
            ? 'Bu konu için henüz özet kart yok.'
            : 'Tüm kartları bildin. Tekrar için Unuttum havuzuna bakabilirsin.',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
      ),
    );
  }
}

class _SwipeStamp extends StatelessWidget {
  final String label;
  final Color color;
  final Alignment alignment;
  final double opacity;

  const _SwipeStamp({
    required this.label,
    required this.color,
    required this.alignment,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: alignment == Alignment.topLeft ? -0.25 : 0.25,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color, width: 2),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
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

class SummaryCardFace extends StatelessWidget {
  final TopicSummaryCardModel card;
  final bool showHeart;

  const SummaryCardFace({
    super.key,
    required this.card,
    this.showHeart = true,
  });

  /// Favorilerden tam kart göstermek için.
  static Future<void> showViewer(
    BuildContext context,
    TopicSummaryCardModel card,
  ) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 40),
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.62,
          child: Stack(
            children: [
              SummaryCardFace(card: card),
              Positioned(
                top: 6,
                right: 2,
                child: IconButton(
                  tooltip: 'Kapat',
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF243048),
            Color(0xFF162033),
            Color(0xFF0E1524),
          ],
        ),
        border: Border.all(
          color: AppTheme.champagne.withValues(alpha: 0.42),
          width: 1.15,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.champagne.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.champagne.withValues(alpha: 0.28),
                          AppTheme.champagne.withValues(alpha: 0.1),
                        ],
                      ),
                      border: Border.all(
                        color: AppTheme.champagne.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _kindIcon(card.kind),
                          size: 12,
                          color: AppTheme.champagneLight,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          card.kindLabel.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
                            color: AppTheme.champagneLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (showHeart)
                ListenableBuilder(
                  listenable: SummaryCardProgressService.instance,
                  builder: (context, _) {
                    final fav = SummaryCardProgressService.instance
                        .isFavorite(card.id);
                    return Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                        border: Border.all(
                          color: fav
                              ? const Color(0xFFF87171).withValues(alpha: 0.55)
                              : Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: FavoriteHeartButton(
                        isFavorite: fav,
                        onToggle: () async {
                          await SummaryCardProgressService.instance
                              .toggleFavorite(card.id);
                        },
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 1,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.champagne.withValues(alpha: 0.45),
                  AppTheme.champagne.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Text(
            card.title,
            style: const TextStyle(
              fontFamily: 'serif',
              fontSize: 21,
              height: 1.15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: Colors.white,
            ),
          ),
          if (card.imageUrl != null && card.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  card.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Text(
                card.body,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.42,
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _kindIcon(SummaryCardKind kind) => switch (kind) {
        SummaryCardKind.formula => Icons.functions_rounded,
        SummaryCardKind.tip => Icons.lightbulb_outline_rounded,
        SummaryCardKind.osym => Icons.school_outlined,
      };
}
