import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/map_screen/models/floating_sheet_type.dart';
import 'package:task_manager/features/map_screen/screens/views/floating_metadata_sheet.dart';

void main() {
  testWidgets('updates mention suggestions as the query changes', (
    tester,
  ) async {
    var query = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                FloatingMetadataSheet.show(
                  context: context,
                  buttonContext: context,
                  type: FloatingSheetType.assign,
                  loadAssignees: () async => const [
                    'Aman',
                    'Arav Sharma',
                    'Aditya Verma',
                  ],
                  searchQuery: () => query,
                  multiSelect: true,
                );
              },
              child: const Text('Open suggestions'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open suggestions'));
    await tester.pumpAndSettle();

    expect(find.text('Aman'), findsOneWidget);
    expect(find.text('Arav Sharma'), findsOneWidget);
    expect(find.text('Aditya Verma'), findsOneWidget);

    query = 'aman';
    FloatingMetadataSheet.update();
    await tester.pumpAndSettle();

    expect(find.text('Aman'), findsOneWidget);
    expect(find.text('Arav Sharma'), findsNothing);
    expect(find.text('Aditya Verma'), findsNothing);

    FloatingMetadataSheet.hide();
    await tester.pumpAndSettle();
  });
}
