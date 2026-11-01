import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_manager/features/map_screen/utils/frequent_option_usage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('keeps selected options first, then orders by usage', () async {
    await FrequentOptionUsage.recordSelection('assignee', 'A');
    await FrequentOptionUsage.recordSelection('assignee', 'B');
    await FrequentOptionUsage.recordSelection('assignee', 'B');

    final ordered = await FrequentOptionUsage.orderOptions(
      'assignee',
      ['A', 'B', 'C'],
      selectedValues: ['A'],
    );

    expect(ordered, ['A', 'B', 'C']);
  });

  test('usage counts are isolated between lists', () async {
    await FrequentOptionUsage.recordSelection('priority', 'Today');

    final ordered = await FrequentOptionUsage.orderOptions('workType', [
      'Today',
      'Meeting',
    ]);

    expect(ordered, ['Today', 'Meeting']);
  });
}
