import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/map_screen/models/task.dart';
import 'package:task_manager/features/map_screen/screens/task_detail_page.dart';

void main() {
  testWidgets('title label stays visible and entered text appends to title', (
    tester,
  ) async {
    final task = Task('Help');

    await tester.pumpWidget(
      MaterialApp(
        home: TaskDetailPage(task: task, onChanged: () {}, onSave: () async {}),
      ),
    );

    await tester.tap(find.text('Help'));
    await tester.pumpAndSettle();

    final titleField = find.byKey(const ValueKey('task-title-input'));
    expect(find.text('Help'), findsOneWidget);
    expect(titleField, findsOneWidget);
    final titleInput = tester.widget<TextField>(titleField);
    expect(titleInput.controller!.text, isEmpty);
    expect(titleInput.decoration?.labelText, 'Help');
    expect(
      titleInput.decoration?.floatingLabelBehavior,
      FloatingLabelBehavior.always,
    );
    expect(titleInput.decoration?.hintStyle?.color, Colors.grey.shade400);
    expect(titleInput.decoration?.border, isA<OutlineInputBorder>());
    expect(
      titleInput.decoration?.contentPadding,
      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
    expect(titleInput.style?.fontSize, 18);

    await tester.enterText(titleField, 'me');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(task.title, 'Help me');
    expect(find.text('Help me'), findsOneWidget);
  });

  testWidgets('Save appends entered text after the existing title', (
    tester,
  ) async {
    final task = Task('Help');
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

    await tester.tap(find.text('Help'));
    await tester.pumpAndSettle();

    final titleField = find.byKey(const ValueKey('task-title-input'));
    expect(find.text('Help'), findsOneWidget);
    await tester.enterText(titleField, 'me');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(task.title, 'Help me');
    expect(saveCalled, isTrue);
  });

  testWidgets('title editor remains visible when the keyboard opens', (
    tester,
  ) async {
    addTearDown(tester.view.resetViewInsets);
    final task = Task('Help');

    await tester.pumpWidget(
      MaterialApp(
        home: TaskDetailPage(task: task, onChanged: () {}, onSave: () async {}),
      ),
    );
    await tester.tap(find.text('Help'));
    await tester.pump();

    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();

    final titleField = find.byKey(const ValueKey('task-title-input'));
    final fieldRect = tester.getRect(titleField);
    final visibleScreenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio -
        tester.view.viewInsets.bottom / tester.view.devicePixelRatio;

    expect(
      fieldRect.top,
      greaterThan(tester.getRect(find.byType(AppBar)).bottom),
    );
    expect(fieldRect.bottom, lessThan(visibleScreenHeight));
    expect(find.text('Help'), findsOneWidget);
  });

  testWidgets(
    'priority picker exposes every option and stays open while scrolling',
    (tester) async {
      final task = Task('Priority task');

      await tester.pumpWidget(
        MaterialApp(
          home: TaskDetailPage(
            task: task,
            onChanged: () {},
            onSave: () async {},
          ),
        ),
      );

      await tester.ensureVisible(find.text('Priority'));
      await tester.tap(find.text('Priority'));
      await tester.pumpAndSettle();

      expect(find.text('U1'), findsOneWidget);
      expect(find.text('U2'), findsOneWidget);
      expect(find.text('U3'), findsOneWidget);

      await tester.drag(find.byType(ListView).last, const Offset(0, -240));
      await tester.pumpAndSettle();

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Tomorrow'), findsOneWidget);

      await tester.drag(find.byType(ListView).last, const Offset(0, -320));
      await tester.pumpAndSettle();

      expect(find.text('Free'), findsOneWidget);
      await tester.tap(find.text('Free'));
      await tester.pumpAndSettle();

      expect(task.priority, 'Free');
    },
  );

  testWidgets('priority picker closes when tapping or scrolling outside', (
    tester,
  ) async {
    final task = Task('Priority task');

    await tester.pumpWidget(
      MaterialApp(
        home: TaskDetailPage(task: task, onChanged: () {}, onSave: () async {}),
      ),
    );

    await tester.ensureVisible(find.text('Priority'));
    await tester.tap(find.text('Priority'));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('U1'), findsNothing);

    await tester.tap(find.text('Priority'));
    await tester.pumpAndSettle();
    expect(find.text('U1'), findsOneWidget);

    await tester.dragFrom(const Offset(10, 10), const Offset(0, 120));
    await tester.pumpAndSettle();
    expect(find.text('U1'), findsNothing);
  });
}
