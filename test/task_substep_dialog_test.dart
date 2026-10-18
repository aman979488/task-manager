import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/map_screen/screens/dialogs/task_substep_dialog.dart';

void main() {
  testWidgets('unfocuses and returns the trimmed substep title', (
    tester,
  ) async {
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await promptAddSubstepDialog(context);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Call the client  ');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(result, 'Call the client');
    expect(find.text('Add substep'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
