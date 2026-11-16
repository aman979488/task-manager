import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:task_manager/features/call_history/screens/contacts_view.dart';
import 'package:task_manager/features/call_history/viewmodels/contact_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ContactsView renders header, search, and contact cards matching Callyzer UI', (tester) async {
    final controller = ContactController();
    await controller.loadContacts();

    await tester.pumpWidget(
      ChangeNotifierProvider<ContactController>.value(
        value: controller,
        child: const MaterialApp(
          home: ContactsView(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Top Header
    expect(find.text('Contacts'), findsOneWidget);
    expect(find.byTooltip('Favorites'), findsOneWidget);
    expect(find.byTooltip('Filter'), findsOneWidget);
    expect(find.byTooltip('Sort'), findsOneWidget);
    expect(find.byTooltip('More options'), findsOneWidget);

    // Search bar
    expect(find.text('Search contacts'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);

    // Contact cards
    expect(find.text('Didi 😘'), findsOneWidget);
    expect(find.text('+918237969266'), findsOneWidget);
    expect(find.text('3757'), findsOneWidget);
    expect(find.text('Add to Group'), findsWidgets);

    // Mummy contact
    expect(find.text('Mummy ❤️'), findsOneWidget);
    expect(find.text('+919209985689'), findsOneWidget);
    expect(find.text('2135'), findsOneWidget);

    // Promotional banner card
    expect(
      find.text('Get winning sales scripts, objection handling tactics & pro tips — free!'),
      findsOneWidget,
    );
    expect(find.text('Claim your free scripts'), findsOneWidget);

    // Action buttons inside tiles
    expect(find.byTooltip('Copy Number'), findsWidgets);
    expect(find.byTooltip('Send SMS'), findsWidgets);
    expect(find.byTooltip('WhatsApp'), findsWidgets);
    expect(find.byTooltip('Call'), findsWidgets);

    // Test Search functionality
    await tester.enterText(find.byType(TextField).first, 'Karuna');
    await tester.pumpAndSettle();
    expect(find.text('Karuna Sycs'), findsOneWidget);
    expect(find.text('Didi 😘'), findsNothing);

    // Reset search
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();
    expect(find.text('Didi 😘'), findsOneWidget);

    // Test Add to Group dialog opens
    await tester.tap(find.text('Add to Group').first);
    await tester.pumpAndSettle();
    expect(find.text('Add "Didi 😘" to Group'), findsOneWidget);
    expect(find.text('Family'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);

    // Close sheet
    await tester.tap(find.text('Family'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add to Group'));
    await tester.pumpAndSettle();
  });
}
