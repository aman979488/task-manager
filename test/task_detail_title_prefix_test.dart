import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/map_screen/models/task.dart';
import 'package:task_manager/features/map_screen/screens/task_detail_page.dart';

void main() {
  testWidgets('title label stays visible while entering a prefix', (
    tester,
  ) async {
    final task = Task('Existing task');

    await tester.pumpWidget(
      MaterialApp(
        home: TaskDetailPage(task: task, onChanged: () {}, onSave: () async {}),
      ),
    );

    await tester.tap(find.text('Existing task'));
    await tester.pumpAndSettle();

    final titleField = find.byKey(const ValueKey('task-title-input'));
    expect(find.text('Existing task'), findsOneWidget);
    expect(titleField, findsOneWidget);
    expect(tester.widget<TextField>(titleField).controller!.text, isEmpty);

    await tester.enterText(titleField, 'Urgent');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(task.title, 'Urgent Existing task');
    expect(find.text('Urgent Existing task'), findsOneWidget);
  });

  testWidgets('Save persists the entered prefix before the existing title', (
    tester,
  ) async {
    final task = Task('Existing task');
    var saveCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: TaskDetailPage(
          task: task,
          onChanged: () {},
          onSave: () async => saveCalled = true,
        ),
      ),
    );

    await tester.tap(find.text('Existing task'));
    await tester.pumpAndSettle();

    final titleField = find.byKey(const ValueKey('task-title-input'));
    expect(find.text('Existing task'), findsOneWidget);
    await tester.enterText(titleField, 'Urgent');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(task.title, 'Urgent Existing task');
    expect(saveCalled, isTrue);
  });
}
