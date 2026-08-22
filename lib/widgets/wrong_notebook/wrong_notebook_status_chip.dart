import 'package:flutter/material.dart';

import '../../models/manual_question_model.dart';

class WrongNotebookStatusChip extends StatelessWidget {
  final ManualQuestionStatus status;
  final ValueChanged<ManualQuestionStatus> onChanged;

  const WrongNotebookStatusChip({
    super.key,
    required this.status,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ManualQuestionStatus>(
      onSelected: onChanged,
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: ManualQuestionStatus.fresh,
          child: Text('Yeni'),
        ),
        PopupMenuItem(
          value: ManualQuestionStatus.repeat,
          child: Text('Tekrar Et'),
        ),
        PopupMenuItem(
          value: ManualQuestionStatus.solved,
          child: Text('Çözüldü'),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: _statusColor(status).withValues(alpha: 0.16),
          border:
              Border.all(color: _statusColor(status).withValues(alpha: 0.38)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _statusIcon(status),
              size: 14,
              color: _statusColor(status),
            ),
            const SizedBox(width: 5),
            Text(
              _statusLabel(status),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _statusColor(status),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(ManualQuestionStatus status) {
    return switch (status) {
      ManualQuestionStatus.fresh => 'Yeni',
      ManualQuestionStatus.repeat => 'Tekrar Et',
      ManualQuestionStatus.solved => 'Çözüldü',
    };
  }

  IconData _statusIcon(ManualQuestionStatus status) {
    return switch (status) {
      ManualQuestionStatus.fresh => Icons.fiber_new_rounded,
      ManualQuestionStatus.repeat => Icons.refresh_rounded,
      ManualQuestionStatus.solved => Icons.check_circle_rounded,
    };
  }

  Color _statusColor(ManualQuestionStatus status) {
    return switch (status) {
      ManualQuestionStatus.fresh => const Color(0xFF60A5FA),
      ManualQuestionStatus.repeat => const Color(0xFFF59E0B),
      ManualQuestionStatus.solved => const Color(0xFF10B981),
    };
  }
}
