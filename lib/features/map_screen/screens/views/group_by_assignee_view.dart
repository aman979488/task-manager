import 'package:flutter/material.dart';

import '../../models/task.dart';
import 'group_by_view.dart';

class GroupByAssigneeView extends StatelessWidget {
  const GroupByAssigneeView({
    super.key,
    required this.groups,
    required this.onOpenAssignee,
    required this.onOpenTask,
    required this.refreshable,
  });

  final Map<String, List<Task>> groups;
  final void Function(String name, List<Task> tasks) onOpenAssignee;
  final ValueChanged<Task> onOpenTask;
  final Widget Function(Widget child) refreshable;

  @override
  Widget build(BuildContext context) => GroupByView(
    groups: groups,
    groupBy: 'Assignee',
    onOpenAssignee: onOpenAssignee,
    onOpenTask: onOpenTask,
    refreshable: refreshable,
  );
}
