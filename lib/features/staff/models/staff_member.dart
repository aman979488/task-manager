import '../../../utils/role_permissions.dart';

class StaffMember {
  const StaffMember({
    required this.uid,
    required this.documentId,
    required this.name,
    required this.contactNo,
    required this.email,
    required this.role,
  });

  factory StaffMember.fromMap(String uid, Map<String, dynamic> data) {
    return StaffMember(
      uid: data['uid']?.toString() ?? uid,
      documentId: uid,
      name: data['name']?.toString() ?? '',
      contactNo: data['contactNo']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      role: AppRole.fromString(data['role']?.toString()),
    );
  }

  final String uid;
  final String documentId;
  final String name;
  final String contactNo;
  final String email;
  final AppRole role;

  String get roleLabel => switch (role) {
    AppRole.superAdmin => 'Super Admin',
    AppRole.admin => 'Admin',
    AppRole.user => 'User',
    AppRole.officeStaff => 'Office Staff',
    AppRole.employee => 'Employee',
    AppRole.fieldUser => 'Field User',
  };
}
