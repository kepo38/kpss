import 'package:flutter/material.dart';

import '../models/content_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';
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
        backgroundColor: AppTheme.ink,
        foregroundColor: Colors.white,
        leading: const AppBackButton(),
        title: Text(
          topicName,
          style: const TextStyle(
            fontFamily: 'serif',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: TopicSummarySwipeDeck(
            cards: cards,
            embedded: false,
          ),
        ),
      ),
    );
  }
}
