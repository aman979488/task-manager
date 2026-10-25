import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/map_screen/models/task.dart';
import 'package:task_manager/features/map_screen/screens/assignee_tasks_view.dart';
import 'package:task_manager/features/map_screen/screens/views/group_by_assignee_view.dart';
import 'package:task_manager/features/map_screen/screens/views/my_work_view.dart';

void main() {
  testWidgets('My Work layout expands dynamically named assignee sections', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyWorkView(
            sections: {
              'Aman': [Task('Aman task', assignee: 'Aman')],
            },
            sectionNames: const ['Aman'],
            taskResultsBuilder: (tasks) =>
                Column(children: [for (final task in tasks) Text(task.title)]),
          ),
        ),
      ),
    );

    expect(find.text('AMAN'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('assignee group row opens its task view', (tester) async {
    final amanTasks = [
      Task('Aman task 1', assignee: 'Aman'),
      Task('Aman task 2', assignee: 'Aman'),
    ];
    final assigneeGroups = {'Aman': amanTasks};
    String? openedAssigneeName;
    List<Task>? openedTasks;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupByAssigneeView(
            groups: assigneeGroups,
            pageStorageId: 'assignees',
            onOpenAssignee: (name, tasks) {
              openedAssigneeName = name;
              openedTasks = tasks;
            },
            onOpenTask: (_) {},
            refreshable: (child) => child,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
    await tester.tap(find.text('Aman'));
    await tester.pumpAndSettle();
    expect(openedAssigneeName, 'Aman');
    expect(openedTasks, amanTasks);
  });

  testWidgets('assign row opens the assignee task view on tap', (tester) async {
    final amanTasks = [Task('Aman task', assignee: 'Aman')];
    String? openedAssigneeName;
    List<Task>? openedTasks;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupByAssigneeView(
            groups: {'Aman': amanTasks},
            pageStorageId: 'assign',
            onOpenAssignee: (name, tasks) {
              openedAssigneeName = name;
              openedTasks = tasks;
            },
            onOpenTask: (_) {},
            refreshable: (child) => child,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
    await tester.tap(find.text('Aman'));
    await tester.pumpAndSettle();

    expect(openedAssigneeName, 'Aman');
    expect(openedTasks, amanTasks);
  });

  testWidgets('assignee task view groups tasks into My Work sections', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AssigneeTasksView(
          assigneeName: 'Aman',
          tasks: [
            Task('Urgent task', priority: 'Urgent', assignee: 'Aman'),
            Task('Today task', priority: 'Today', assignee: 'Aman'),
            Task('Tomorrow task', priority: 'Tomorrow', assignee: 'Aman'),
            Task('Later task', priority: 'Later', assignee: 'Aman'),
          ],
          onOpenTask: (_) {},
        ),
      ),
    );

    expect(find.text('URGENT'), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('TOMORROW'), findsOneWidget);
    expect(find.text('LATER'), findsOneWidget);
  });

  testWidgets('assignee task view adds and displays a task for that assignee', (
    tester,
  ) async {
    final existingTask = Task(
      'Existing task',
      priority: 'Today',
      assignee: 'Aman',
    );
    final newTask = Task('New task', priority: 'Monitor', assignee: 'Aman');
    var addedTask = false;

    await tester.pumpWidget(
      MaterialApp(
        home: AssigneeTasksView(
          assigneeName: 'Aman',
          tasks: [existingTask],
          onOpenTask: (_) {},
          onAddTask: () async {
            addedTask = true;
            return [existingTask, newTask];
          },
        ),
      ),
    );

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byTooltip('Add task for Aman'), findsOneWidget);
    await tester.tap(find.byTooltip('Add task for Aman'));
    await tester.pumpAndSettle();

    expect(addedTask, isTrue);
    expect(find.text('2 Pending • 0 Done'), findsOneWidget);
    expect(find.text('MONITOR'), findsOneWidget);
  });
}
