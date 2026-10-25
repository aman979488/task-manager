import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/map_screen/models/task.dart';
import 'package:task_manager/features/map_screen/screens/widgets/map_task_list_item.dart';
import 'package:task_manager/features/map_screen/screens/widgets/task_tile.dart';

void main() {
  testWidgets('capitalizes the first character of the displayed task title', (
    tester,
  ) async {
    final task = Task('call client');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskTile(
            task: task,
            isSelected: false,
            taskName: task.title,
            description: null,
            priorityWidget: const SizedBox.shrink(),
            onToggleDone: () {},
            onToggleSelection: () {},
            onOpen: () {},
            onAddSubtask: () {},
          ),
        ),
      ),
    );

    expect(find.text('Call client'), findsOneWidget);
    expect(task.title, 'call client');
  });

  testWidgets('supports single-line ellipsis for long task titles', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskTile(
            task: Task('A task with a long title'),
            isSelected: false,
            taskName: 'A task with a long title',
            description: null,
            taskNameMaxLines: 1,
            priorityWidget: const SizedBox.shrink(),
            onToggleDone: () {},
            onToggleSelection: () {},
            onOpen: () {},
            onAddSubtask: () {},
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('A task with a long title'));
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);
  });

  testWidgets('uses single-line ellipsis by default in task lists', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskTile(
            task: Task('A task with a long title'),
            isSelected: false,
            taskName: 'A task with a long title',
            description: null,
            priorityWidget: const SizedBox.shrink(),
            onToggleDone: () {},
            onToggleSelection: () {},
            onOpen: () {},
            onAddSubtask: () {},
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('A task with a long title'));
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);
  });

  testWidgets('task list item keeps titles on one line when unspecified', (
    tester,
  ) async {
    const taskTitle = 'A long task title that should end with ellipsis';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapTaskListItem(
            task: Task(taskTitle),
            viewType: 'Detailed list',
            isSelected: false,
            taskName: taskTitle,
            description: null,
            onEditPriority: (_) {},
            onToggleDone: () {},
            onToggleSelection: () {},
            onOpen: () {},
            onAddSubtask: () {},
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text(taskTitle));
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);
  });

  testWidgets('read-only task list item can show a timer action', (
    tester,
  ) async {
    var timerActionCalled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapTaskListItem(
            task: Task('Completed task', isDone: true),
            viewType: 'Detailed list',
            isSelected: false,
            taskName: 'Completed task',
            description: null,
            onEditPriority: (_) {},
            readOnly: true,
            onToggleDone: () {},
            onToggleSelection: () {},
            onOpen: () {},
            onAddSubtask: () {},
            onReadOnlyAction: () => timerActionCalled = true,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    await tester.tap(find.byTooltip('Set task time'));
    expect(timerActionCalled, isTrue);
  });

  testWidgets('priority badge stays compact and fits text at 140% zoom', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: Scaffold(
            body: MapTaskListItem(
              task: Task('Task', priority: 'Tomorrow'),
              viewType: 'Detailed list',
              dense: true,
              isSelected: false,
              taskName: 'Task',
              description: null,
              onEditPriority: (_) {},
              onToggleDone: () {},
              onToggleSelection: () {},
              onOpen: () {},
              onAddSubtask: () {},
            ),
          ),
        ),
      ),
    );

    final badge = find
        .ancestor(of: find.text('Tomorrow'), matching: find.byType(Container))
        .first;
    final badgeBox = tester.getRect(badge);
    final textBox = tester.getRect(find.text('Tomorrow'));

    expect(badgeBox.width, lessThanOrEqualTo(60));
    expect(badgeBox.height, lessThanOrEqualTo(22));
    expect(
      find.ancestor(
        of: find.text('Tomorrow'),
        matching: find.byType(FittedBox),
      ),
      findsOneWidget,
    );
    expect((badgeBox.center.dy - textBox.center.dy).abs(), lessThan(1));
    expect(tester.takeException(), isNull);
  });
}
