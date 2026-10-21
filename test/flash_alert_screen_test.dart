import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/flash/flash_alert_screen.dart';

void main() {
  testWidgets('shows the flash message and dismisses when acknowledged', (
    tester,
  ) async {
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              FlashAlertScreen(
                senderName: 'Aman',
                text: 'Client ko call karo',
                onDismiss: () => dismissed = true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('⚡ FLASH MESSAGE'), findsOneWidget);
    expect(find.text('Message from Aman'), findsOneWidget);
    expect(find.text('Client ko call karo'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    expect(dismissed, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
