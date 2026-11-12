import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/utils/role_permissions.dart';

void main() {
  group('AppRole.fromString', () {
    test('recognizes admin role labels with spaces and mixed casing', () {
      expect(AppRole.fromString(' Admin '), AppRole.admin);
      expect(AppRole.fromString('Super Admin'), AppRole.superAdmin);
      expect(AppRole.fromString('Office Staff'), AppRole.officeStaff);
      expect(AppRole.fromString('Field User'), AppRole.fieldUser);
    });
  });

  group('RolePermissions.canManageStaff', () {
    test('allows only admins and super admins', () {
      expect(RolePermissions.canManageStaff(AppRole.admin), isTrue);
      expect(RolePermissions.canManageStaff(AppRole.superAdmin), isTrue);
      expect(RolePermissions.canManageStaff(AppRole.officeStaff), isFalse);
      expect(RolePermissions.canManageStaff(AppRole.employee), isFalse);
    });
  });
}
