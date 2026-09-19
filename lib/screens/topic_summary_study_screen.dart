import 'package:flutter/material.dart';

import '../models/content_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';
import '../widgets/embossed_app_bar_title.dart';
import '../widgets/topic_summary_swipe_deck.dart';

/// Yalnızca özet kart destesi + Unuttum / Biliyorum.
class TopicSummaryStudyScreen extends StatelessWidget {
  final String topicName;
  final List<TopicSummaryCardModel> cards;

  const TopicSummaryStudyScreen({
    super.key,
    required this.topicName,
    required this.cards,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ink,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
        leading: const AppBackButton(),
        title: const EmbossedAppBarTitle('Özet Konular'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1A2A3E),
                Color(0xFF121C2E),
              ],
            ),
          ),
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF162338),
              Color(0xFF0C1424),
              Color(0xFF0A1C22),
              Color(0xFF0E1828),
            ],
            stops: [0.0, 0.35, 0.7, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -40,
              right: -30,
              child: _AtmosphereBlob(
                size: 180,
                color: AppTheme.champagne.withValues(alpha: 0.14),
              ),
            ),
            Positioned(
              bottom: 80,
              left: -50,
              child: _AtmosphereBlob(
                size: 220,
                color: AppTheme.neonEdge.withValues(alpha: 0.1),
              ),
            ),
            Positioned(
              bottom: -20,
              right: 40,
              child: _AtmosphereBlob(
                size: 140,
                color: AppTheme.champagne.withValues(alpha: 0.08),
              ),
            ),
            SafeArea(
              top: false,
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: TopicSummarySwipeDeck(
                  cards: cards,
                  topicLabel: topicName,
                  embedded: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AtmosphereBlob extends StatelessWidget {
  final double size;
  final Color color;

  const _AtmosphereBlob({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
