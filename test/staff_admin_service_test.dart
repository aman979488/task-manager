import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/staff/services/staff_admin_service.dart';

void main() {
  group('StaffAdminService.requiresAdminFunction', () {
    test('does not require a function when email is unchanged', () {
      expect(
        StaffAdminService.requiresAdminFunction(
          currentEmail: 'Staff@Example.com ',
          newEmail: 'staff@example.com',
        ),
        isFalse,
      );
    });

    test('requires a function when Gmail changes', () {
      expect(
        StaffAdminService.requiresAdminFunction(
          currentEmail: 'staff@example.com',
          newEmail: 'new@example.com',
        ),
        isTrue,
      );
    });
  });
}
