import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../utils/role_permissions.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({required NotificationService notificationService})
    : _notificationService = notificationService {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      _loadCurrentUser,
      onError: (Object error) {
        debugPrint('Authentication state error: $error');
      },
    );
  }

  final NotificationService _notificationService;
  late final StreamSubscription<User?> _authSubscription;

  AppRole _appRole = AppRole.admin;
  String _userUid = 'user123';
  String _userEmail = 'user@example.com';
  String _userName = 'User';
  bool _allowNotifications = true;
  bool _isLoadingProfile = false;

  AppRole get appRole => _appRole;
  String get userUid => _userUid;
  String get userEmail => _userEmail;
  String get userName => _userName;
  bool get allowNotifications => _allowNotifications;
  bool get isLoadingProfile => _isLoadingProfile;

  Map<String, dynamic> get actorMetadata => {
    'uid': _userUid,
    'email': _userEmail,
    'name': _userName,
  };

  Future<void> signIn({required String email, required String password}) async {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> createAccount({
    required String name,
    required String email,
    required String password,
    required String contactNo,
  }) async {
    final credential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );

    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-creation-failed',
        message: 'Firebase did not return the created account.',
      );
    }

    await user.updateDisplayName(name.trim());
    final profileRef = await _findOrCreateProfile(
      uid: user.uid,
      email: email.trim(),
      name: name.trim(),
      contactNo: contactNo.trim(),
    );
    await _applyProfile(user, profileRef);
  }

  Future<void> signOut() => FirebaseAuth.instance.signOut();

  Future<void> _loadCurrentUser(User? user) async {
    if (user == null) {
      _userUid = 'user123';
      _userEmail = 'user@example.com';
      _userName = 'User';
      _appRole = AppRole.admin;
      _isLoadingProfile = false;
      notifyListeners();
      return;
    }

    _isLoadingProfile = true;
    notifyListeners();
    try {
      final profileRef = await _findOrCreateProfile(
        uid: user.uid,
        email: user.email ?? '',
        name: user.displayName ?? '',
      );
      await _applyProfile(user, profileRef);
    } catch (error) {
      debugPrint('Error loading staff profile: $error');
      _userUid = user.uid;
      _userEmail = user.email ?? '';
      _userName = user.displayName ?? user.email?.split('@').first ?? 'Staff';
      _appRole = AppRole.employee;
      _isLoadingProfile = false;
      notifyListeners();
    }
  }

  Future<DocumentReference<Map<String, dynamic>>> _findOrCreateProfile({
    required String uid,
    required String email,
    required String name,
    String contactNo = '',
  }) async {
    final users = FirebaseFirestore.instance.collection('users');
    final byUid = await users.where('uid', isEqualTo: uid).limit(1).get();
    if (byUid.docs.isNotEmpty) {
      return byUid.docs.first.reference;
    }

    if (email.isNotEmpty) {
      final byEmail = await users
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (byEmail.docs.isNotEmpty) {
        await byEmail.docs.first.reference.update({'uid': uid});
        return byEmail.docs.first.reference;
      }
    }

    final profileRef = users.doc(uid);
    await profileRef.set({
      'uid': uid,
      'name': name.isEmpty ? email.split('@').first : name,
      'email': email,
      'contactNo': contactNo,
      'role': 'employee',
    });
    return profileRef;
  }

  Future<void> _applyProfile(
    User user,
    DocumentReference<Map<String, dynamic>> profileRef,
  ) async {
    final snapshot = await profileRef.get();
    final profile = snapshot.data() ?? <String, dynamic>{};

    _userUid = user.uid;
    _userEmail = user.email ?? profile['email']?.toString() ?? '';
    _userName =
        profile['name']?.toString() ??
        user.displayName ??
        _userEmail.split('@').first;
    _appRole = AppRole.fromString(profile['role']?.toString());
    _isLoadingProfile = false;
    notifyListeners();

    try {
      await _notificationService.registerDevice(user.uid);
    } catch (error) {
      debugPrint(
        'Could not register this device for push notifications: $error',
      );
    }
  }

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

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}
