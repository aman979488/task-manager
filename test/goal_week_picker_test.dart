import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_manager/features/map_screen/models/floating_sheet_type.dart';
import 'package:task_manager/features/map_screen/screens/views/date_time_picker_dialog.dart';
import 'package:task_manager/features/map_screen/screens/views/floating_metadata_sheet.dart';
import 'package:task_manager/features/map_screen/utils/task_week_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FloatingMetadataSheet.hide();
  });

  testWidgets('goal picker accepts a date from a future month', (tester) async {
    String? selectedWeekKey;
    final now = DateTime.now();
    final targetDate = DateTime(now.year, now.month + 2, 10);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                FloatingMetadataSheet.show(
                  context: context,
                  buttonContext: context,
                  type: FloatingSheetType.goal,
                  goalWeekKeys: weeksOfMonth(
                    now.year,
                    now.month,
                  ).map((week) => week.key).toList(),
                  selectedValues: [weekKeyFor(now)],
                  onSelected: (value) => selectedWeekKey = value,
                );
              },
              child: const Text('Open goal'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open goal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(goalWeekPickerOptionLabel));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('${targetDate.day}').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(selectedWeekKey, weekKeyFor(targetDate));
    expect(FloatingMetadataSheet.isShowing, isFalse);
    expect(tester.takeException(), isNull);
  });

  tearDown(FloatingMetadataSheet.hide);
}
