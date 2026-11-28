import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/map_screen/models/task.dart';
import 'package:task_manager/features/map_screen/screens/views/done_tasks_view.dart';

void main() {
  testWidgets('Done Work summary stays on one line on a narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final date = DateTime(2026, 11, 28);
    final tasks = List.generate(
      27,
      (index) => Task(
        'Completed task $index',
        isDone: true,
        completedAt: date.millisecondsSinceEpoch,
        startTime: '12:00AM',
        endTime: '11:00PM',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DoneTasksView(
            tasks: tasks,
            viewType: 'Detailed list',
            calendarBuilder: (_) => const SizedBox.shrink(),
            refreshable: (child) => child,
          ),
        ),
      ),
    );

    final header = find.byKey(
      const ValueKey('done-work-date-2026-11-28T00:00:00.000'),
    );
    final headerCenterY = tester.getRect(header).center.dy;
    for (final label in ['621.00 Hr', 'Score 2484', 'Report']) {
      final item = find.text(label);
      expect(item, findsOneWidget);
      expect(tester.getRect(item).center.dy, closeTo(headerCenterY, 2));
    }
    expect(tester.takeException(), isNull);
  });
}
