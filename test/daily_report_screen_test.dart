import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:task_manager/features/call_history/viewmodels/call_log_controller.dart';
import 'package:task_manager/features/map_screen/models/task.dart';
import 'package:task_manager/features/reports/screens/daily_report_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('opens with only the first date expanded and toggles sections', (
    tester,
  ) async {
    const channel = MethodChannel('task_manager/call_history');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => []);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final tasks = [
      Task(
        'Call client',
        isDone: true,
        workType: 'Call',
        startTime: '10:00 AM',
        endTime: '10:30 AM',
        completedAt: DateTime(
          today.year,
          today.month,
          today.day,
          10,
        ).millisecondsSinceEpoch,
      ),
      Task(
        'Visit client',
        isDone: true,
        workType: 'Visit',
        startTime: '11:00 AM',
        endTime: '12:00 PM',
        completedAt: DateTime(
          yesterday.year,
          yesterday.month,
          yesterday.day,
          11,
        ).millisecondsSinceEpoch,
      ),
    ];

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CallLogController(),
        child: MaterialApp(home: DailyReportScreen(tasks: tasks)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Call'), findsOneWidget);
    expect(find.text('Visit'), findsNothing);

    await tester.tap(find.textContaining('Yesterday'));
    await tester.pumpAndSettle();
    expect(find.text('Visit'), findsOneWidget);

    await tester.tap(find.textContaining('Today'));
    await tester.pumpAndSettle();
    expect(find.text('Call'), findsNothing);
  });
}
