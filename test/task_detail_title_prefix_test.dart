import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/map_screen/models/task.dart';
import 'package:task_manager/features/map_screen/screens/task_detail_page.dart';
import 'package:task_manager/features/map_screen/screens/views/task_step_list_widget.dart';

void main() {
  testWidgets('work name label stays visible and title text is editable', (
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
    expect(titleInput.controller!.text, 'Help');
    expect(titleInput.decoration?.labelText, 'Work Detail');
    expect(titleInput.decoration?.helperText, isNull);
    expect(
      titleInput.decoration?.floatingLabelBehavior,
      FloatingLabelBehavior.auto,
    );
    expect(
      titleInput.decoration?.floatingLabelAlignment,
      FloatingLabelAlignment.start,
    );
    expect(titleInput.decoration?.hintText, isNull);
    expect(titleInput.decoration?.helperText, isNull);
    expect(titleInput.decoration?.border, isA<OutlineInputBorder>());
    expect(
      titleInput.decoration?.contentPadding,
      const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    );
    expect(titleInput.decoration?.suffixIcon, isA<SizedBox>());
    expect(titleInput.style?.fontSize, 16);

    await tester.enterText(titleField, 'Help me');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(task.title, 'Help me');
    expect(find.text('Help me'), findsOneWidget);
  });

  testWidgets('empty work detail shows its placeholder and floats on focus', (
    tester,
  ) async {
    final task = Task('');
    await tester.pumpWidget(
      MaterialApp(
        home: TaskDetailPage(task: task, onChanged: () {}, onSave: () async {}),
      ),
    );

    expect(find.text('Work Detail').first, findsOneWidget);
    await tester.tap(find.text('Work Detail').first);
    await tester.pumpAndSettle();

    final titleField = tester.widget<TextField>(
      find.byKey(const ValueKey('task-title-input')),
    );
    expect(titleField.decoration?.labelText, 'Work Detail');
    expect(
      titleField.decoration?.floatingLabelBehavior,
      FloatingLabelBehavior.auto,
    );
    expect(
      titleField.decoration?.floatingLabelAlignment,
      FloatingLabelAlignment.start,
    );
    expect(titleField.decoration?.hintText, isNull);
    expect(titleField.decoration?.border, isA<OutlineInputBorder>());
    expect(titleField.decoration?.suffixIcon, isA<SizedBox>());
  });

  testWidgets('Save updates the existing work name', (tester) async {
    final task = Task(
      'Help',
      followUp: DateTime(2026, 10, 27, 9).toIso8601String(),
    );
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
    await tester.enterText(titleField, 'Help revised');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(task.title, 'Help revised');
    expect(saveCalled, isTrue);
  });

  testWidgets('save toggle saves without marking the task done', (
    tester,
  ) async {
    final task = Task(
      'Finish report',
      followUp: DateTime(2026, 10, 29, 9).toIso8601String(),
    );
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

    final doneToggle = find.byKey(const ValueKey('task-done-toggle'));
    expect(doneToggle, findsOneWidget);
    expect(
      find.ancestor(of: doneToggle, matching: find.byType(TextField)),
      findsOneWidget,
    );
    await tester.tap(doneToggle);
    await tester.pumpAndSettle();

    expect(task.isDone, isFalse);
    expect(task.completedAt, isNull);
    expect(saveCalled, isTrue);
    expect(find.text('Mark task as done?'), findsNothing);
    expect(tester.widget<Switch>(doneToggle).value, isFalse);
  });

  testWidgets('new task detail keeps the entered title editable', (
    tester,
  ) async {
    final task = Task(
      'Draft title',
      followUp: DateTime(2026, 10, 27, 9).toIso8601String(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TaskDetailPage(
          task: task,
          isNewTask: true,
          onChanged: () {},
          onSave: () async {},
        ),
      ),
    );

    final titleField = find.byKey(const ValueKey('task-title-input'));
    expect(titleField, findsOneWidget);
    expect(
      tester.widget<TextField>(titleField).controller!.text,
      'Draft title',
    );

    await tester.enterText(titleField, 'Draft title continued');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(task.title, 'Draft title continued');
  });

  testWidgets('new task defaults Date & Time to now and shows the year', (
    tester,
  ) async {
    final beforeBuild = DateTime.now();
    final task = Task('Draft title');

    await tester.pumpWidget(
      MaterialApp(
        home: TaskDetailPage(
          task: task,
          isNewTask: true,
          onChanged: () {},
          onSave: () async {},
        ),
      ),
    );
    await tester.pump();

    final afterBuild = DateTime.now();
    final defaultDateTime = DateTime.parse(task.followUp!);
    expect(
      defaultDateTime.isBefore(beforeBuild) ||
          defaultDateTime.isAfter(afterBuild),
      isFalse,
    );
    expect(find.text('Date & Time'), findsOneWidget);
    expect(find.textContaining('/${defaultDateTime.year},'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Date & Time')).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('task-title-input'))).dy,
      ),
    );
    expect(
      tester.getTopLeft(find.text('Date & Time')).dy,
      lessThan(tester.getTopLeft(find.byType(TaskStepListWidget)).dy),
    );
  });

  testWidgets('work name input is limited to 30 words', (tester) async {
    final task = Task('Work');
    await tester.pumpWidget(
      MaterialApp(
        home: TaskDetailPage(task: task, onChanged: () {}, onSave: () async {}),
      ),
    );

    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    final titleField = find.byKey(const ValueKey('task-title-input'));
    final thirtyWords = List<String>.generate(30, (index) => 'word$index');
    await tester.enterText(titleField, thirtyWords.join(' '));
    await tester.enterText(titleField, [...thirtyWords, 'extra'].join(' '));
    await tester.pump();

    final titleInput = tester.widget<TextField>(titleField);
    expect(titleInput.controller!.text, thirtyWords.join(' '));
    expect(titleInput.decoration?.labelText, 'Work Detail');
  });

  testWidgets('older task without date time gets current date and is saved', (
    tester,
  ) async {
    final beforeBuild = DateTime.now();
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

    await tester.pumpAndSettle();

    final afterSave = DateTime.now();
    final defaultDateTime = DateTime.parse(task.followUp!);
    expect(
      defaultDateTime.isBefore(beforeBuild) ||
          defaultDateTime.isAfter(afterSave),
      isFalse,
    );
    expect(saveCalled, isTrue);
    expect(find.text('Date & Time is required'), findsNothing);
  });

  test('follow-up date and time are serialized and restored', () {
    final followUp = DateTime(2026, 10, 27, 9, 30).toIso8601String();
    final task = Task('Help', followUp: followUp);

    final restored = Task.fromMap('task-id', task.toMap());

    expect(restored.followUp, followUp);
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

      final priorityTile = find.ancestor(
        of: find.text('Priority').first,
        matching: find.byType(ListTile),
      );
      final priorityRect = tester.getRect(priorityTile.first);
      expect(
        tester.getTopLeft(find.text('U1')).dy,
        closeTo(priorityRect.bottom + 8, 1),
      );

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

  testWidgets(
    'deadline picker opens just above its button near screen bottom',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      final task = Task('Deadline task');

      await tester.pumpWidget(
        MaterialApp(
          home: TaskDetailPage(
            task: task,
            onChanged: () {},
            onSave: () async {},
          ),
        ),
      );

      await tester.ensureVisible(find.text('Deadline'));
      await tester.tap(find.text('Deadline'));
      await tester.pumpAndSettle();

      final deadlineTile = find.ancestor(
        of: find.text('Deadline').first,
        matching: find.byType(ListTile),
      );
      final deadlineRect = tester.getRect(deadlineTile.first);
      final lastOptionRect = tester.getRect(find.text('Today (6 PM)'));
      expect(lastOptionRect.bottom, lessThanOrEqualTo(deadlineRect.top));
      expect(deadlineRect.top - lastOptionRect.bottom, lessThanOrEqualTo(8));
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
