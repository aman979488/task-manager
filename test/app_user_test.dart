import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/auth/models/app_user.dart';

void main() {
  test('AppUser serializes Google profile using users collection fields', () {
    const user = AppUser(
      uid: 'google-uid',
      name: 'Google User',
      email: 'google@example.com',
      contactNo: '+1234567890',
      photoUrl: 'https://example.com/photo.png',
    );

    expect(user.toMap(), {
      'uid': 'google-uid',
      'name': 'Google User',
      'email': 'google@example.com',
      'contactNo': '+1234567890',
      'photoUrl': 'https://example.com/photo.png',
      'role': 'user',
    });
  });
}
