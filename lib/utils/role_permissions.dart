enum AppRole {
  superAdmin,
  admin,
  officeStaff,
  employee,
  fieldUser,
  user;

  static AppRole fromString(String? role) {
    switch (role?.toLowerCase()) {
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
  static bool canManageTasks(AppRole role) {
    return role == AppRole.superAdmin ||
        role == AppRole.admin ||
        role == AppRole.officeStaff;
  }
}
