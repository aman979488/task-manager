import 'package:flutter/material.dart';

import '../../models/task.dart';

class TaskListView extends StatelessWidget {
  const TaskListView({
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
  Widget build(BuildContext context) {
    if (viewType == 'Calendar') return calendarBuilder(tasks);
    if (tasks.isEmpty) {
      return refreshable(
        ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(
              height: 240,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No tasks found in this category.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return refreshable(
      MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(zoom)),
        child: viewType == 'Grid'
            ? GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 260,
                  mainAxisExtent: 150 + (80 * (zoom - 1)),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: tasks.length,
                itemBuilder: (context, index) =>
                    taskBuilder(tasks[index], index),
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
                itemCount: tasks.length,
                itemBuilder: (context, index) =>
                    taskBuilder(tasks[index], index),
              ),
      ),
    );
  }
}
