import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:task_manager/features/call_history/screens/all_calls_view.dart';
import 'package:task_manager/features/call_history/utils/date_label_utils.dart';
import 'package:task_manager/features/call_history/viewmodels/call_log_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows all calls and filters them by call type', (tester) async {
    const channel = MethodChannel('task_manager/call_history');
    final recentCalls = Completer<List<Map<String, Object?>>>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
          expect(call.method, 'getRecentCalls');
          return recentCalls.future;
        });

    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CallLogController(),
        child: const MaterialApp(home: AllCallsView()),
      ),
    );
    await tester.pump();

    expect(find.widgetWithText(AppBar, 'Call History'), findsOneWidget);
    expect(find.text('All Calls'), findsOneWidget);
    final tabBar = find.byType(TabBar);
    expect(
      find.descendant(of: tabBar, matching: find.byIcon(Icons.call)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tabBar, matching: find.byIcon(Icons.south_west)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tabBar, matching: find.byIcon(Icons.north_east)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tabBar, matching: find.byIcon(Icons.call_missed)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tabBar, matching: find.byIcon(Icons.south_east)),
      findsOneWidget,
    );
    expect(find.text('Never Attended Calls'), findsOneWidget);
    expect(find.text('Not Pickup by Client'), findsOneWidget);
    expect(find.text('Blocked'), findsNothing);
    expect(find.text('Search'), findsOneWidget);
    expect(find.byTooltip('Filter by date'), findsOneWidget);
    expect(find.byTooltip('Export to Excel'), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Contacts'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final firstCallTime = DateTime.now();
    recentCalls.complete([
      {
        'name': 'Aman',
        'number': '+919794887387',
        'type': 2,
        'duration': 33,
        'timestamp': firstCallTime.millisecondsSinceEpoch,
        '_id': '1',
      },
      {
        'name': 'Mummy',
        'number': '+919209985689',
        'type': 3,
        'duration': 0,
        'timestamp': DateTime.now().millisecondsSinceEpoch - 60000,
        '_id': '2',
      },
      {
        'name': 'Declined',
        'number': '+919000000001',
        'type': 5,
        'duration': 0,
        'timestamp': DateTime.now().millisecondsSinceEpoch - 120000,
        '_id': '3',
      },
      {
        'name': 'Client',
        'number': '+919000000002',
        'type': 2,
        'duration': 0,
        'timestamp': DateTime.now().millisecondsSinceEpoch - 180000,
        '_id': '4',
      },
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Incoming'), findsOneWidget);
    expect(find.text('Outgoing'), findsOneWidget);
    expect(find.text('Aman'), findsOneWidget);
    expect(find.text('Mummy'), findsOneWidget);

    await tester.tap(find.text('Analytics').last);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Analytics'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Graph View'), findsOneWidget);
    expect(find.text('Summary'), findsOneWidget);
    expect(find.text('Total Phone Calls'), findsOneWidget);
    expect(find.text('Incoming Calls'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('analytics-period-selector')));
    await tester.pumpAndSettle();
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Year'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);
    expect(find.text('All Time'), findsOneWidget);
    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();
    expect(find.text('Year'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('analytics-period-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    expect(find.text('Select Duration'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    final today = DateTime.now();
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
    final datePrefix =
        '${today.day.toString().padLeft(2, '0')}-${months[today.month - 1]}-${today.year}';
    await tester.ensureVisible(
      find.byKey(const ValueKey('analytics-date-range')),
    );
    await tester.tap(find.byKey(const ValueKey('analytics-date-range')));
    await tester.pumpAndSettle();
    expect(find.text('Select Duration'), findsOneWidget);
    expect(find.text('From Date & Time'), findsOneWidget);
    expect(find.text('To Date & Time'), findsOneWidget);
    expect(find.text('$datePrefix 12:00 AM'), findsOneWidget);
    expect(find.text('$datePrefix 11:59 PM'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('analytics-date-range')),
    );
    await tester.tap(find.byKey(const ValueKey('analytics-date-range')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Graph View'));
    await tester.tap(find.text('Graph View'));
    await tester.pumpAndSettle();
    expect(find.text('Duration'), findsOneWidget);
    expect(find.text('Phone Call'), findsOneWidget);
    expect(find.text('Rejected'), findsOneWidget);
    await tester.ensureVisible(find.text('Duration'));
    await tester.tap(find.text('Duration'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Phone Call'));
    await tester.tap(find.text('Phone Call'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Analysis'));
    await tester.tap(find.text('Analysis'));
    await tester.pumpAndSettle();
    expect(find.text('Never Attended Calls'), findsOneWidget);
    expect(find.text('Not Pickup by Client'), findsOneWidget);
    await tester.tap(find.text('Call History').last);
    await tester.pumpAndSettle();

    final callTimeFinder = find.text(DateLabelUtils.timeLabel(firstCallTime));
    final whatsappFinder = find.byTooltip('WhatsApp').first;
    expect(
      tester.getCenter(callTimeFinder).dy,
      lessThan(tester.getTopLeft(whatsappFinder).dy),
    );
    expect(
      (tester.getCenter(callTimeFinder).dx -
              tester.getCenter(whatsappFinder).dx)
          .abs(),
      lessThan(1),
    );

    await tester.tap(find.byTooltip('Filter by date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yesterday'));
    await tester.pumpAndSettle();
    expect(find.text('No calls found'), findsOneWidget);
    await tester.tap(find.byTooltip('Filter by date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All time'));
    await tester.pumpAndSettle();
    expect(find.text('Aman'), findsOneWidget);

    await tester.tap(find.text('Tap to add note & tag').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Follow up');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Follow up'), findsOneWidget);

    await tester.tap(find.text('Missed'));
    await tester.pumpAndSettle();

    expect(find.text('Mummy'), findsOneWidget);
    expect(find.text('Aman'), findsNothing);

    await tester.tap(find.text('Never Attended Calls'));
    await tester.pumpAndSettle();
    expect(find.text('Mummy'), findsOneWidget);
    expect(find.text('Declined'), findsOneWidget);
    expect(find.text('Client'), findsNothing);

    await tester.tap(find.text('Not Pickup by Client'));
    await tester.pumpAndSettle();
    expect(find.text('Client'), findsOneWidget);
    expect(find.text('Aman'), findsNothing);
    expect(find.text('Mummy'), findsNothing);
  });
}
