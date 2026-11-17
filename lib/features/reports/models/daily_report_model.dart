import '../../call_history/models/call_log_model.dart';
import '../../map_screen/models/task.dart';

class WorkTypeSummary {
  final String title;
  final int count;
  final int durationMinutes;
  final List<Task> tasks;

  const WorkTypeSummary({
    required this.title,
    required this.count,
    required this.durationMinutes,
    this.tasks = const [],
  });

  String get formattedDuration {
    if (durationMinutes <= 0) return '0m';
    final hours = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;
    if (hours == 0) return '${mins}m';
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }
}

class DayReport {
  final DateTime date;
  final String dateKey;
  final String displayDate;
  final bool isToday;
  final int totalCalls;
  final int totalVisits;
  final int totalTasks;
  final int totalDurationMinutes;
  final List<WorkTypeSummary> workTypes;
  final List<CallLogModel> callLogs;

  const DayReport({
    required this.date,
    required this.dateKey,
    required this.displayDate,
    required this.isToday,
    required this.totalCalls,
    required this.totalVisits,
    required this.totalTasks,
    required this.totalDurationMinutes,
    required this.workTypes,
    this.callLogs = const [],
  });

  String get formattedDuration {
    if (totalDurationMinutes <= 0) return '0m';
    final hours = totalDurationMinutes ~/ 60;
    final mins = totalDurationMinutes % 60;
    if (hours == 0) return '${mins}m';
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }
}
