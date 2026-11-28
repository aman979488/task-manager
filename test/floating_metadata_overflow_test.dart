import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_manager/features/map_screen/models/floating_sheet_type.dart';
import 'package:task_manager/features/map_screen/screens/views/floating_metadata_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'multi-select dropdown scrolls when the available height is constrained',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 128);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () {
                    FloatingMetadataSheet.show(
                      context: context,
                      buttonContext: context,
                      type: FloatingSheetType.assign,
                      loadAssignees: () async => const ['Aman', 'Nina'],
                      multiSelect: true,
                    );
                  },
                  child: const Text('Open constrained dropdown'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open constrained dropdown'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Done'), findsOneWidget);
      FloatingMetadataSheet.hide();
      await tester.pumpAndSettle();
    },
  );
}
