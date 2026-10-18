import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/map_screen/models/floating_sheet_type.dart';
import 'package:task_manager/features/map_screen/screens/views/floating_metadata_sheet.dart';
import 'package:task_manager/features/map_screen/utils/task_mention_parser.dart';

void main() {
  group('FloatingMetadataSheet', () {
    test('matches metadata options without case sensitivity', () {
      expect(
        TaskMentionParser.matchesSearchQuery('Aman Yadav', 'aman'),
        isTrue,
      );
      expect(
        TaskMentionParser.matchesSearchQuery('Aman Yadav', 'xyz'),
        isFalse,
      );
    });

    testWidgets(
      'filters assignee options from the search field',
      (tester) async {
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
                        'Aman Yadav',
                        'Other person',
                      ],
                      onSelected: (_) {},
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

        expect(find.text('Search...'), findsOneWidget);
        expect(find.text('Aman Yadav'), findsOneWidget);
        expect(find.text('Other person'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'aman');
        await tester.pumpAndSettle();

        expect(find.text('Aman Yadav'), findsOneWidget);
        expect(find.text('Other person'), findsNothing);

        FloatingMetadataSheet.hide();
        await tester.pumpAndSettle();
      },
    );
  });
}
