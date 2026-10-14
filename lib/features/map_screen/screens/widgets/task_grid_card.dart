import 'package:flutter/material.dart';

import '../../models/task.dart';
import 'task_metadata_badges.dart';

class TaskGridCard extends StatelessWidget {
  const TaskGridCard({
    super.key,
    required this.task,
    required this.taskName,
    required this.description,
    required this.isSelected,
    this.dense = false,
    required this.onToggleSelection,
    required this.onOpen,
  });

  final Task task;
  final String taskName;
  final String? description;
  final bool isSelected;
  final bool dense;
  final VoidCallback onToggleSelection;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.all(dense ? 2 : 4),
    color: isSelected
        ? const Color(0xFFFBE64E).withValues(alpha: 0.15)
        : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: Colors.grey.shade200),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onLongPress: onToggleSelection,
      onTap: onOpen,
      child: Padding(
        padding: EdgeInsets.all(dense ? 8 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  task.isDone
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: task.isDone ? Colors.green : Colors.grey,
                  size: dense ? 17 : 20,
                ),
                const SizedBox(width: 8),
                if (task.priority?.isNotEmpty == true)
                  Text(
                    task.priority!,
                    style: TextStyle(
                      color: Color(0xFF6B5800),
                      fontWeight: FontWeight.w600,
                      fontSize: dense ? 10 : 12,
                    ),
                  ),
              ],
            ),
            SizedBox(height: dense ? 6 : 10),
            Text(
              taskName,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: dense ? 13 : 14,
                decoration: task.isDone ? TextDecoration.lineThrough : null,
              ),
            ),
            const Spacer(),
            if (description?.isNotEmpty == true)
              Text(
                description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: dense ? 10 : 12,
                  color: Colors.grey.shade600,
                ),
              ),
            if (task.workType?.trim().isNotEmpty == true ||
                task.clientName?.trim().isNotEmpty == true)
              Padding(
                padding: EdgeInsets.only(top: dense ? 3 : 6),
                child: TaskMetadataBadges(task: task, compact: true),
              ),
          ],
        ),
      ),
    ),
  );
}
