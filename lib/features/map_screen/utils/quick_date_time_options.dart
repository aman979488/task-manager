class QuickDateTimeOption {
  const QuickDateTimeOption._({
    required this.label,
    required this.dayOffset,
    required this.hour,
  });

  final String label;
  final int dayOffset;
  final int hour;

  DateTime resolve(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final date = today.add(Duration(days: dayOffset));
    return DateTime(date.year, date.month, date.day, hour);
  }
}

class QuickDateTimeOptions {
  QuickDateTimeOptions._();

  static const _weekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static List<QuickDateTimeOption> options({DateTime? now}) {
    final today = now ?? DateTime.now();
    final options = <QuickDateTimeOption>[
      const QuickDateTimeOption._(
        label: 'Today (1 PM)',
        dayOffset: 0,
        hour: 13,
      ),
      const QuickDateTimeOption._(
        label: 'Today (3 PM)',
        dayOffset: 0,
        hour: 15,
      ),
      const QuickDateTimeOption._(
        label: 'Today (6 PM)',
        dayOffset: 0,
        hour: 18,
      ),
      const QuickDateTimeOption._(
        label: 'Tomorrow (9 AM)',
        dayOffset: 1,
        hour: 9,
      ),
      const QuickDateTimeOption._(
        label: 'Tomorrow (12 PM)',
        dayOffset: 1,
        hour: 12,
      ),
      const QuickDateTimeOption._(
        label: 'Tomorrow (3 PM)',
        dayOffset: 1,
        hour: 15,
      ),
      const QuickDateTimeOption._(
        label: 'Tomorrow (6 PM)',
        dayOffset: 1,
        hour: 18,
      ),
    ];

    for (var dayOffset = 2; dayOffset < 7; dayOffset++) {
      final date = DateTime(
        today.year,
        today.month,
        today.day,
      ).add(Duration(days: dayOffset));
      final weekday = _weekdays[date.weekday - 1];
      final month = _months[date.month - 1];
      options.add(
        QuickDateTimeOption._(
          label: '$weekday, $month ${date.day} (12 PM)',
          dayOffset: dayOffset,
          hour: 12,
        ),
      );
    }

    return options;
  }

  static List<String> labels({DateTime? now}) => [
    ...options(now: now).map((option) => option.label),
    'Custom',
  ];

  static DateTime? resolve(String label, {DateTime? now}) {
    final referenceTime = now ?? DateTime.now();
    final option = options(now: referenceTime).where(
      (option) => option.label.toLowerCase() == label.trim().toLowerCase(),
    );
    if (option.isEmpty) return null;
    return option.first.resolve(referenceTime);
  }
}
