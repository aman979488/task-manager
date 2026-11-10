import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/map_screen/models/task.dart';
import 'package:task_manager/features/map_screen/screens/dialogs/task_notification_setup_dialog.dart';

void main() {
  testWidgets('timing can be selected before a reminder is set', (
    tester,
  ) async {
    TaskNotification? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await showTaskNotificationSetupDialog(
                  context,
                  reminderAt: null,
                  templateLabel: 'Work update',
                  message: 'Work update: I am working on it.',
                  pickCustomTime: () async => null,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5 minutes before'));
    await tester.pumpAndSettle();

    expect(selected, isNotNull);
    expect(selected!.timing, '5 minutes before');
    expect(selected!.scheduledAt, isEmpty);
    expect(selected!.templateLabel, 'Work update');
  });

  testWidgets('timing can be selected when the reminder time is in the past', (
    tester,
  ) async {
    TaskNotification? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await showTaskNotificationSetupDialog(
                  context,
                  reminderAt: DateTime(2026, 11, 1, 10),
                  templateLabel: 'Work update',
                  message: 'Work update: I am working on it.',
                  pickCustomTime: () async => null,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5 minutes before'));
    await tester.pumpAndSettle();

    expect(selected, isNotNull);
    expect(selected!.timing, '5 minutes before');
    expect(selected!.scheduledAt, isNotEmpty);
  });

  testWidgets('timing options remain scrollable on a short screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                await showTaskNotificationSetupDialog(
                  context,
                  reminderAt: null,
                  templateLabel: 'Work update',
                  message: 'Work update: I am working on it.',
                  pickCustomTime: () async => null,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('Now'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
