import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/flash/flash_alert_screen.dart';

void main() {
  testWidgets('shows the flash message and dismisses when acknowledged', (
    tester,
  ) async {
    String? submittedResponse;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              FlashAlertScreen(
                senderName: 'Aman',
                text: 'Client ko call karo',
                onRespond: ({response, responseText}) async {
                  submittedResponse = response;
                },
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('⚡ FLASH MESSAGE'), findsOneWidget);
    expect(find.text('Message from Aman'), findsOneWidget);
    expect(find.text('Client ko call karo'), findsOneWidget);

    await tester.ensureVisible(find.text('Got it'));
    await tester.tap(find.text('Got it'));
    await tester.pump();
    expect(submittedResponse, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('sends a selected status response', (tester) async {
    String? submittedResponse;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              FlashAlertScreen(
                senderName: 'Aman',
                text: 'How is the task going?',
                onRespond: ({response, responseText}) async {
                  submittedResponse = response;
                },
              ),
            ],
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Finished'));
    await tester.tap(find.text('Finished'));
    await tester.pump();

    expect(submittedResponse, 'Finished');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('sends a typed response from Others', (tester) async {
    String? submittedResponse;
    String? submittedText;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              FlashAlertScreen(
                senderName: 'Aman',
                text: 'How is the task going?',
                onRespond: ({response, responseText}) async {
                  submittedResponse = response;
                  submittedText = responseText;
                },
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Others'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'I will call in 10 minutes');
    await tester.ensureVisible(find.text('Send response'));
    await tester.tap(find.text('Send response'));
    await tester.pump();

    expect(submittedResponse, 'Others');
    expect(submittedText, 'I will call in 10 minutes');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
