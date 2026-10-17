import 'package:flutter/material.dart';

import '../../models/task.dart';

class MyWorkTaskResultsView extends StatelessWidget {
  const MyWorkTaskResultsView({
    super.key,
    required this.tasks,
    required this.viewType,
    required this.zoom,
    required this.selectedDate,
    required this.onDateChanged,
    required this.scheduledDate,
    required this.taskBuilder,
    required this.detailedTaskBuilder,
  });

  final List<Task> tasks;
  final String viewType;
  final double zoom;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  final DateTime? Function(Task task) scheduledDate;
  final Widget Function(Task task, int index) taskBuilder;
  final Widget Function(Task task) detailedTaskBuilder;

  @override
  Widget build(BuildContext context) {
    if (viewType == 'Calendar') {
      final selectedDay = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
      );
      final dayTasks = tasks.where((task) {
        final scheduled = scheduledDate(task);
        return scheduled != null &&
            scheduled.year == selectedDay.year &&
            scheduled.month == selectedDay.month &&
            scheduled.day == selectedDay.day;
      }).toList();

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CalendarDatePicker(
            initialDate: selectedDate,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            onDateChanged: onDateChanged,
          ),
          const Divider(height: 1),
          if (dayTasks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No tasks scheduled for this day.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...dayTasks.map((task) => detailedTaskBuilder(task)),
        ],
      );
    }

    if (tasks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(24, 8, 24, 20),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'No tasks in this section.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(zoom)),
      child: viewType == 'Grid'
          ? GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 260,
                mainAxisExtent: 130 + (65 * (zoom - 1)),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: tasks.length,
              itemBuilder: (context, index) => taskBuilder(tasks[index], index),
            )
          : Column(
              children: tasks
                  .asMap()
                  .entries
                  .map((entry) => taskBuilder(entry.value, entry.key))
                  .toList(),
            ),
    );
  }
}
