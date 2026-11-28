import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/flash/flash_alert_service.dart';
import 'package:task_manager/features/map_screen/models/task.dart';
import 'package:task_manager/features/map_screen/screens/views/task_notifications_section.dart';

Widget _buildWrapper({
  required Task task,
  required bool isExpanded,
  required VoidCallback onChanged,
  Future<bool> Function(TaskNotification notification)? onNotificationScheduled,
  Future<List<FlashTemplate>> Function()? loadTemplates,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: TaskNotificationsSection(
          task: task,
          isExpanded: isExpanded,
          onChanged: onChanged,
          onNotificationScheduled: onNotificationScheduled ?? (_) async => true,
          loadTemplates: loadTemplates,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'TaskNotificationsSection stays hidden when isExpanded is false',
    (tester) async {
      final task = Task(
        'Test Notification Task',
        id: 'task-1',
        taskNotifications: [
          const TaskNotification(
            templateLabel: 'Flash call',
            message: 'Please call me when you are free.',
            timing: 'At time of reminder',
            scheduledAt: '2026-11-09T10:00:00.000Z',
            isEnabled: true,
          ),
        ],
      );

      await tester.pumpWidget(
        _buildWrapper(task: task, isExpanded: false, onChanged: () {}),
      );

      expect(find.text('Add notification'), findsNothing);
      expect(find.text('Template'), findsNothing);
      expect(find.text('Please call me when you are free.'), findsNothing);
    },
  );

  testWidgets(
    'TaskNotificationsSection renders items and allows toggling switch and deleting',
    (tester) async {
      var changedCount = 0;
      final task = Task(
        'Test Notification Task 2',
        id: 'task-2',
        taskNotifications: [
          const TaskNotification(
            templateLabel: 'Work update',
            message: 'Work update: I am working on it.',
            timing: '5 minutes before',
            scheduledAt: '2026-11-09T10:00:00.000Z',
            isEnabled: true,
          ),
        ],
      );

      await tester.pumpWidget(
        _buildWrapper(
          task: task,
          isExpanded: true,
          onChanged: () => changedCount++,
        ),
      );

      expect(find.text('Add notification'), findsNothing);
      expect(find.text('Template'), findsOneWidget);
      expect(find.text('Work update: I am working on it.'), findsOneWidget);

      // Toggle switch
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      await tester.tap(switchFinder);
      await tester.pump();

      expect(task.taskNotifications.first.isEnabled, false);
      expect(changedCount, 1);

      // Remove notification
      final removeBtn = find.byTooltip('Remove notification');
      expect(removeBtn, findsOneWidget);
      await tester.tap(removeBtn);
      await tester.pump();

      expect(task.taskNotifications.isEmpty, true);
      expect(changedCount, 2);
    },
  );

  testWidgets('selecting a template reveals notification timing options', (
    tester,
  ) async {
    final reminderAt = DateTime(2026, 11, 28, 12);
    final task = Task(
      'Test Notification Task',
      reminder: reminderAt.toIso8601String(),
    );
    var changedCount = 0;
    TaskNotification? scheduledNotification;

    await tester.pumpWidget(
      _buildWrapper(
        task: task,
        isExpanded: true,
        onChanged: () => changedCount++,
        onNotificationScheduled: (notification) async {
          scheduledNotification = notification;
          return true;
        },
        loadTemplates: () async => const [
          FlashTemplate(
            label: 'Work update',
            text: 'Work update: I am working on it.',
          ),
        ],
      ),
    );

    expect(find.text('Add notification'), findsNothing);
    await tester.tap(find.text('Template'));
    await tester.pumpAndSettle();
    expect(find.text('Work update'), findsOneWidget);

    await tester.tap(find.text('Work update'));
    await tester.pumpAndSettle();
    expect(find.text('Add notification'), findsOneWidget);

    await tester.tap(find.text('Add notification'));
    await tester.pumpAndSettle();
    expect(find.text('10 minutes before'), findsOneWidget);

    await tester.tap(find.text('10 minutes before'));
    await tester.pumpAndSettle();

    expect(task.taskNotifications, hasLength(1));
    expect(task.taskNotifications.single.templateLabel, 'Work update');
    expect(
      task.taskNotifications.single.message,
      'Work update: I am working on it.',
    );
    expect(task.taskNotifications.single.timing, '10 minutes before');
    expect(
      task.taskNotifications.single.scheduledAt,
      DateTime(2026, 11, 28, 11, 50).toIso8601String(),
    );
    expect(scheduledNotification, task.taskNotifications.single);
    expect(changedCount, 1);
  });
}
