import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/map_screen/models/task.dart';
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
}
