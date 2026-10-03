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
}
