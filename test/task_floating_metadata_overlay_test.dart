import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/tasks/models/task_metadata_type.dart';
import 'package:task_manager/features/tasks/widgets/task_floating_metadata_overlay.dart';

void main() {
  group('TaskFloatingMetadataOverlay', () {
    test('filters metadata options without case sensitivity', () {
      expect(
        TaskFloatingMetadataOverlay.matchesQuery('Aman Yadav', 'aman'),
        isTrue,
      );
      expect(
        TaskFloatingMetadataOverlay.matchesQuery('Aman Yadav', 'xyz'),
        isFalse,
      );
    });

    test('highlights matching characters in filtered options', () {
      final highlighted = TaskFloatingMetadataOverlay.highlightedOption(
        'Aman Yadav',
        'ay',
      );

      expect(highlighted.children, isNotEmpty);
      expect(
        highlighted.children!.where(
          (span) => span.style?.backgroundColor == const Color(0xFFFFF2A6),
        ),
        hasLength(2),
      );
    });

    testWidgets(
      'mention suggestions filter and highlight without a search box',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () {
                    TaskFloatingMetadataOverlay.show(
                      context: context,
                      buttonContext: context,
                      type: TaskMetadataType.assign,
                      options: const ['Aman Yadav', 'Other person'],
                      initialSearchQuery: 'aman',
                      showSearchField: false,
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

        expect(find.text('Search...'), findsNothing);
        expect(find.text('Aman Yadav'), findsOneWidget);
        expect(find.text('Other person'), findsNothing);

        TaskFloatingMetadataOverlay.hide();
        await tester.pumpAndSettle();
      },
    );
  });
}
