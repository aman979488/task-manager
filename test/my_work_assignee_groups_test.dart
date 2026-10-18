import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/map_screen/models/task.dart';
import 'package:task_manager/features/map_screen/screens/assignee_tasks_view.dart';
import 'package:task_manager/features/map_screen/screens/views/group_by_assignee_view.dart';

void main() {
  testWidgets('assignee groups expand to show their tasks', (tester) async {
    final amanTasks = [
      Task('Aman task 1', assignee: 'Aman'),
      Task('Aman task 2', assignee: 'Aman'),
    ];
    final assigneeGroups = {'Aman': amanTasks};

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupByAssigneeView(
            groups: assigneeGroups,
            pageStorageId: 'assignees',
            onOpenAssignee: (_, _) {},
            onOpenTask: (_) {},
            refreshable: (child) => child,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Aman').first);
    await tester.pumpAndSettle();
    expect(find.text('Aman task 1'), findsOneWidget);
    expect(find.text('Aman task 2'), findsOneWidget);
  });

  testWidgets('tapping an assign-tab name opens its assignee view', (
    tester,
  ) async {
    final amanTasks = [Task('Aman task', assignee: 'Aman')];
    String? openedName;
    List<Task>? openedTasks;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupByAssigneeView(
            groups: {'Aman': amanTasks},
            pageStorageId: 'assign',
            openAssigneeOnTap: true,
            onOpenAssignee: (name, tasks) {
              openedName = name;
              openedTasks = tasks;
            },
            onOpenTask: (_) {},
            refreshable: (child) => child,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Aman').first);
    expect(openedName, 'Aman');
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
            Task('Tomorrow task', priority: 'Tomorrow', assignee: 'Aman'),
          ],
        ),
      ),
    );

    expect(find.text('URGENT'), findsOneWidget);
    expect(find.text('TOMORROW'), findsOneWidget);
  });

  testWidgets('assignee state survives switching tabs', (tester) async {
    final bucket = PageStorageBucket();
    final groups = {
      'Aman': [Task('Aman task', assignee: 'Aman')],
    };
    var selectedTab = 0;

    Widget buildScreen() => MaterialApp(
      home: PageStorage(
        bucket: bucket,
        child: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () =>
                      setState(() => selectedTab = 1 - selectedTab),
                  child: const Text('Switch tab'),
                ),
                Expanded(
                  child: selectedTab == 0
                      ? GroupByAssigneeView(
                          key: const PageStorageKey('assign-tab'),
                          groups: groups,
                          pageStorageId: 'assign-tab',
                          onOpenAssignee: (_, _) {},
                          onOpenTask: (_) {},
                          refreshable: (child) => child,
                        )
                      : const Center(child: Text('Other tab')),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(buildScreen());
    await tester.tap(find.text('Aman').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Switch tab'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Switch tab'));
    await tester.pumpAndSettle();

    expect(find.text('Aman task'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
