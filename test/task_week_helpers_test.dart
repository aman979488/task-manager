import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/map_screen/models/task.dart';
import 'package:task_manager/features/map_screen/utils/task_week_helpers.dart';

void main() {
  group('task week helpers', () {
    test('assigns days to weeks without crossing month boundaries', () {
      expect(weekKeyFor(DateTime(2026, 10, 7)), '2026-10-W1');
      expect(weekKeyFor(DateTime(2026, 10, 8)), '2026-10-W2');
      expect(weekKeyFor(DateTime(2026, 10, 28)), '2026-10-W4');
      expect(weekKeyFor(DateTime(2026, 10, 29)), '2026-10-W5');
    });

    test('includes week five only when the month has more than 28 days', () {
      expect(weeksOfMonth(2026, 2), hasLength(4));
      expect(weeksOfMonth(2026, 10), hasLength(5));

      final finalWeek = dateRangeForWeek('2026-10-W5');
      expect(finalWeek?.start, DateTime(2026, 10, 29));
      expect(finalWeek?.end, DateTime(2026, 10, 31));
      expect(dateRangeForWeek('2026-02-W5'), isNull);
    });
  });

  test('goal fields default safely and round-trip through task maps', () {
    final oldTask = Task.fromMap('old-task', {'title': 'Legacy task'});
    expect(oldTask.weekKey, isNull);
    expect(oldTask.isMonthlyGoal, isFalse);

    final task = Task('Goal task', weekKey: '2026-10-W2', isMonthlyGoal: true);
    final restored = Task.fromMap('goal-task', task.toMap());
    expect(restored.weekKey, task.weekKey);
    expect(restored.isMonthlyGoal, isTrue);
  });
}
