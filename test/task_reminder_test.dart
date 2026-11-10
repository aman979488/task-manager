import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/map_screen/models/task.dart';

void main() {
  test('task reminder is due when reminder time has passed and reminder was not sent', () {
    final task = Task(
      'Follow up client',
      reminder: DateTime.now()
          .subtract(const Duration(minutes: 1))
          .toIso8601String(),
      reminderSent: false,
    );

    expect(task.isReminderDueAt(DateTime.now()), isTrue);
  });

  test('task reminder is not due when it was already sent', () {
    final task = Task(
      'Follow up client',
      reminder: DateTime.now()
          .subtract(const Duration(minutes: 1))
          .toIso8601String(),
      reminderSent: true,
    );

    expect(task.isReminderDueAt(DateTime.now()), isFalse);
  });

  test('Task.fromMap loads reminderSent status', () {
    final task = Task.fromMap('abc123', {
      'title': 'Follow up client',
      'reminder': DateTime.now().toIso8601String(),
      'reminderSent': true,
    });

    expect(task.reminderSent, isTrue);
  });

  test('task notification settings survive serialization', () {
    final notification = TaskNotification(
      templateLabel: 'Work update',
      message: 'Work update: I am working on it.',
      timing: '1 hour before',
      scheduledAt: DateTime(2026, 11, 4, 12).toIso8601String(),
      isEnabled: false,
    );
    final restored = Task.fromMap(
      'task-with-notification',
      Task('Notification task', taskNotifications: [notification]).toMap(),
    );

    expect(restored.taskNotifications, hasLength(1));
    expect(restored.taskNotifications.single.templateLabel, 'Work update');
    expect(restored.taskNotifications.single.message, notification.message);
    expect(restored.taskNotifications.single.timing, '1 hour before');
    expect(
      restored.taskNotifications.single.scheduledAt,
      notification.scheduledAt,
    );
    expect(restored.taskNotifications.single.isEnabled, isFalse);
  });

  test('Task.fromMap replaces a malformed title with an empty string', () {
    final task = Task.fromMap('bad-title', {'title': 42});

    expect(task.title, isEmpty);
  });

  test('deadline notification is due within three hours of the deadline', () {
    final task = Task(
      'Follow up client',
      deadline: DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
    );

    expect(task.isDeadlineNotificationDue(DateTime.now()), isTrue);
  });

  test('deadline notification is not due outside the three-hour window', () {
    final task = Task(
      'Follow up client',
      deadline: DateTime.now().add(const Duration(hours: 4)).toIso8601String(),
    );

    expect(task.isDeadlineNotificationDue(DateTime.now()), isFalse);
  });

  test('deadline notification is not due after it was already sent', () {
    final task = Task(
      'Follow up client',
      deadline: DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
      deadlineReminderSent: true,
    );

    expect(task.isDeadlineNotificationDue(DateTime.now()), isFalse);
  });
}
