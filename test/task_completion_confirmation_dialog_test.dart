import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/map_screen/screens/views/task_completion_confirmation_dialog.dart';

void main() {
  testWidgets('task completion requires explicit confirmation', (tester) async {
    bool? confirmed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                confirmed = await showTaskCompletionConfirmation(
                  context,
                  'Prepare report',
                );
              },
              child: const Text('Open confirmation'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open confirmation'));
    await tester.pumpAndSettle();
    expect(find.text('Mark task as done?'), findsOneWidget);
    expect(find.text('Mark "Prepare report" as completed?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(confirmed, isFalse);

    await tester.tap(find.text('Open confirmation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);
  });
}
