import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/manual_question_model.dart';
import '../../theme/app_theme.dart';
import 'wrong_notebook_status_chip.dart';

class WrongNotebookManualCard extends StatelessWidget {
  final ManualQuestionModel item;
  final VoidCallback onTapImage;
  final VoidCallback onRemove;
  final VoidCallback? onShare;
  final ValueChanged<ManualQuestionStatus> onStatusChanged;

  const WrongNotebookManualCard({
    super.key,
    required this.item,
    required this.onTapImage,
    required this.onRemove,
    required this.onStatusChanged,
    this.onShare,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _MetaPill(label: item.subjectLabel),
                        _MetaPill(label: item.topicLabel),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onShare != null) ...[
                        _ShareButton(onTap: onShare!),
                        const SizedBox(width: 4),
                      ],
                      _RemoveButton(onTap: onRemove),
                    ],
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
                  WrongNotebookStatusChip(
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
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: AppTheme.mutedOnPage(context),
        ),
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ShareButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.mutedOnPage(context);
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: 'WhatsApp / paylaş',
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF25D366).withValues(alpha: 0.12),
            border: Border.all(
              color: const Color(0xFF25D366).withValues(alpha: 0.4),
            ),
          ),
          child: Icon(
            Icons.share_rounded,
            size: 16,
            color: muted.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RemoveButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.mutedOnPage(context);
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: 'Kaldır',
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.ink.withValues(alpha: 0.04),
            border: Border.all(color: AppTheme.ink.withValues(alpha: 0.06)),
          ),
          child: Icon(
            Icons.delete_outline_rounded,
            size: 16,
            color: muted.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

