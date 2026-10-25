import 'package:flutter/material.dart';

import '../../models/task.dart';
import 'task_list_view.dart';

class DoneTasksView extends StatelessWidget {
  const DoneTasksView({
    super.key,
    required this.tasks,
    required this.viewType,
    required this.zoom,
    required this.taskBuilder,
    required this.calendarBuilder,
    required this.refreshable,
  });

  final List<Task> tasks;
  final String viewType;
  final double zoom;
  final Widget Function(Task task, int index) taskBuilder;
  final Widget Function(List<Task> tasks) calendarBuilder;
  final Widget Function(Widget child) refreshable;

  @override
  Widget build(BuildContext context) => TaskListView(
    tasks: tasks,
    viewType: viewType,
    zoom: zoom,
    taskBuilder: taskBuilder,
    calendarBuilder: calendarBuilder,
    refreshable: refreshable,
  );
}
