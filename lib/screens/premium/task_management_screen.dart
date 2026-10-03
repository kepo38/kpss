import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/study_task_model.dart';
import '../../services/task_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';

class TaskManagementScreen extends StatefulWidget {
  const TaskManagementScreen({super.key});

  @override
  State<TaskManagementScreen> createState() => _TaskManagementScreenState();
}

class _TaskManagementScreenState extends State<TaskManagementScreen> {
  final _service = TaskService.instance;

  @override
  Widget build(BuildContext context) {
    final pending = _service.pending;
    final completed = _service.completed;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Görev Yönetimi'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskDialog,
        icon: const Icon(Icons.add),
        label: const Text('Görev Ekle'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          _SummaryRow(
            pending: pending.length,
            completed: completed.length,
          ),
          const SizedBox(height: 20),
          if (pending.isNotEmpty) ...[
            Text('Bekleyen', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...pending.map((t) => _TaskTile(
                  task: t,
                  onToggle: () => setState(() => _service.toggleComplete(t.id)),
                  onDelete: () => setState(() => _service.deleteTask(t.id)),
                )),
          ],
          if (completed.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Tamamlanan', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...completed.map((t) => _TaskTile(
                  task: t,
                  onToggle: () => setState(() => _service.toggleComplete(t.id)),
                  onDelete: () => setState(() => _service.deleteTask(t.id)),
                )),
          ],
        ],
      ),
    );
  }

  Future<void> _showAddTaskDialog() async {
    final titleCtrl = TextEditingController();
    final dersCtrl = TextEditingController(text: 'Türkçe');
    var priority = TaskPriority.orta;

    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Yeni Görev'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Görev'),
                ),
                TextField(
                  controller: dersCtrl,
                  decoration: const InputDecoration(labelText: 'Ders etiketi'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<TaskPriority>(
                  value: priority,
                  decoration: const InputDecoration(labelText: 'Öncelik'),
                  items: TaskPriority.values
                      .map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text(p.label),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => priority = v!),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('İptal'),
              ),
              FilledButton(
                onPressed: () {
                  _service.addTask(StudyTaskModel(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    baslik: titleCtrl.text,
                    dersEtiketi: dersCtrl.text,
                    oncelik: priority,
                    hedefTarih: DateTime.now().add(const Duration(days: 7)),
                    olusturmaTarihi: DateTime.now(),
                  ));
                  Navigator.pop(ctx);
                  if (mounted) setState(() {});
                },
                child: const Text('Ekle'),
              ),
            ],
          ),
        ),
      );
    } finally {
      titleCtrl.dispose();
      dersCtrl.dispose();
    }
  }
}

class _SummaryRow extends StatelessWidget {
  final int pending;
  final int completed;

  const _SummaryRow({required this.pending, required this.completed});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('$pending', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold)),
                  const Text('Bekleyen'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('$completed', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.lightAccent)),
                  const Text('Tamamlanan'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TaskTile extends StatelessWidget {
  final StudyTaskModel task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _TaskTile({
    required this.task,
    required this.onToggle,
    required this.onDelete,
  });

  Color _priorityColor() {
    switch (task.oncelik) {
      case TaskPriority.dusuk:
        return Colors.green;
      case TaskPriority.orta:
        return AppTheme.lightAccent;
      case TaskPriority.yuksek:
        return Colors.red.shade300;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Checkbox(
          value: task.tamamlandi,
          onChanged: (_) => onToggle(),
          activeColor: AppTheme.lightPrimary,
        ),
        title: Text(
          task.baslik,
          style: task.tamamlandi
              ? const TextStyle(decoration: TextDecoration.lineThrough)
              : null,
        ),
        subtitle: Row(
          children: [
            Chip(
              label: Text(task.dersEtiketi, style: const TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _priorityColor(),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
