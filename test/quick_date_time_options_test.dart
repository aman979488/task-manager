import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/map_screen/models/quick_date_time_option.dart';

void main() {
  final now = DateTime(2026, 10, 14, 10);

  test('quick options use fixed times for today and tomorrow', () {
    expect(
      QuickDateTimeOptions.resolve('Today (1 PM)', now: now),
      DateTime(2026, 10, 14, 13),
    );
    expect(
      QuickDateTimeOptions.resolve('Tomorrow (9 AM)', now: now),
      DateTime(2026, 10, 15, 9),
    );
    expect(
      QuickDateTimeOptions.resolve('Tomorrow (6 PM)', now: now),
      DateTime(2026, 10, 15, 18),
    );
  });

  test('quick options include remaining dates through seven days', () {
    final options = QuickDateTimeOptions.options(now: now);

    expect(options, hasLength(12));
    expect(options[7].label, 'Fri, Oct 16 (12 PM)');
    expect(options.last.resolve(now), DateTime(2026, 10, 20, 12));
    expect(QuickDateTimeOptions.resolve('Custom', now: now), isNull);
  });
}
