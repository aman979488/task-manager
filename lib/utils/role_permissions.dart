enum AppRole {
  superAdmin,
  admin,
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
    return canManageStaff(role);
  }
}
