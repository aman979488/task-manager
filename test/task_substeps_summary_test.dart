import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/map_screen/models/task.dart';
import 'package:task_manager/features/map_screen/screens/widgets/map_task_list_item.dart';
import 'package:task_manager/features/map_screen/screens/widgets/task_substeps_summary.dart';

void main() {
  testWidgets('shows substep titles and completion state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskSubstepsSummary(
            steps: [
              TaskStep(title: 'Call the client'),
              TaskStep(title: 'Send the details', isDone: true),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Call the client'), findsOneWidget);
    expect(find.text('Send the details'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
  });

  testWidgets('task rows hide substep titles in each list view', (
    tester,
  ) async {
    for (final viewType in ['Detailed list', 'List', 'Grid']) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapTaskListItem(
              task: Task(
                'Main task',
                steps: [TaskStep(title: 'Internal substep')],
              ),
              viewType: viewType,
              isSelected: false,
              taskName: 'Main task',
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

      expect(find.text('Main task'), findsOneWidget);
      expect(find.text('Internal substep'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('completed task priority badge does not open the editor', (
    tester,
  ) async {
    var editCount = 0;
    var openCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapTaskListItem(
            task: Task('Completed task', priority: 'U1', isDone: true),
            viewType: 'Detailed list',
            isSelected: false,
            taskName: 'Completed task',
            description: null,
            onEditPriority: (_) => editCount++,
            readOnly: true,
            onToggleDone: () {},
            onToggleSelection: () {},
            onOpen: () => openCount++,
            onAddSubtask: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('U1'));
    await tester.tap(find.text('Completed task'));
    expect(editCount, 0);
    expect(openCount, 0);
    expect(find.text('U1'), findsOneWidget);
    expect(find.text('Completed task'), findsOneWidget);
  });
}
