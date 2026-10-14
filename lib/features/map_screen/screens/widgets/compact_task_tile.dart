import 'package:flutter/material.dart';

import '../../models/task.dart';
import 'task_metadata_badges.dart';

class CompactTaskTile extends StatelessWidget {
  const CompactTaskTile({
    super.key,
    required this.task,
    required this.taskName,
    required this.description,
    required this.isSelected,
    required this.priorityBadge,
    required this.onToggleDone,
    required this.onAddSubtask,
    required this.onToggleSelection,
    required this.onOpen,
  });

  final Task task;
  final String taskName;
  final String? description;
  final bool isSelected;
  final Widget priorityBadge;
  final VoidCallback onToggleDone;
  final VoidCallback onAddSubtask;
  final VoidCallback onToggleSelection;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final hasMetadata =
        task.workType?.trim().isNotEmpty == true ||
        task.clientName?.trim().isNotEmpty == true;
    return ListTile(
      dense: true,
      selected: isSelected,
      leading: Checkbox(
        value: task.isDone,
        activeColor: const Color(0xFF6B5800),
        onChanged: (_) => onToggleDone(),
      ),
      title: Text(
        taskName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF26364A),
          decoration: task.isDone ? TextDecoration.lineThrough : null,
          decorationColor: Colors.blueGrey.shade400,
        ),
      ),
      subtitle: description?.isNotEmpty != true && !hasMetadata
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (description?.isNotEmpty == true)
                  Text(
                    description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blueGrey.shade500,
                      height: 1.25,
                    ),
                  ),
                if (hasMetadata)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: TaskMetadataBadges(task: task, compact: true),
                  ),
              ],
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          priorityBadge,
          IconButton(
            tooltip: 'Add subtask',
            visualDensity: VisualDensity.compact,
            onPressed: onAddSubtask,
            icon: const Icon(
              Icons.add_circle_outline,
              color: Color(0xFF526D8A),
              size: 21,
            ),
          ),
        ],
      ),
      onLongPress: onToggleSelection,
      onTap: onOpen,
    );
  }
}
