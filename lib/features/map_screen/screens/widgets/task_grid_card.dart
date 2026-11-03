import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../utils/task_title_formatter.dart';
import 'task_metadata_badges.dart';

class TaskGridCard extends StatelessWidget {
  const TaskGridCard({
    super.key,
    required this.task,
    required this.taskName,
    required this.description,
    required this.priorityWidget,
    required this.isSelected,
    this.dense = false,
    this.showMetadata = false,
    this.includeScheduleMetadata = false,
    this.assigneeLabel,
    this.highlightedTitlePrefix,
    this.taskNameMaxLines = 1,
    required this.onToggleSelection,
    required this.onOpen,
  });

  final Task task;
  final String taskName;
  final String? description;
  final Widget priorityWidget;
  final bool isSelected;
  final bool dense;
  final bool showMetadata;
  final bool includeScheduleMetadata;
  final String? assigneeLabel;
  final String? highlightedTitlePrefix;
  final int taskNameMaxLines;
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
                priorityWidget,
              ],
            ),
            SizedBox(height: dense ? 6 : 10),
            Text.rich(
              _titleSpan(),
              maxLines: taskNameMaxLines,
              overflow: TextOverflow.ellipsis,
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
            if (showMetadata &&
                (includeScheduleMetadata ||
                    task.assignee?.trim().isNotEmpty == true ||
                    task.workType?.trim().isNotEmpty == true ||
                    task.clientName?.trim().isNotEmpty == true))
              Padding(
                padding: EdgeInsets.only(top: dense ? 3 : 6),
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
    ),
  );

  TextSpan _titleSpan() {
    final titleStyle = TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: dense ? 13 : 14,
      decoration: task.isDone ? TextDecoration.lineThrough : null,
    );
    final prefix = highlightedTitlePrefix?.trim();
    if (prefix == null || prefix.isEmpty) {
      return TextSpan(text: taskName, style: titleStyle);
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
