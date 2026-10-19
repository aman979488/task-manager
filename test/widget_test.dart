import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/map_screen/models/task.dart';
import 'package:task_manager/features/map_screen/screens/views/my_work_view.dart';

void main() {
  test('Task model initialization smoke test', () {
    final task = Task('Smoke Test Task', priority: 'High');

    expect(task.title, 'Smoke Test Task');
    expect(task.priority, 'High');
    expect(task.isDone, isFalse);

    final map = task.toMap();
    expect(map['title'], 'Smoke Test Task');
    expect(map['priority'], 'High');
  });

  testWidgets('My Work shows an empty-state message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MyWorkView(
          sections: const {},
          taskResultsBuilder: (_) => const SizedBox.shrink(),
          emptyMessage: 'No tasks in My Work.',
        ),
      ),
    );
    expect(find.text('No tasks in My Work.'), findsOneWidget);
    expect(find.text('No tasks in My Work.'), findsOneWidget);
    expect(find.text('No tasks in My Work.'), findsOneWidget);
  });
  testWidgets('triple-tap toggles the second populated My Work section', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyWorkView(
            sections: {
              'Urgent Works': [Task('Urgent task')],
              'IMP Works': [Task('Important task')],
            },
            taskResultsBuilder: (tasks) => Text(tasks.single.title),
          ),
        ),
      ),
    );

    Future<void> tripleTapBlankArea() async {
      for (var tap = 0; tap < 3; tap++) {
        await tester.tapAt(const Offset(24, 500));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 400));
    }

    expect(find.text('Important task'), findsNothing);
    await tripleTapBlankArea();
    expect(find.text('Important task'), findsOneWidget);

    await tripleTapBlankArea();
    expect(find.text('Important task'), findsNothing);
  });
}
