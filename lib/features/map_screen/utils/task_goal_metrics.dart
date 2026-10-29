import '../models/task.dart';

double weeklyGoalScore(Iterable<Task> tasks) {
  var score = 0.0;
  for (final task in tasks) {
    if (!task.isDone) continue;
    final start = _minutes(task.startTime);
    final end = _minutes(task.endTime);
    if (start == null || end == null) continue;

    final minutes = end >= start ? end - start : end + 24 * 60 - start;
    final hours = double.parse((minutes / 60).toStringAsFixed(2));
    score += hours * 4;
  }
  return double.parse(score.toStringAsFixed(2));
}

int? _minutes(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final match = RegExp(
    r'^(\d{1,2}):(\d{2})(?:\s*(AM|PM))?$',
    caseSensitive: false,
  ).firstMatch(value.trim());
  if (match == null) return null;

  var hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  final meridiem = match.group(3)?.toUpperCase();
  if (minute > 59 || hour > 23) return null;
  if (meridiem != null) {
    if (hour < 1 || hour > 12) return null;
    hour %= 12;
    if (meridiem == 'PM') hour += 12;
  }
  return hour * 60 + minute;
}
