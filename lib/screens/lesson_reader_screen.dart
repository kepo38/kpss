import 'package:flutter/material.dart';

import '../models/content_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';
import '../widgets/formatted_text.dart';

/// Konu bilgi kartlarını art arda okuma ekranı.
class LessonReaderScreen extends StatelessWidget {
  final String topicName;
  final List<TopicLessonModel> lessons;

  const LessonReaderScreen({
    super.key,
    required this.topicName,
    required this.lessons,
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
      body: lessons.isEmpty
          ? Center(
              child: Text(
                'Bu konu için henüz bilgi kartı yok.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 48),
              itemCount: lessons.length,
              itemBuilder: (context, i) {
                final lesson = lessons[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${i + 1} / ${lessons.length}',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.champagne.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lesson.title,
                        style: const TextStyle(
                          fontFamily: 'serif',
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (lesson.imageUrl != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(lesson.imageUrl!),
                        ),
                        const SizedBox(height: 16),
                      ],
                      FormattedText(
                        lesson.body,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.55,
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
