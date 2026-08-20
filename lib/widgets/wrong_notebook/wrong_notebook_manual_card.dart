import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/manual_question_model.dart';
import '../../theme/app_theme.dart';

class WrongNotebookManualCard extends StatelessWidget {
  final ManualQuestionModel item;
  final VoidCallback onTapImage;
  final VoidCallback onRemove;
  final ValueChanged<ManualQuestionStatus> onStatusChanged;

  const WrongNotebookManualCard({
    super.key,
    required this.item,
    required this.onTapImage,
    required this.onRemove,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final on = AppTheme.onPage(context);
    final muted = AppTheme.mutedOnPage(context);
    final date =
        DateFormat('dd.MM.yyyy HH:mm').format(item.createdAt.toLocal());
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppTheme.surfaceCard(context).withValues(alpha: 0.92),
          border: Border.all(color: AppTheme.hairline(context)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _MetaPill(label: item.subjectLabel),
                  const SizedBox(width: 6),
                  _MetaPill(label: item.topicLabel),
                  const Spacer(),
                  IconButton(
                    onPressed: onRemove,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: muted.withValues(alpha: 0.7),
                    ),
                    tooltip: 'Kaldır',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onTapImage,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Image.file(
                      File(item.imagePath),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppTheme.ink.withValues(alpha: 0.08),
                        alignment: Alignment.center,
                        child: Text(
                          'Görsel bulunamadı',
                          style: TextStyle(
                            color: muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (item.hasNote) ...[
                const SizedBox(height: 8),
                Text(
                  item.noteText,
                  style: TextStyle(color: on, fontSize: 13.5, height: 1.35),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      date,
                      style: TextStyle(
                        color: muted.withValues(alpha: 0.75),
                        fontSize: 11,
                      ),
                    ),
                  ),
                  _StatusChip(
                    status: item.status,
                    onChanged: onStatusChanged,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final String label;
  const _MetaPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        color: AppTheme.ink.withValues(alpha: 0.05),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: AppTheme.mutedOnPage(context),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final ManualQuestionStatus status;
  final ValueChanged<ManualQuestionStatus> onChanged;

  const _StatusChip({
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
