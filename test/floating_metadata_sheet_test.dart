import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/map_screen/models/floating_sheet_type.dart';
import 'package:task_manager/features/map_screen/screens/views/floating_metadata_sheet.dart';

void main() {
  testWidgets(
    'single-select dropdown restores, replaces and clears selection',
    (tester) async {
      String? selectedValue = 'U1';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  FloatingMetadataSheet.show(
                    context: context,
                    buttonContext: context,
                    type: FloatingSheetType.priority,
                    selectedValues: [if (selectedValue != null) selectedValue!],
                    onSelected: (value) => selectedValue = value,
                    onDeselected: (_) => selectedValue = null,
                  );
                },
                child: const Text('Open priority'),
              ),
            ),
          ),
        ),
      );

      Future<void> openDropdown() async {
        await tester.tap(find.text('Open priority'));
        await tester.pumpAndSettle();
      }

      Future<void> tapOption(String label) async {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      ListTile optionTile(String label) => tester.widget<ListTile>(
        find
            .ancestor(
              of: find.text(label).first,
              matching: find.byType(ListTile),
            )
            .first,
      );

      await openDropdown();
      expect(optionTile('U1').selected, isTrue);
      await tapOption('U1');
      expect(selectedValue, isNull);

      await openDropdown();
      expect(find.byIcon(Icons.check), findsNothing);
      await tapOption('U2');
      expect(selectedValue, 'U2');

      await openDropdown();
      expect(optionTile('U2').selected, isTrue);
      expect(
        tester.getCenter(find.text('U2').first).dy,
        lessThan(tester.getCenter(find.text('U1').first).dy),
      );
      await tapOption('U2');
      expect(selectedValue, isNull);
    },
  );

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

  testWidgets(
    'multi-select keeps order stable until Done and sorts on reopen',
    (tester) async {
      final selectedValues = <String>['B'];

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
                    loadAssignees: () async => const ['A', 'B', 'C'],
                    multiSelect: true,
                    closeOnSelect: false,
                    selectedValues: List<String>.from(selectedValues),
                    onSelected: selectedValues.add,
                    onDeselected: selectedValues.remove,
                  );
                },
                child: const Text('Open assignees'),
              ),
            ),
          ),
        ),
      );

      Future<void> openDropdown() async {
        await tester.tap(find.text('Open assignees'));
        await tester.pumpAndSettle();
      }

      await openDropdown();
      expect(
        tester.getCenter(find.text('B').first).dy,
        lessThan(tester.getCenter(find.text('A').first).dy),
      );
      expect(find.byIcon(Icons.check_box), findsOneWidget);
      expect(find.byIcon(Icons.check_box_outline_blank), findsNWidgets(2));

      await tester.tap(find.text('C').first);
      await tester.pumpAndSettle();
      expect(FloatingMetadataSheet.isShowing, isTrue);
      expect(
        tester.getCenter(find.text('B').first).dy,
        lessThan(tester.getCenter(find.text('A').first).dy),
      );
      expect(
        tester.getCenter(find.text('A').first).dy,
        lessThan(tester.getCenter(find.text('C').first).dy),
      );
      expect(find.byIcon(Icons.check_box), findsNWidgets(2));

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(FloatingMetadataSheet.isShowing, isFalse);

      await openDropdown();
      expect(
        tester.getCenter(find.text('B').first).dy,
        lessThan(tester.getCenter(find.text('C').first).dy),
      );
      expect(
        tester.getCenter(find.text('C').first).dy,
        lessThan(tester.getCenter(find.text('A').first).dy),
      );
      FloatingMetadataSheet.hide();
    },
  );

  testWidgets('shows and handles the flash message reminder option', (
    tester,
  ) async {
    var flashOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                FloatingMetadataSheet.show(
                  context: context,
                  buttonContext: context,
                  type: FloatingSheetType.remind,
                  onFlashMessage: () async => flashOpened = true,
                );
              },
              child: const Text('Open reminder options'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open reminder options'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'flash');
    await tester.pumpAndSettle();

    expect(find.text('⚡ Flash message'), findsOneWidget);
    await tester.tap(find.text('⚡ Flash message'));
    await tester.pumpAndSettle();

    expect(flashOpened, isTrue);
    FloatingMetadataSheet.hide();
  });
}
