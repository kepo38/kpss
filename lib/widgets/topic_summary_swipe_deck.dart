import 'package:flutter/material.dart';

import '../models/content_models.dart';
import '../services/summary_card_progress_service.dart';
import '../theme/app_theme.dart';
import 'favorite_heart_button.dart';

/// Konu detayında Tinder tarzı özet kart destesi.
class TopicSummarySwipeDeck extends StatefulWidget {
  final List<TopicSummaryCardModel> cards;

  const TopicSummarySwipeDeck({
    super.key,
    required this.cards,
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Özet kartlar',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_queue.length} kart',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 248,
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
                    Transform.translate(
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _resolve(known: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF87171),
                      side: BorderSide(
                        color: const Color(0xFFF87171).withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.replay_rounded, size: 18),
                    label: const Text('Unuttum'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _resolve(known: true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.champagne,
                      foregroundColor: AppTheme.ink,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Biliyorum'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Sola kaydır: Tekrar Et · Sağa kaydır: Biliyorum',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.4),
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
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.inkSoft,
            AppTheme.ink.withValues(alpha: 0.92),
          ],
        ),
        border: Border.all(
          color: AppTheme.champagne.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  color: AppTheme.champagne.withValues(alpha: 0.16),
                ),
                child: Text(
                  card.kindLabel,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.champagneLight,
                  ),
                ),
              ),
              const Spacer(),
              if (showHeart)
                ListenableBuilder(
                  listenable: SummaryCardProgressService.instance,
                  builder: (context, _) {
                    return FavoriteHeartButton(
                      isFavorite: SummaryCardProgressService.instance
                          .isFavorite(card.id),
                      onToggle: () async {
                        await SummaryCardProgressService.instance
                            .toggleFavorite(card.id);
                      },
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            card.title,
            style: const TextStyle(
              fontFamily: 'serif',
              fontSize: 20,
              fontWeight: FontWeight.w700,
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
            child: Text(
              card.body,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.4,
                color: Colors.white.withValues(alpha: 0.78),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
