import 'package:cloud_functions/cloud_functions.dart';

class StaffAdminService {
  StaffAdminService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  final FirebaseFunctions _functions;

  static bool requiresAdminFunction({
    required String currentEmail,
    required String newEmail,
  }) {
    return currentEmail.trim().toLowerCase() != newEmail.trim().toLowerCase();
  }

  Future<void> updateStaffProfile({
    required String uid,
    required String name,
    required String contactNo,
    required String email,
    required String role,
  }) async {
    await _functions
        .httpsCallable('updateStaffProfile')
        .call<Map<String, dynamic>>({
          'uid': uid,
          'name': name,
          'contactNo': contactNo,
          'email': email,
          'role': role,
        });
  }
}
