import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/map_screen/screens/dialogs/task_options_dialog.dart';

void main() {
  testWidgets('task option dialog reports the selected option', (tester) async {
    String selected = 'Priority';
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => chooseTaskOptionDialog(
                context: context,
                title: 'Sort by',
                options: const ['Priority', 'Title'],
                selected: selected,
                onSelected: (value) => selected = value,
              ),
              child: const Text('Open options'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Title'));
    await tester.pumpAndSettle();

    expect(selected, 'Title');
  });
}
