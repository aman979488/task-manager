import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/auth/login_page.dart';

void main() {
  testWidgets('login page offers Google sign-in', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));

    expect(find.text('Continue with Google'), findsOneWidget);
  });
}
