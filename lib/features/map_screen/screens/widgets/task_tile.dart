import 'package:flutter/material.dart';

import '../../models/task.dart';
import 'task_metadata_badges.dart';

class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.isSelected,
    this.dense = false,
    required this.taskName,
    required this.description,
    required this.priorityWidget,
    required this.onToggleDone,
    required this.onToggleSelection,
    required this.onOpen,
    required this.onAddSubtask,
  });

  final Task task;
  final bool isSelected;
  final bool dense;
  final String taskName;
  final String? description;
  final Widget priorityWidget;
  final VoidCallback onToggleDone;
  final VoidCallback onToggleSelection;
  final VoidCallback onOpen;
  final VoidCallback onAddSubtask;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(
      horizontal: dense ? 8 : 12,
      vertical: dense ? 0 : 2,
    ),
    child: InkWell(
      onLongPress: onToggleSelection,
      onTap: onOpen,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFBE64E).withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: 8,
          vertical: dense ? 5 : 8,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: onToggleDone,
              child: Padding(
                padding: EdgeInsets.only(right: dense ? 8 : 14),
                child: isSelected
                    ? Icon(
                        Icons.check_circle,
                        size: dense ? 23 : 28,
                        color: Color(0xFF6B5800),
                      )
                    : Icon(
                        task.isDone
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: dense ? 23 : 28,
                        color: task.isDone ? Colors.green : Colors.black54,
                      ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    taskName,
                    style: TextStyle(
                      fontSize: dense ? 13 : 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF26364A),
                      decoration: task.isDone
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      decorationColor: Colors.blueGrey.shade400,
                    ),
                  ),
                  if (description?.isNotEmpty == true)
                    Padding(
                      padding: EdgeInsets.only(top: dense ? 1 : 3),
                      child: Text(
                        description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: dense ? 10 : 12,
                          height: 1.25,
                          color: task.isDone
                              ? Colors.grey.shade500
                              : Colors.blueGrey.shade500,
                        ),
                      ),
                    ),
                  if (task.workType?.trim().isNotEmpty == true ||
                      task.clientName?.trim().isNotEmpty == true)
                    Padding(
                      padding: EdgeInsets.only(top: dense ? 1 : 3),
                      child: TaskMetadataBadges(task: task, compact: true),
                    ),
                ],
              ),
            ),
            SizedBox(width: dense ? 6 : 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    priorityWidget,
                    SizedBox(width: dense ? 4 : 8),
                    InkWell(
                      onTap: onAddSubtask,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: EdgeInsets.all(dense ? 4 : 6),
                        child: Icon(
                          Icons.add_circle_outline,
                          size: dense ? 20 : 24,
                          color: Color(0xFF6B5800),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
