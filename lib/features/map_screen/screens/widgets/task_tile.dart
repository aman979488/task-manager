import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../utils/task_title_formatter.dart';
import 'task_metadata_badges.dart';

class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.isSelected,
    this.dense = false,
    this.showMetadata = false,
    this.includeScheduleMetadata = false,
    this.assigneeLabel,
    this.highlightedTitlePrefix,
    this.taskNameMaxLines = 1,
    required this.taskName,
    required this.description,
    required this.priorityWidget,
    required this.onToggleDone,
    required this.onToggleSelection,
    required this.onOpen,
    required this.onAddSubtask,
    this.trailingActionIcon = Icons.add_circle_outline,
    this.trailingActionTooltip = 'Add subtask',
  });

  final Task task;
  final bool isSelected;
  final bool dense;
  final bool showMetadata;
  final bool includeScheduleMetadata;
  final String? assigneeLabel;
  final String? highlightedTitlePrefix;
  final int? taskNameMaxLines;
  final String taskName;
  final String? description;
  final Widget priorityWidget;
  final VoidCallback onToggleDone;
  final VoidCallback onToggleSelection;
  final VoidCallback onOpen;
  final VoidCallback onAddSubtask;
  final IconData trailingActionIcon;
  final String trailingActionTooltip;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(
      horizontal: dense ? 2 : 4,
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
        padding: EdgeInsets.symmetric(horizontal: 0, vertical: dense ? 5 : 8),
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
                  Text.rich(
                    _titleSpan(),
                    maxLines: taskNameMaxLines,
                    overflow: taskNameMaxLines == null
                        ? TextOverflow.clip
                        : TextOverflow.ellipsis,
                  ),
                  if (description?.isNotEmpty == true)
                    Padding(
                      padding: EdgeInsets.only(top: dense ? 1 : 3),
                      child: Text(
                        description!,
                        maxLines: 3,
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
                  if (showMetadata &&
                      (includeScheduleMetadata ||
                          task.assignee?.trim().isNotEmpty == true ||
                          task.workType?.trim().isNotEmpty == true ||
                          task.clientName?.trim().isNotEmpty == true))
                    Padding(
                      padding: EdgeInsets.only(top: dense ? 1 : 3),
                      child: TaskMetadataBadges(
                        task: task,
                        compact: true,
                        includeScheduleMetadata: includeScheduleMetadata,
                        assigneeLabel: assigneeLabel,
                      ),
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
                    SizedBox(width: dense ? 14 : 18),
                    IconButton(
                      tooltip: trailingActionTooltip,
                      visualDensity: VisualDensity.compact,
                      onPressed: onAddSubtask,
                      icon: Icon(
                        trailingActionIcon,
                        size: dense ? 20 : 24,
                        color: const Color(0xFF6B5800),
                      ),
                      padding: EdgeInsets.all(dense ? 4 : 6),
                      constraints: const BoxConstraints(),
                      splashRadius: 20,
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

  TextSpan _titleSpan() {
    final titleStyle = TextStyle(
      fontSize: dense ? 13 : 15,
      fontWeight: FontWeight.w600,
      color: const Color(0xFF26364A),
      decoration: task.isDone
          ? TextDecoration.lineThrough
          : TextDecoration.none,
      decorationColor: Colors.blueGrey.shade400,
    );
    final prefix = highlightedTitlePrefix?.trim();
    if (prefix == null || prefix.isEmpty) {
      return TextSpan(
        text: capitalizeFirstCharacter(taskName),
        style: titleStyle,
      );
    }
    return TextSpan(
      children: [
        TextSpan(
          text: '$prefix - ',
          style: titleStyle.copyWith(color: Colors.black),
        ),
        TextSpan(text: capitalizeFirstCharacter(taskName), style: titleStyle),
      ],
    );
  }
}
