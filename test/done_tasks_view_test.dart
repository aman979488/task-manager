import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/map_screen/models/task.dart';
import 'package:task_manager/features/map_screen/screens/views/done_tasks_view.dart';

void main() {
  testWidgets('Done Work follows date, timing, and client layout', (
    tester,
  ) async {
    final task = Task(
      'Finished report',
      isDone: true,
      createdDate: '23/10/2026 • 9:00',
      completedAt: DateTime(2026, 10, 24, 16).millisecondsSinceEpoch,
      startTime: '9:00 AM',
      endTime: '10:30 AM',
      workType: 'Personal',
      clientName: 'Personal',
      priority: 'IMP',
    );
    var edited = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DoneTasksView(
            tasks: [task],
            viewType: 'Detailed list',
            calendarBuilder: (_) => const SizedBox.shrink(),
            refreshable: (child) => child,
            onEditTaskTime: (task) async {
              edited = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('Fri, Oct 23, 2026'), findsOneWidget);
    expect(find.text('Finished report'), findsOneWidget);
    expect(find.text('9:00 AM - 10:30 AM'), findsOneWidget);
    expect(find.textContaining('1.50'), findsNothing);
    expect(find.text('Personal (Personal)'), findsOneWidget);
    expect(find.text('IMP'), findsOneWidget);
    expect(find.byIcon(Icons.flag_outlined), findsNothing);
    expect(find.byTooltip('Edit task time'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit task time'));
    await tester.pump();
    expect(edited, isTrue);
  });
}
