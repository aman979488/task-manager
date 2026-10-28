import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/map_screen/models/task.dart';
import 'package:task_manager/features/map_screen/screens/assignee_tasks_view.dart';
import 'package:task_manager/features/map_screen/screens/views/group_by_assignee_view.dart';
import 'package:task_manager/features/map_screen/screens/views/group_by_view.dart';
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

  testWidgets('group-by expanded tasks use the shared My Work renderer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupByView(
            groups: {
              'Urgent': [Task('Urgent task', priority: 'Urgent')],
            },
            groupBy: 'Priority',
            pageStorageId: 'group-by-priority-test',
            onOpenAssignee: (_, _) {},
            onOpenTask: (_) {},
            refreshable: (child) => child,
            taskResultsBuilder: (tasks) => Column(
              children: [
                for (final task in tasks) Text('Shared: ${task.title}'),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Urgent'));
    await tester.pumpAndSettle();

    expect(find.text('Shared: Urgent task'), findsOneWidget);
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

  testWidgets('assignee task view uses the shared My Work task renderer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AssigneeTasksView(
          assigneeName: 'Aman',
          tasks: [Task('Urgent task', priority: 'Urgent', assignee: 'Aman')],
          onOpenTask: (_) {},
          taskResultsBuilder: (tasks) => Column(
            children: [for (final task in tasks) Text('Shared: ${task.title}')],
          ),
        ),
      ),
    );

    final scrollViewRect = tester.getRect(find.byType(CustomScrollView));
    final blankSpaceTapPoint = Offset(
      scrollViewRect.left + 20,
      scrollViewRect.top + 300,
    );
    await tester.tapAt(blankSpaceTapPoint);
    await tester.tapAt(blankSpaceTapPoint);
    await tester.tapAt(blankSpaceTapPoint);
    await tester.pump(const Duration(milliseconds: 351));
    await tester.pumpAndSettle();

    expect(find.text('Shared: Urgent task'), findsOneWidget);
  });

  testWidgets('assignee task displays priority and substeps', (tester) async {
    final task = Task(
      'Prepare proposal',
      priority: 'Today',
      assignee: 'Aman',
      steps: [
        TaskStep(title: 'Review requirements'),
        TaskStep(title: 'Send draft'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AssigneeTasksView(
          assigneeName: 'Aman',
          tasks: [task],
          onOpenTask: (_) {},
        ),
      ),
    );

    final scrollViewRect = tester.getRect(find.byType(CustomScrollView));
    final blankSpaceTapPoint = Offset(
      scrollViewRect.left + 20,
      scrollViewRect.top + 300,
    );
    await tester.tapAt(blankSpaceTapPoint);
    await tester.tapAt(blankSpaceTapPoint);
    await tester.tapAt(blankSpaceTapPoint);
    await tester.pump(const Duration(milliseconds: 351));
    await tester.pumpAndSettle();

    expect(find.text('Prepare proposal'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Review requirements'), findsOneWidget);
    expect(find.text('Send draft'), findsOneWidget);
  });

  testWidgets('assignee task can add a substep without a chevron', (
    tester,
  ) async {
    final task = Task('Prepare proposal', priority: 'Today', assignee: 'Aman');

    await tester.pumpWidget(
      MaterialApp(
        home: AssigneeTasksView(
          assigneeName: 'Aman',
          tasks: [task],
          onOpenTask: (_) {},
          onAddSubstep: (task) async {
            task.steps.add(TaskStep(title: 'Review requirements'));
          },
        ),
      ),
    );

    final scrollViewRect = tester.getRect(find.byType(CustomScrollView));
    final blankSpaceTapPoint = Offset(
      scrollViewRect.left + 20,
      scrollViewRect.top + 300,
    );
    await tester.tapAt(blankSpaceTapPoint);
    await tester.tapAt(blankSpaceTapPoint);
    await tester.tapAt(blankSpaceTapPoint);
    await tester.pump(const Duration(milliseconds: 351));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Add subtask'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

    await tester.tap(find.byTooltip('Add subtask'));
    await tester.pumpAndSettle();

    expect(find.text('Review requirements'), findsOneWidget);
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
