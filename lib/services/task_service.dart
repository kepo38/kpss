import '../models/study_task_model.dart';

class TaskService {
  TaskService._();
  static final TaskService instance = TaskService._();

  final List<StudyTaskModel> _tasks = [
    StudyTaskModel(
      id: 't1',
      baslik: 'Türkçe paragraf tekrarı',
      dersEtiketi: 'Türkçe',
      oncelik: TaskPriority.yuksek,
      hedefTarih: DateTime.now().add(const Duration(days: 2)),
      olusturmaTarihi: DateTime.now(),
    ),
    StudyTaskModel(
      id: 't2',
      baslik: 'Matematik problem seti',
      dersEtiketi: 'Matematik',
      oncelik: TaskPriority.orta,
      hedefTarih: DateTime.now().add(const Duration(days: 4)),
      olusturmaTarihi: DateTime.now(),
    ),
  ];

  List<StudyTaskModel> get tasks => List.unmodifiable(_tasks);

  List<StudyTaskModel> get pending => _tasks.where((t) => !t.tamamlandi).toList();
  List<StudyTaskModel> get completed => _tasks.where((t) => t.tamamlandi).toList();

  void addTask(StudyTaskModel task) => _tasks.insert(0, task);

  void toggleComplete(String id) {
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i == -1) return;
    _tasks[i] = _tasks[i].copyWith(tamamlandi: !_tasks[i].tamamlandi);
  }

  void deleteTask(String id) => _tasks.removeWhere((t) => t.id == id);
}
