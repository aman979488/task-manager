import 'package:flutter/material.dart';

import '../../models/task.dart';

class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.isSelected,
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
  final String taskName;
  final String? description;
  final Widget priorityWidget;
  final VoidCallback onToggleDone;
  final VoidCallback onToggleSelection;
  final VoidCallback onOpen;
  final VoidCallback onAddSubtask;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: onToggleDone,
              child: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: isSelected
                    ? const Icon(
                        Icons.check_circle,
                        size: 28,
                        color: Color(0xFF6B5800),
                      )
                    : Icon(
                        task.isDone
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 28,
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
                      fontSize: 15,
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
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.25,
                          color: task.isDone
                              ? Colors.grey.shade500
                              : Colors.blueGrey.shade500,
                        ),
                      ),
                    ),
                  if (task.workType?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        task.workType!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: task.isDone
                              ? Colors.grey.shade500
                              : Colors.blueGrey.shade500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    priorityWidget,
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: onAddSubtask,
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.add_circle_outline,
                          size: 24,
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
