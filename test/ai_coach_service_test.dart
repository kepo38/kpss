import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/services/ai_coach_service.dart';
import 'package:kpss_akademi/widgets/countdown_widget.dart';

void main() {
  final coach = AiCoachService.instance;

  test('topic hints resolve to curriculum topic ids', () {
    expect(
      coach.topicIdForName(KpssType.lisans, 'turkce', 'Paragraf'),
      'turkce_paragraf',
    );
    expect(
      coach.topicIdForName(KpssType.lisans, 'tarih', 'Atatürk İnkılapları'),
      'tarih_inkilaplar',
    );
    expect(
      coach.topicIdForName(KpssType.lisans, null, 'Problemler'),
      'mat_problem',
    );
  });

  test('CoachInsight.canOpenTopic when ids present', () {
    const insight = CoachInsight(
      message: 'test',
      subject: 'Türkçe',
      topic: 'Paragraf',
      kpssType: KpssType.lisans,
      subjectId: 'turkce',
      topicId: 'turkce_paragraf',
    );
    expect(insight.canOpenTopic, isTrue);
  });
}
