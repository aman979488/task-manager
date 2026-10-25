import 'package:flutter/material.dart';

import '../../models/task.dart';
import 'compact_task_tile.dart';
import 'task_grid_card.dart';
import 'task_tile.dart';

class MapTaskListItem extends StatelessWidget {
  const MapTaskListItem({
    super.key,
    required this.task,
    required this.viewType,
    this.dense = false,
    this.showMetadata = false,
    this.taskNameMaxLines,
    required this.isSelected,
    required this.taskName,
    required this.description,
    required this.onEditPriority,
    this.priorityEditable = true,
    this.readOnly = false,
    required this.onToggleDone,
    required this.onToggleSelection,
    required this.onOpen,
    required this.onAddSubtask,
  });

  final Task task;
  final String viewType;
  final bool dense;
  final bool showMetadata;
  final int? taskNameMaxLines;
  final bool isSelected;
  final String taskName;
  final String? description;
  final ValueChanged<BuildContext> onEditPriority;
  final bool priorityEditable;
  final bool readOnly;
  final VoidCallback onToggleDone;
  final VoidCallback onToggleSelection;
  final VoidCallback onOpen;
  final VoidCallback onAddSubtask;

  @override
  Widget build(BuildContext context) {
    if (viewType == 'Grid') {
      return TaskGridCard(
        task: task,
        taskName: taskName,
        description: description,
        showMetadata: showMetadata,
        taskNameMaxLines: taskNameMaxLines ?? 1,
        isSelected: isSelected,
        dense: dense,
        onToggleSelection: readOnly ? _ignoreAction : onToggleSelection,
        onOpen: readOnly ? _ignoreAction : onOpen,
      );
    }

    if (viewType == 'List') {
      return CompactTaskTile(
        task: task,
        taskName: taskName,
        description: description,
        showMetadata: showMetadata,
        isSelected: isSelected,
        dense: dense,
        priorityBadge: _priorityBadge(
          compact: true,
          onTap: priorityEditable && !readOnly
              ? () => onEditPriority(context)
              : _ignoreAction,
        ),
        onToggleDone: readOnly ? _ignoreAction : onToggleDone,
        onAddSubtask: readOnly ? _ignoreAction : onAddSubtask,
        onToggleSelection: readOnly ? _ignoreAction : onToggleSelection,
        onOpen: readOnly ? _ignoreAction : onOpen,
      );
    }

    return TaskTile(
      task: task,
      isSelected: isSelected,
      dense: dense,
      taskName: taskName,
      description: description,
      showMetadata: showMetadata,
      taskNameMaxLines: taskNameMaxLines ?? 1,
      priorityWidget: Builder(
        builder: (badgeContext) => _priorityBadge(
          compact: dense,
          onTap: priorityEditable && !readOnly
              ? () => onEditPriority(badgeContext)
              : _ignoreAction,
        ),
      ),
      onToggleDone: readOnly ? _ignoreAction : onToggleDone,
      onToggleSelection: readOnly ? _ignoreAction : onToggleSelection,
      onOpen: readOnly ? _ignoreAction : onOpen,
      onAddSubtask: readOnly ? _ignoreAction : onAddSubtask,
    );
  }

  static void _ignoreAction() {}

  Widget _priorityBadge({required bool compact, required VoidCallback onTap}) {
    final priority = task.priority?.trim();
    final color = _priorityColor(priority);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: compact ? null : 84,
        constraints: compact
            ? const BoxConstraints(maxWidth: 60, maxHeight: 22)
            : null,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 10,
          vertical: compact ? 2 : 6,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: compact ? color.withValues(alpha: 0.07) : null,
          borderRadius: BorderRadius.circular(compact ? 10 : 12),
          border: Border.all(
            color: compact
                ? color.withValues(alpha: 0.42)
                : const Color(0xFF6B5800),
          ),
        ),
        child: compact
            ? Text(
                priority != null && priority.isNotEmpty ? priority : 'None',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  priority != null && priority.isNotEmpty ? priority : 'None',
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B5800),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
      ),
    );
  }

  Color _priorityColor(String? priority) {
    switch (priority?.trim().toLowerCase()) {
      case 'u1':
      case 'u2':
      case 'u3':
      case 'urgent':
        return const Color(0xFF9B5965);
      case 'imp':
        return const Color(0xFF526D8A);
      case 'today':
      case 'tomorrow':
        return const Color(0xFF557E9B);
      case 'hold':
        return const Color(0xFF99765B);
      case 'process':
        return const Color(0xFF667F89);
      default:
        return const Color(0xFF71808D);
    }
  }
}
