import 'package:flutter/material.dart';

import '../../models/task.dart';
import 'group_by_view.dart';

class GroupByAssigneeView extends StatelessWidget {
  const GroupByAssigneeView({
    super.key,
    required this.groups,
    required this.pageStorageId,
    required this.onOpenAssignee,
    required this.onOpenTask,
    required this.refreshable,
    this.openAssigneeOnTap = false,
  });

  final Map<String, List<Task>> groups;
  final String pageStorageId;
  final void Function(String name, List<Task> tasks) onOpenAssignee;
  final ValueChanged<Task> onOpenTask;
  final Widget Function(Widget child) refreshable;
  final bool openAssigneeOnTap;

  @override
  Widget build(BuildContext context) => GroupByView(
    groups: groups,
    groupBy: 'Assignee',
    pageStorageId: pageStorageId,
    onOpenAssignee: onOpenAssignee,
    onOpenTask: onOpenTask,
    refreshable: refreshable,
    openAssigneeOnTap: openAssigneeOnTap,
  );
}
