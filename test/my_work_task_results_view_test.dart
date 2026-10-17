import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/map_screen/models/task.dart';
import 'package:task_manager/features/map_screen/screens/views/my_work_task_results_view.dart';

void main() {
  testWidgets('calendar results show only tasks scheduled on selected day', (
    tester,
  ) async {
    final todayTask = Task(
      'Today task',
      deadline: DateTime(2026, 10, 14, 17).toIso8601String(),
    );
    final tomorrowTask = Task(
      'Tomorrow task',
      deadline: DateTime(2026, 10, 15, 9).toIso8601String(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyWorkTaskResultsView(
            tasks: [todayTask, tomorrowTask],
            viewType: 'Calendar',
            zoom: 1,
            selectedDate: DateTime(2026, 10, 14),
            onDateChanged: (_) {},
            scheduledDate: (task) =>
                DateTime.tryParse(task.deadline ?? task.reminder ?? ''),
            taskBuilder: (task, index) => Text(task.title),
            detailedTaskBuilder: (task) => Text(task.title),
          ),
        ),
      ),
    );

    expect(find.text('Today task'), findsOneWidget);
    expect(find.text('Tomorrow task'), findsNothing);
  });
}
