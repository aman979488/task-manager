import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/map_screen/models/task.dart';
import 'package:task_manager/features/map_screen/screens/widgets/task_substeps_summary.dart';

void main() {
  testWidgets('shows substep titles and completion state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskSubstepsSummary(
            steps: [
              TaskStep(title: 'Call the client'),
              TaskStep(title: 'Send the details', isDone: true),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Call the client'), findsOneWidget);
    expect(find.text('Send the details'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
  });
}
