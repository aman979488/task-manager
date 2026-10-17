import 'package:flutter/material.dart';

import '../../models/task.dart';

class TaskMetadataBadges extends StatelessWidget {
  const TaskMetadataBadges({
    super.key,
    required this.task,
    this.compact = false,
  });

  final Task task;
  final bool compact;

  @override
  Widget build(BuildContext context) {
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
}
