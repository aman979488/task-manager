import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/map_screen/models/task.dart';
import 'package:task_manager/features/map_screen/screens/views/done_tasks_view.dart';

void main() {
  testWidgets(
    'Done Work shows blue date header on grey bg, timing, priority and timer icon',
    (tester) async {
      final task = Task(
        'Finished report',
        isDone: true,
        createdDate: '23/10/2026 • 9:00',
        completedAt: DateTime(2026, 10, 23, 16).millisecondsSinceEpoch,
        startTime: '9:00 AM',
        endTime: '10:30 AM',
        workType: 'Personal',
        clientName: 'Personal',
        priority: 'IMP',
      );
      var timerTapped = false;
      Task? openedTask;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DoneTasksView(
              tasks: [task],
              viewType: 'Detailed list',
              calendarBuilder: (_) => const SizedBox.shrink(),
              refreshable: (child) => child,
              onEditTaskTime: (t) async {
                timerTapped = true;
              },
              onOpenTask: (opened) => openedTask = opened,
            ),
          ),
        ),
      );

      // Date header with grey background and blue text
      expect(find.text('23 -10- 2026 Fri_Dur-1.50Hr_Sco-6'), findsOneWidget);
      final headerText = tester.widget<Text>(
        find.text('23 -10- 2026 Fri_Dur-1.50Hr_Sco-6'),
      );
      expect(headerText.style?.color, const Color(0xFF265492));

      // Task title with strikethrough
      expect(find.text('Finished report'), findsOneWidget);
      final taskTitle = tester.widget<Text>(find.text('Finished report'));
      expect(taskTitle.style?.decoration, TextDecoration.lineThrough);

      // Timing under the task
      expect(
        find.text('9:00AM-10:30AM_1.50Hr_0 Days_Personal'),
        findsOneWidget,
      );

      // Priority badge
      expect(find.text('IMP'), findsOneWidget);

      // Timer icon button next to priority badge
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.timer_outlined));
      await tester.pump();
      expect(timerTapped, isTrue);
      expect(openedTask, isNull);
      await tester.tap(find.text('IMP'));
      await tester.pump();
      expect(openedTask, isNull);

      // Excluded action icons (pencil, edit, copy)
      expect(find.byIcon(Icons.edit), findsNothing);
      expect(find.byIcon(Icons.content_copy), findsNothing);
    },
  );

  testWidgets('tapping anywhere in a Done Work task opens task details', (
    tester,
  ) async {
    final task = Task('Finished report', isDone: true);
    Task? openedTask;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DoneTasksView(
            tasks: [task],
            viewType: 'Detailed list',
            calendarBuilder: (_) => const SizedBox.shrink(),
            refreshable: (child) => child,
            onOpenTask: (opened) => openedTask = opened,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('done-task-Finished report')));

    expect(openedTask, same(task));
  });

  testWidgets('groups completed tasks by completion date', (tester) async {
    final firstTask = Task(
      'First task',
      isDone: true,
      createdDate: '28/10/2026 • 9:00',
      completedAt: DateTime(2026, 10, 29, 10).millisecondsSinceEpoch,
      startTime: '09:00AM',
      endTime: '10:00AM',
    );
    final secondTask = Task(
      'Second task',
      isDone: true,
      createdDate: '29/10/2026 • 10:00',
      completedAt: DateTime(2026, 10, 29, 12).millisecondsSinceEpoch,
      startTime: '10:00AM',
      endTime: '12:00PM',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DoneTasksView(
            tasks: [firstTask, secondTask],
            viewType: 'Detailed list',
            calendarBuilder: (_) => const SizedBox.shrink(),
            refreshable: (child) => child,
          ),
        ),
      ),
    );

    expect(find.text('29 -10- 2026 Thu_Dur-3.00Hr_Sco-12'), findsOneWidget);
    expect(find.text('28 -10- 2026 Wed_Dur-0Hr_Sco-0'), findsNothing);
    expect(find.text('First task'), findsOneWidget);
    expect(find.text('Second task'), findsOneWidget);
  });
}
