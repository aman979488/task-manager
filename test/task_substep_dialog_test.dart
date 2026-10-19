import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/map_screen/screens/dialogs/task_substep_dialog.dart';

void main() {
  testWidgets('adds substeps repeatedly until the dialog is closed', (
    tester,
  ) async {
    final addedTitles = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                await promptAddSubstepDialog(
                  context,
                  onAdd: (title) async {
                    addedTitles.add(title);
                  },
                );
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
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();

    expect(addedTitles, ['Call the client']);
    expect(find.text('Add substep'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      isTrue,
    );

    await tester.enterText(find.byType(TextField), 'Send the details');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(addedTitles, ['Call the client', 'Send the details']);
    expect(find.text('Add substep'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Add substep'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
