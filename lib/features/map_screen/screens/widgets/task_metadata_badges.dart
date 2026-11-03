import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../utils/task_date_formatter.dart';

class TaskMetadataBadges extends StatelessWidget {
  const TaskMetadataBadges({
    super.key,
    required this.task,
    this.compact = false,
    this.includeScheduleMetadata = false,
    this.assigneeLabel,
  });

  final Task task;
  final bool compact;
  final bool includeScheduleMetadata;
  final String? assigneeLabel;

  @override
  Widget build(BuildContext context) {
    if (includeScheduleMetadata) {
      final metadata = <String>[
        if (task.clientName?.trim().isNotEmpty == true)
          '#${task.clientName!.trim()}',
        if (task.reminder?.trim().isNotEmpty == true)
          '*${_formatScheduleValue(task.reminder!)}',
        if ((assigneeLabel ?? task.assignee)?.trim().isNotEmpty == true)
          '@${(assigneeLabel ?? task.assignee)!.trim()}',
        if (task.deadline?.trim().isNotEmpty == true)
          '!${_formatScheduleValue(task.deadline!)}',
      ];

      if (metadata.isEmpty) return const SizedBox.shrink();
      return Text(
        metadata.join('  •  '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          color: Colors.blueGrey.shade500,
          height: 1.2,
        ),
      );
    }

    final metadata = <String>[
      if (task.assignee?.trim().isNotEmpty == true) '@${task.assignee!.trim()}',
      if (task.clientName?.trim().isNotEmpty == true)
        '#${task.clientName!.trim()}',
      if (task.workType?.trim().isNotEmpty == true) '+${task.workType!.trim()}',
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final value in metadata)
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              color: Colors.blueGrey.shade600,
            ),
          ),
      ],
    );
  }

  String _formatScheduleValue(String value) {
    return DateTime.tryParse(value) == null
        ? value.trim()
        : TaskDateFormatter.formatDateTime(value);
  }
}
