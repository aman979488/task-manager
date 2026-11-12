enum AppRole {
  superAdmin,
  admin,
  officeStaff,
  employee,
  fieldUser,
  user;

  static AppRole fromString(String? role) {
    final normalizedRole = role
        ?.trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s-]+'), '_');
    switch (normalizedRole) {
      case 'superadmin':
      case 'super_admin':
        return AppRole.superAdmin;
      case 'admin':
        return AppRole.admin;
      case 'officestaff':
      case 'office_staff':
        return AppRole.officeStaff;
      case 'employee':
        return AppRole.employee;
      case 'fielduser':
      case 'field_user':
        return AppRole.fieldUser;
      default:
        return AppRole.user;
    }
  }
}

class RolePermissions {
  static bool canManageStaff(AppRole role) {
    return role == AppRole.superAdmin || role == AppRole.admin;
  }

  static bool canManageTasks(AppRole role) {
    return role == AppRole.superAdmin ||
        role == AppRole.admin ||
        role == AppRole.officeStaff;
  }
}
