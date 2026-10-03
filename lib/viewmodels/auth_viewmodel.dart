import 'package:flutter/material.dart';
import '../utils/role_permissions.dart';

class AuthViewModel extends ChangeNotifier {
  AppRole _appRole = AppRole.admin;
  String _userUid = 'user123';
  String _userEmail = 'user@example.com';
  String _userName = 'User';
  bool _allowNotifications = true;

  AppRole get appRole => _appRole;
  String get userUid => _userUid;
  String get userEmail => _userEmail;
  String get userName => _userName;
  bool get allowNotifications => _allowNotifications;

  Map<String, dynamic> get actorMetadata => {
        'uid': _userUid,
        'email': _userEmail,
        'name': _userName,
      };

  void updateRole(AppRole role) {
    _appRole = role;
    notifyListeners();
  }

  void setUser({
    required String uid,
    required String email,
    required String name,
    AppRole? role,
  }) {
    _userUid = uid;
    _userEmail = email;
    _userName = name;
    if (role != null) _appRole = role;
    notifyListeners();
  }

  void setAllowNotifications(bool value) {
    _allowNotifications = value;
    notifyListeners();
  }
}
