class TaskWeek {
  const TaskWeek({
    required this.year,
    required this.month,
    required this.weekNumber,
    required this.start,
    required this.end,
  });

  final int year;
  final int month;
  final int weekNumber;
  final DateTime start;
  final DateTime end;

  String get key =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-W$weekNumber';
}

String weekKeyFor(DateTime date) {
  final weekNumber = ((date.day - 1) ~/ 7) + 1;
  return TaskWeek(
    year: date.year,
    month: date.month,
    weekNumber: weekNumber,
    start: DateTime(date.year, date.month, ((weekNumber - 1) * 7) + 1),
    end: DateTime(
      date.year,
      date.month,
      (weekNumber * 7) < DateTime(date.year, date.month + 1, 0).day
          ? weekNumber * 7
          : DateTime(date.year, date.month + 1, 0).day,
    ),
  ).key;
}

List<TaskWeek> weeksOfMonth(int year, int month) {
  final lastDay = DateTime(year, month + 1, 0).day;
  final weekCount = ((lastDay - 1) ~/ 7) + 1;

  return List<TaskWeek>.generate(weekCount, (index) {
    final weekNumber = index + 1;
    final startDay = (index * 7) + 1;
    final endDay = (startDay + 6).clamp(1, lastDay);
    return TaskWeek(
      year: year,
      month: month,
      weekNumber: weekNumber,
      start: DateTime(year, month, startDay),
      end: DateTime(year, month, endDay),
    );
  });
}

TaskWeek? dateRangeForWeek(String weekKey) {
  final match = RegExp(r'^(\d{4})-(\d{2})-W([1-5])$').firstMatch(weekKey);
  if (match == null) return null;

  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final weekNumber = int.parse(match.group(3)!);
  if (month < 1 || month > 12) return null;

  for (final week in weeksOfMonth(year, month)) {
    if (week.weekNumber == weekNumber) return week;
  }
  return null;
}

String weekLabelForKey(String weekKey) {
  final week = dateRangeForWeek(weekKey);
  if (week == null) return weekKey;
  final monthName = const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][week.month - 1];
  return '$monthName Week ${week.weekNumber} '
      '(${week.start.month}/${week.start.day}-${week.end.month}/${week.end.day}, '
      '${week.year})';
}

String? weekKeyForCreatedDate(String createdDate) {
  final parts = createdDate.split(' • ').first.split('/');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  if (month < 1 ||
      month > 12 ||
      day < 1 ||
      day > DateTime(year, month + 1, 0).day) {
    return null;
  }
  return weekKeyFor(DateTime(year, month, day));
}
