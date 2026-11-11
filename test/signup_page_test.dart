import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/auth/signup_page.dart';
import 'package:task_manager/viewmodels/auth_viewmodel.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() {
  test('Google sign-in cancellation has no error message', () {
    expect(
      AuthViewModel.message(
        const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
      ),
      isEmpty,
    );
    expect(
      AuthViewModel.message(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.unknownError,
        ),
      ),
      'Google sign-in failed',
    );
  });

  testWidgets('signup page offers Google sign-in', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignupPage()));

    expect(find.text('Sign up with Google'), findsOneWidget);
  });

  testWidgets('signup form validates required fields', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignupPage()));

    await tester.ensureVisible(find.text('Sign up'));
    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();

    expect(find.text('Name daalein.'), findsOneWidget);
    expect(find.text('Email daalein.'), findsOneWidget);
    expect(find.text('Contact number daalein.'), findsOneWidget);
    expect(
      find.text('Password kam se kam 6 characters ka ho.'),
      findsOneWidget,
    );
    expect(find.text('Password confirm karein.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signup form validates email and password match', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignupPage()));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Test User',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'not-an-email',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contact number'),
      '1234567890',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password1',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      'password2',
    );

    await tester.ensureVisible(find.text('Sign up'));
    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();

    expect(
      find.text('Email address sahi format mein daalein.'),
      findsOneWidget,
    );
    expect(find.text('Passwords match nahi karte.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
