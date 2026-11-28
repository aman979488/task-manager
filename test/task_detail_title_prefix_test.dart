import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/flash/flash_alert_service.dart';
import 'package:task_manager/features/map_screen/models/task.dart';
import 'package:task_manager/features/map_screen/screens/task_detail_page.dart';
import 'package:task_manager/features/map_screen/screens/views/task_step_list_widget.dart';

void main() {
  testWidgets('Add notification schedules the selected template', (
    tester,
  ) async {
    TaskNotification? scheduledNotification;
    final reminderAt = DateTime(2026, 11, 28, 17);
    final task = Task(
      'Help',
      assignee: 'Nirmal',
      assigneeUid: 'Nirmal',
      reminder: reminderAt.toIso8601String(),
      followUp: DateTime.now().toIso8601String(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TaskDetailPage(
          task: task,
          onChanged: () {},
          onSave: () async {},
          loadNotificationTemplates: () async => const [
            FlashTemplate(label: 'Work update', text: 'Work update message'),
          ],
          onScheduleFlashNotification: (notification, task) async {
            scheduledNotification = notification;
            expect(task.assignee, 'Nirmal');
            return true;
          },
        ),
      ),
    );

    final flashButton = find.byTooltip('Show notification templates');
    expect(flashButton, findsOneWidget);
    await tester.tap(flashButton);
    await tester.pumpAndSettle();

    expect(find.text('Template'), findsOneWidget);
    expect(find.text('Choose a template'), findsNothing);
    await tester.tap(find.text('Template'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a template'), findsOneWidget);
    expect(find.text('Send to'), findsNothing);
    await tester.tap(find.text('Work update'));
    await tester.pumpAndSettle();
    expect(find.text('Add notification'), findsOneWidget);

    final templateCard = find
        .ancestor(
          of: find.text('Template'),
          matching: find.byType(AnimatedContainer),
        )
        .first;
    final addNotificationCard = find
        .ancestor(
          of: find.text('Add notification'),
          matching: find.byType(AnimatedContainer),
        )
        .first;
    final reminderCard = find
        .ancestor(
          of: find.text('Remind Me'),
          matching: find.byType(AnimatedContainer),
        )
        .first;
    expect(
      tester.getSize(templateCard).width,
      tester.getSize(reminderCard).width,
    );
    expect(
      tester.getSize(addNotificationCard).width,
      tester.getSize(reminderCard).width,
    );
    final templateDecoration =
        tester.widget<AnimatedContainer>(templateCard).decoration
            as BoxDecoration;
    final colorValue = templateDecoration.color!.toARGB32();
    expect((colorValue >> 16) & 0xff, greaterThan(colorValue & 0xff));
    expect((colorValue >> 8) & 0xff, greaterThan(colorValue & 0xff));
    await tester.tap(find.text('Add notification'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10 minutes before'));
    await tester.pumpAndSettle();
    expect(scheduledNotification?.templateLabel, 'Work update');
    expect(scheduledNotification?.message, 'Work update message');
    expect(scheduledNotification?.timing, '10 minutes before');
    expect(
      scheduledNotification?.scheduledAt,
      reminderAt.subtract(const Duration(minutes: 10)).toIso8601String(),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reminder and deadline timing stay on one line', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    final task = Task(
      'Help',
      reminder: DateTime(2026, 11, 28, 14, 30).toIso8601String(),
      deadline: DateTime(2026, 11, 28, 16).toIso8601String(),
      followUp: DateTime.now().toIso8601String(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TaskDetailPage(task: task, onChanged: () {}, onSave: () async {}),
      ),
    );

    for (final label in ['Remind Me', 'Deadline']) {
      final labelText = tester.widget<Text>(find.text(label));
      expect(labelText.maxLines, 1);
    }
    expect(find.text('11/28/26 2:30PM'), findsOneWidget);
    expect(find.text('11/28/26 4:00PM'), findsOneWidget);
  });

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

  testWidgets('Extend deadline opens picker and saves the selected deadline', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    final initialDeadline = DateTime(2026, 10, 27, 9);
    final task = Task(
      'Prepare report',
      deadline: initialDeadline.toIso8601String(),
    );
    var saveCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: TaskDetailPage(task: task, onSave: () async => saveCalled = true),
      ),
    );

    final extendButton = find.byIcon(Icons.event_repeat);
    await tester.ensureVisible(extendButton);
    await tester.tap(extendButton);
    await tester.pumpAndSettle();

    expect(find.text('DATE'), findsOneWidget);
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    expect(saveCalled, isTrue);
    expect(task.deadline, initialDeadline.toIso8601String());
  });

  testWidgets('goal week label and value use separate lines', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    final task = Task('Weekly goal', weekKey: '2026-11-W2');

    await tester.pumpWidget(
      MaterialApp(
        home: TaskDetailPage(task: task, onChanged: () {}, onSave: () async {}),
      ),
    );

    await tester.ensureVisible(find.text('View more'));
    await tester.tap(find.text('View more'));
    await tester.pumpAndSettle();
    expect(find.text('View less'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Goal (week)'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    final goalTileFinder = find.ancestor(
      of: find.text('Goal (week)'),
      matching: find.byType(ListTile),
    );
    final goalTile = tester.widget<ListTile>(goalTileFinder.first);

    expect(goalTile.title, isA<Text>());
    expect(goalTile.subtitle, isA<Text>());
    expect(goalTile.trailing, isNull);
    expect(find.text('November Week 2 (11/8-11/14, 2026)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('done toggle saves and marks the task done', (tester) async {
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

    expect(task.isDone, isTrue);
    expect(task.completedAt, isNotNull);
    expect(saveCalled, isTrue);
    expect(find.text('Mark task as done?'), findsNothing);
    expect(tester.widget<Switch>(doneToggle).value, isTrue);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('task-title-input')))
          .style
          ?.decoration,
      TextDecoration.lineThrough,
    );
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

  testWidgets('back saves a newly entered task title', (tester) async {
    var saveCount = 0;
    bool? savedResult;
    var detailClosed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                savedResult = await Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(
                    builder: (_) => TaskDetailPage(
                      task: Task('Draft title'),
                      isNewTask: true,
                      onChanged: () {},
                      onSave: () async => saveCount++,
                    ),
                  ),
                );
                detailClosed = true;
              },
              child: const Text('Open task'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open task'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('task-title-input')),
      'Saved task title',
    );
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(saveCount, 1);
    expect(detailClosed, isTrue);
    expect(savedResult, isTrue);
  });

  testWidgets('keyboard Done saves a newly entered task title', (tester) async {
    var saveCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: TaskDetailPage(
          task: Task('Draft title'),
          isNewTask: true,
          onChanged: () {},
          onSave: () async => saveCount++,
        ),
      ),
    );

    final titleField = find.byKey(const ValueKey('task-title-input'));
    await tester.enterText(titleField, 'Saved from keyboard');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(saveCount, 1);
    expect(find.text('Saved from keyboard'), findsOneWidget);
  });

  testWidgets('leaving the new task title field saves without closing detail', (
    tester,
  ) async {
    var saveCount = 0;
    bool? savedResult;
    var detailClosed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                savedResult = await Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(
                    builder: (_) => TaskDetailPage(
                      task: Task('Draft title'),
                      isNewTask: true,
                      onChanged: () {},
                      onSave: () async => saveCount++,
                    ),
                  ),
                );
                detailClosed = true;
              },
              child: const Text('Open task'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open task'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('task-title-input')),
      'Saved on blur',
    );
    await tester.tap(find.text('Task'));
    await tester.pumpAndSettle();

    expect(saveCount, 1);
    expect(detailClosed, isFalse);
    expect(find.text('Saved on blur'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(saveCount, 2);
    expect(detailClosed, isTrue);
    expect(savedResult, isTrue);
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

  testWidgets('task detail priority is marked and can be cleared', (
    tester,
  ) async {
    final task = Task('Priority task', priority: 'U1');

    await tester.pumpWidget(
      MaterialApp(
        home: TaskDetailPage(task: task, onChanged: () {}, onSave: () async {}),
      ),
    );

    await tester.ensureVisible(find.text('Priority'));
    await tester.tap(find.text('Priority'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check), findsOneWidget);
    final selectedOptionText = find.descendant(
      of: find.byType(ListView).last,
      matching: find.text('U1'),
    );
    final selectedOption = find.ancestor(
      of: selectedOptionText,
      matching: find.byType(InkWell),
    );
    tester.widget<InkWell>(selectedOption.last).onTap!();
    await tester.pumpAndSettle();

    expect(task.priority, isNull);
  });

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
