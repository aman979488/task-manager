import 'package:flutter/material.dart';

import '../../models/task.dart';
import 'task_metadata_badges.dart';
import 'task_substeps_summary.dart';

class CompactTaskTile extends StatelessWidget {
  const CompactTaskTile({
    super.key,
    required this.task,
    required this.taskName,
    required this.description,
    required this.isSelected,
    this.dense = false,
    this.showMetadata = false,
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
  final bool dense;
  final bool showMetadata;
  final Widget priorityBadge;
  final VoidCallback onToggleDone;
  final VoidCallback onAddSubtask;
  final VoidCallback onToggleSelection;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final hasMetadata =
        showMetadata &&
        (task.assignee?.trim().isNotEmpty == true ||
            task.workType?.trim().isNotEmpty == true ||
            task.clientName?.trim().isNotEmpty == true);
    final hasSubsteps = task.steps.isNotEmpty;
    return ListTile(
      dense: true,
      visualDensity: dense
          ? const VisualDensity(horizontal: -1, vertical: -1)
          : VisualDensity.standard,
      contentPadding: EdgeInsets.symmetric(horizontal: dense ? 8 : 16),
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
          fontSize: dense ? 13 : 15,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF26364A),
          decoration: task.isDone ? TextDecoration.lineThrough : null,
          decorationColor: Colors.blueGrey.shade400,
        ),
      ),
      subtitle: description?.isNotEmpty != true && !hasMetadata && !hasSubsteps
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
                      fontSize: dense ? 10 : 12,
                      color: Colors.blueGrey.shade500,
                      height: 1.25,
                    ),
                  ),
                if (hasSubsteps)
                  TaskSubstepsSummary(steps: task.steps, dense: true),
                if (hasMetadata)
                  Padding(
                    padding: EdgeInsets.only(top: dense ? 1 : 3),
                    child: TaskMetadataBadges(task: task, compact: true),
                  ),
              ],
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          priorityBadge,
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Add subtask',
            visualDensity: VisualDensity.compact,
            onPressed: onAddSubtask,
            icon: Icon(
              Icons.add_circle_outline,
              color: Color(0xFF526D8A),
              size: dense ? 19 : 21,
            ),
          ),
        ],
      ),
      onLongPress: onToggleSelection,
      onTap: onOpen,
    );
  }
}
