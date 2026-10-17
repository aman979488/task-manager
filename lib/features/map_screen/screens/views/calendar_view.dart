import 'package:flutter/material.dart';

import '../../models/task.dart';

class CalendarView extends StatelessWidget {
  const CalendarView({
    super.key,
    required this.tasks,
    required this.selectedDate,
    required this.onDateChanged,
    required this.scheduledDate,
    required this.taskBuilder,
    required this.refreshable,
  });

  final List<Task> tasks;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  final DateTime? Function(Task task) scheduledDate;
  final Widget Function(Task task, int index) taskBuilder;
  final Widget Function(Widget child) refreshable;

  @override
  Widget build(BuildContext context) {
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

    return refreshable(
      SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
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
              ...dayTasks.asMap().entries.map(
                (entry) => taskBuilder(entry.value, entry.key),
              ),
          ],
        ),
      ),
    );
  }
}
