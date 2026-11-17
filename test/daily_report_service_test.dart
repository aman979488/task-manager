import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/call_history/models/call_log_model.dart';
import 'package:task_manager/features/map_screen/models/task.dart';
import 'package:task_manager/features/reports/services/daily_report_service.dart';

void main() {
  final now = DateTime(2026, 11, 16, 14, 0); // Monday

  test('DailyReportService groups by date and includes today at index 0', () {
    final todayTask = Task(
      'Client Meeting',
      workType: 'Meet',
      startTime: '10:00 AM',
      endTime: '11:30 AM',
      deadline: DateTime(2026, 11, 16, 12, 0).toIso8601String(),
    );

    final yesterdayTask = Task(
      'Site Visit',
      workType: 'Visit',
      startTime: '02:00 PM',
      endTime: '03:15 PM',
      deadline: DateTime(2026, 11, 15, 16, 0).toIso8601String(),
    );

    final reports = DailyReportService.generateReports(
      tasks: [todayTask, yesterdayTask],
      currentDate: now,
    );

    expect(reports.length, greaterThanOrEqualTo(2));
    expect(reports.first.isToday, isTrue);
    expect(reports.first.date.day, 16);
    expect(reports[1].date.day, 15);
  });

  test(
    'calculates calls, visits, and work type counts and duration accurately',
    () {
      final tasks = [
        Task(
          'Call Client A',
          workType: 'Call',
          startTime: '09:00 AM',
          endTime: '09:45 AM',
          deadline: DateTime(2026, 11, 16).toIso8601String(),
        ),
        Task(
          'Call Client B',
          workType: 'Call',
          startTime: '10:00 AM',
          endTime: '10:30 AM',
          deadline: DateTime(2026, 11, 16).toIso8601String(),
        ),
        Task(
          'Visit Property Site',
          workType: 'Visit',
          startTime: '11:00 AM',
          endTime: '01:00 PM',
          deadline: DateTime(2026, 11, 16).toIso8601String(),
        ),
      ];

      final reports = DailyReportService.generateReports(
        tasks: tasks,
        currentDate: now,
      );

      final todayReport = reports.first;
      expect(todayReport.totalCalls, 2);
      expect(todayReport.totalVisits, 1);
      expect(todayReport.totalTasks, 3);
      // 45 mins + 30 mins + 120 mins = 195 mins (3h 15m)
      expect(todayReport.totalDurationMinutes, 195);
      expect(todayReport.formattedDuration, '3h 15m');

      final callWorkType = todayReport.workTypes.firstWhere(
        (w) => w.title == 'Call',
      );
      expect(callWorkType.count, 2);
      expect(callWorkType.durationMinutes, 75);
      expect(callWorkType.formattedDuration, '1h 15m');

      final visitWorkType = todayReport.workTypes.firstWhere(
        (w) => w.title == 'Visit',
      );
      expect(visitWorkType.count, 1);
      expect(visitWorkType.durationMinutes, 120);
      expect(visitWorkType.formattedDuration, '2h');
    },
  );

  test('includes device call logs in daily calls count', () {
    final callLogs = [
      CallLogModel(
        number: '9876543210',
        name: 'Client X',
        kind: CallKind.outgoing,
        durationSeconds: 120,
        time: DateTime(2026, 11, 16, 10, 0),
      ),
      CallLogModel(
        number: '9876543211',
        name: 'Client Y',
        kind: CallKind.incoming,
        durationSeconds: 300,
        time: DateTime(2026, 11, 16, 11, 0),
      ),
    ];

    final reports = DailyReportService.generateReports(
      tasks: [],
      callLogs: callLogs,
      currentDate: now,
    );

    expect(reports.first.totalCalls, 2);
  });
}
