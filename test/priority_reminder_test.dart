import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/map_screen/models/floating_sheet_type.dart';
import 'package:task_manager/features/map_screen/utils/priority_reminder.dart';
import 'package:task_manager/features/map_screen/viewmodels/add_task_viewmodel.dart';

void main() {
  final now = DateTime(2026, 10, 29, 16, 5);

  test('date-based priorities map to 9 AM reminders', () {
    expect(reminderForPriority('Today', now: now), DateTime(2026, 10, 29, 9));
    expect(
      reminderForPriority('Tomorrow', now: now),
      DateTime(2026, 10, 30, 9),
    );
    expect(
      reminderForPriority('Day Later', now: now),
      DateTime(2026, 10, 31, 9),
    );
    expect(reminderForPriority('Later', now: now), DateTime(2026, 11, 1, 9));
    expect(reminderForPriority('IMP', now: now), isNull);
  });

  test('selecting a date-based add-task priority sets its reminder', () {
    final viewModel = AddTaskViewModel();

    viewModel.setValue(FloatingSheetType.priority, 'Tomorrow');

    final reminder = DateTime.parse(viewModel.reminder!);
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    expect(reminder.year, tomorrow.year);
    expect(reminder.month, tomorrow.month);
    expect(reminder.day, tomorrow.day);
    expect(reminder.hour, 9);
    expect(reminder.minute, 0);
    viewModel.dispose();
  });
}
