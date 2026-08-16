import '../data/kpss_curriculum.dart';
import '../models/topic_progress_model.dart';
import '../widgets/countdown_widget.dart';

class TopicProgressService {
  TopicProgressService._();
  static final TopicProgressService instance = TopicProgressService._();

  final List<TopicProgressModel> _topics = _buildFromCurriculum();

  List<TopicProgressModel> getTopics(KpssType type) =>
      _topics.where((t) => t.kpssType == type).toList();

  double progressPercent(KpssType type) {
    final topics = getTopics(type);
    if (topics.isEmpty) return 0;
    final done = topics.where((t) => t.tamamlandi).length;
    return done / topics.length;
  }

  void toggleTopic(String id) {
    final index = _topics.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final topic = _topics[index];
    _topics[index] = topic.copyWith(
      tamamlandi: !topic.tamamlandi,
      tamamlanmaTarihi: !topic.tamamlandi ? DateTime.now() : null,
    );
  }

  static List<TopicProgressModel> _buildFromCurriculum() {
    final topics = <TopicProgressModel>[];
    for (final type in KpssType.values) {
      for (final subject in KpssCurriculum.subjectsFor(type)) {
        for (final topic in subject.topics) {
          if (topic.subtopics.isEmpty) {
            topics.add(
              TopicProgressModel(
                id: '${type.name}_${topic.id}',
                kpssType: type,
                dersAdi: subject.name,
                konuAdi: topic.name,
                altKonuAdi: topic.name,
              ),
            );
          } else {
            for (final sub in topic.subtopics) {
              topics.add(
                TopicProgressModel(
                  id: '${type.name}_${topic.id}_$sub',
                  kpssType: type,
                  dersAdi: subject.name,
                  konuAdi: topic.name,
                  altKonuAdi: sub,
                ),
              );
            }
          }
        }
      }
    }
    return topics;
  }
}
