import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:task_manager/features/staff/models/staff_member.dart';
import 'package:task_manager/features/staff/screens/staff_directory_screen.dart';
import 'package:task_manager/features/staff/screens/staff_detail_screen.dart';
import 'package:task_manager/features/staff/screens/staff_form_screen.dart';
import 'package:task_manager/utils/role_permissions.dart';
import 'package:task_manager/viewmodels/auth_viewmodel.dart';
import 'package:task_manager/widgets/app_drawer.dart';

class FakeAuthViewModel extends ChangeNotifier implements AuthViewModel {
  FakeAuthViewModel({this.role = AppRole.admin});

  final AppRole role;

  @override
  AppRole get appRole => role;

  @override
  String get userName => 'Admin User';

  @override
  String get userEmail => 'admin@example.com';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app({AppRole role = AppRole.admin}) {
  return ChangeNotifierProvider<AuthViewModel>.value(
    value: FakeAuthViewModel(role: role),
    child: MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Home')),
        drawer: AppDrawer(
          staffDirectoryBuilder: (_) =>
              StaffDirectoryScreen(staffStream: const Stream.empty()),
        ),
      ),
    ),
  );
}

Future<void> _openStaffDirectory(WidgetTester tester) async {
  final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
  scaffoldState.openDrawer();
  await tester.pumpAndSettle();
  expect(find.text('Staff Detail'), findsOneWidget);
  await tester.tap(find.text('Staff Detail'));
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
  expect(find.byType(StaffDirectoryScreen), findsOneWidget);
}

void main() {
  testWidgets('Staff Detail opens list, then Add Staff opens a full screen', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await _openStaffDirectory(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.widgetWithText(FloatingActionButton, 'Add Staff'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add Staff'));
    await tester.pumpAndSettle();

    expect(find.text('Add Staff'), findsWidgets);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.widgetWithText(TextFormField, 'Name'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Contact'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Gmail'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<AppRole>));
    await tester.pumpAndSettle();
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('Super Admin'), findsOneWidget);
    expect(find.text('User'), findsWidgets);
    expect(find.text('Office Staff'), findsNothing);
    expect(find.text('Employee'), findsNothing);
    await tester.tap(find.text('Admin').first);
    await tester.pumpAndSettle();

    final passwordField = find.widgetWithText(TextFormField, 'Password');
    final passwordTextField = find.descendant(
      of: passwordField,
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(passwordTextField).obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(passwordTextField).obscureText, isFalse);
  });

  testWidgets('Add Staff shows validation errors on its own screen', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await _openStaffDirectory(tester);
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add Staff'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Add Staff'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a name'), findsOneWidget);
    expect(find.text('Enter a contact number'), findsOneWidget);
    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Password must be at least 6 characters'), findsOneWidget);
  });

  testWidgets('Super Admin can choose only the three supported roles', (
    tester,
  ) async {
    await tester.pumpWidget(_app(role: AppRole.superAdmin));
    await _openStaffDirectory(tester);
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add Staff'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<AppRole>));
    await tester.pumpAndSettle();

    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('Super Admin'), findsOneWidget);
    expect(find.text('User'), findsWidgets);
    expect(find.text('Office Staff'), findsNothing);
    expect(find.text('Employee'), findsNothing);
    expect(find.text('Field User'), findsNothing);
  });

  testWidgets('Staff detail opens a separate edit screen', (tester) async {
    const member = StaffMember(
      uid: 'staff-uid',
      documentId: 'staff-uid',
      name: 'Existing Staff',
      contactNo: '1234567890',
      email: 'staff@example.com',
      role: AppRole.user,
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthViewModel>.value(
        value: FakeAuthViewModel(role: AppRole.superAdmin),
        child: const MaterialApp(
          home: StaffDetailScreen(
            member: member,
            profileStream: Stream.empty(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Existing Staff'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit staff'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Staff'), findsWidgets);
    expect(find.widgetWithText(TextFormField, 'Name'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Contact'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Gmail'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsNothing);
  });

  testWidgets('Save button stays above the keyboard', (tester) async {
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthViewModel>.value(
        value: FakeAuthViewModel(),
        child: const MaterialApp(home: StaffFormScreen()),
      ),
    );

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    final saveButton = find.widgetWithText(FilledButton, 'Add Staff');
    final visibleHeight =
        tester.view.physicalSize.height - tester.view.viewInsets.bottom;
    expect(tester.getRect(saveButton).bottom, lessThan(visibleHeight));
  });
}
