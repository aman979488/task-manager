import '../../call_history/models/call_log_model.dart';
import '../../map_screen/models/task.dart';
import '../models/daily_report_model.dart';

class DailyReportService {
  const DailyReportService._();

  static List<DayReport> generateReports({
    required List<Task> tasks,
    List<CallLogModel> callLogs = const [],
    DateTime? currentDate,
  }) {
    final now = currentDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final tasksByDate = <DateTime, List<Task>>{};
    for (final task in tasks) {
      final date = getTaskDate(task);
      if (date == null) continue;
      final normalizedDate = DateTime(date.year, date.month, date.day);
      if (normalizedDate.isAfter(today)) continue;
      tasksByDate.putIfAbsent(normalizedDate, () => []).add(task);
    }

    final callsByDate = <DateTime, List<CallLogModel>>{};
    for (final call in callLogs) {
      final callDate = DateTime(call.time.year, call.time.month, call.time.day);
      if (callDate.isAfter(today)) continue;
      callsByDate.putIfAbsent(callDate, () => []).add(call);
    }

    // Collect all dates up to today, ensuring Today is always included
    final allDates = <DateTime>{
      today,
      ...tasksByDate.keys,
      ...callsByDate.keys,
    }.toList()..sort((a, b) => b.compareTo(a));

    final reports = <DayReport>[];
    for (final date in allDates) {
      final dayTasks = tasksByDate[date] ?? const <Task>[];
      final dayCalls = callsByDate[date] ?? const <CallLogModel>[];

      // Work type grouping
      final tasksByWorkType = <String, List<Task>>{};
      var dayTotalMinutes = 0;
      var visitCount = 0;
      var callTaskCount = 0;

      for (final task in dayTasks) {
        final rawWorkType = task.workType?.trim();
        final type = rawWorkType != null && rawWorkType.isNotEmpty
            ? rawWorkType
            : 'General';

        tasksByWorkType.putIfAbsent(type, () => []).add(task);

        final taskMinutes = calculateTaskDurationMinutes(task);
        dayTotalMinutes += taskMinutes;

        final isVisit =
            type.toLowerCase() == 'visit' ||
            type.toLowerCase() == 'meet' ||
            task.title.toLowerCase().contains('visit') ||
            task.note.toLowerCase().contains('visit');
        if (isVisit) visitCount++;

        if (type.toLowerCase() == 'call') callTaskCount++;
      }

      final workTypeSummaries =
          tasksByWorkType.entries.map((entry) {
            final typeTitle = entry.key;
            final list = entry.value;
            final typeMinutes = list.fold<int>(
              0,
              (sum, t) => sum + calculateTaskDurationMinutes(t),
            );
            return WorkTypeSummary(
              title: typeTitle,
              count: list.length,
              durationMinutes: typeMinutes,
              tasks: list,
            );
          }).toList()..sort((a, b) {
            final countCompare = b.count.compareTo(a.count);
            if (countCompare != 0) return countCompare;
            return b.durationMinutes.compareTo(a.durationMinutes);
          });

      final totalCalls = dayCalls.isNotEmpty ? dayCalls.length : callTaskCount;

      reports.add(
        DayReport(
          date: date,
          dateKey:
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
          displayDate: formatDateLabel(date, today),
          isToday: date == today,
          totalCalls: totalCalls,
          totalVisits: visitCount,
          totalTasks: dayTasks.length,
          totalDurationMinutes: dayTotalMinutes,
          workTypes: workTypeSummaries,
          callLogs: dayCalls,
        ),
      );
    }

    return reports;
  }

  static DateTime? getTaskDate(Task task) {
    if (task.completedAt != null) {
      final dt = DateTime.fromMillisecondsSinceEpoch(task.completedAt!);
      return DateTime(dt.year, dt.month, dt.day);
    }
    if (task.deadline != null && task.deadline!.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(task.deadline!);
      if (parsed != null) {
        return DateTime(parsed.year, parsed.month, parsed.day);
      }
    }
    if (task.reminder != null && task.reminder!.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(task.reminder!);
      if (parsed != null) {
        return DateTime(parsed.year, parsed.month, parsed.day);
      }
    }
    if (task.createdDate.trim().isNotEmpty) {
      final dateText = task.createdDate.split(' • ').first.trim();
      final parts = dateText.split('/');
      if (parts.length == 3) {
        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);
        if (day != null && month != null && year != null) {
          return DateTime(year, month, day);
        }
      }
    }
    return null;
  }

  static int calculateTaskDurationMinutes(Task task) {
    final startMinutes = _parseMinutes(task.startTime);
    final endMinutes = _parseMinutes(task.endTime);

    if (startMinutes != null && endMinutes != null) {
      if (endMinutes >= startMinutes) {
        return endMinutes - startMinutes;
      } else {
        return (endMinutes + 24 * 60) - startMinutes;
      }
    }

    if (task.isDone &&
        task.completedAt != null &&
        task.createdDate.isNotEmpty) {
      final created = _createdDateTime(task);
      final completed = DateTime.fromMillisecondsSinceEpoch(task.completedAt!);
      if (created != null && completed.isAfter(created)) {
        final diff = completed.difference(created).inMinutes;
        if (diff > 0 && diff <= 24 * 60) {
          return diff;
        }
      }
    }

    return 0;
  }

  static DateTime? _createdDateTime(Task task) {
    final parts = task.createdDate.split(' • ');
    final dateParts = parts[0].trim().split('/');
    if (dateParts.length != 3) return null;
    final day = int.tryParse(dateParts[0]);
    final month = int.tryParse(dateParts[1]);
    final year = int.tryParse(dateParts[2]);
    if (day == null || month == null || year == null) return null;

    var hour = 0;
    var minute = 0;
    if (parts.length > 1) {
      final timeParts = parts[1].trim().split(':');
      hour = int.tryParse(timeParts.first) ?? 0;
      if (timeParts.length > 1) {
        final minPart = timeParts[1].replaceAll(RegExp(r'[^0-9]'), '');
        minute = int.tryParse(minPart) ?? 0;
        final isPm = parts[1].toUpperCase().contains('PM');
        if (isPm && hour < 12) hour += 12;
        if (!isPm && hour == 12) hour = 0;
      }
    }
    return DateTime(year, month, day, hour, minute);
  }

  static int? _parseMinutes(String? value) {
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

  static String formatDateLabel(DateTime date, DateTime today) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
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

    final dayDiff = today.difference(date).inDays;
    final weekdayName = weekdays[date.weekday - 1];
    final monthName = months[date.month - 1];
    final dateStr = '${date.day} $monthName ${date.year}';

    if (dayDiff == 0) return 'Today • $dateStr ($weekdayName)';
    if (dayDiff == 1) return 'Yesterday • $dateStr ($weekdayName)';
    return '$dateStr ($weekdayName)';
  }
}
