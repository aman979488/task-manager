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
    final metadata = [
      ('Work type', task.workType),
      ('Client', task.clientName),
    ].where((entry) => entry.$2?.trim().isNotEmpty == true);

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final (label, value) in metadata)
          Container(
            constraints: BoxConstraints(maxWidth: compact ? 180 : 220),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 6 : 8,
              vertical: compact ? 2 : 4,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF526D8A).withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF526D8A).withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              '$label: ${value!.trim()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                color: const Color(0xFF526D8A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
