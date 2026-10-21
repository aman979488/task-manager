import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../features/flash/flash_alert_service.dart';
import '../services/notification_service.dart';
import '../utils/role_permissions.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({required this._notificationService}) {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      _loadCurrentUser,
      onError: (Object error) {
        debugPrint('Authentication state error: $error');
        _profileLoadError = 'Could not check authentication state: $error';
        _ready = true;
        notifyListeners();
      },
    );
  }

  final NotificationService _notificationService;
  late final StreamSubscription<User?> _authSubscription;

  AppRole _appRole = AppRole.user;
  String _userUid = '';
  String _userEmail = '';
  String _userName = 'User';
  bool _allowNotifications = true;
  bool _isLoadingProfile = false;
  bool _ready = false;
  String? _profileLoadError;
  int _authEventId = 0;

  AppRole get appRole => _appRole;
  String get userUid => _userUid;
  String get userEmail => _userEmail;
  String get userName => _userName;
  bool get allowNotifications => _allowNotifications;
  bool get isLoadingProfile => _isLoadingProfile;
  bool get ready => _ready;
  bool get loggedIn => _userUid.isNotEmpty;
  String? get profileLoadError => _profileLoadError;

  Map<String, dynamic> get actorMetadata => {
    'uid': _userUid,
    'email': _userEmail,
    'name': _userName,
  };

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (error) {
      return switch (error.code) {
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' => 'Email ya password galat hai',
        'invalid-email' => 'Email sahi format mein daal',
        'too-many-requests' => 'Bahut koshish ho gayi, thodi der baad try kar',
        'network-request-failed' => 'Internet check kar',
        'user-disabled' => 'Yeh account disable hai',
        _ => 'Login nahi hua (${error.code})',
      };
    }
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
    final authEventId = ++_authEventId;
    if (user == null) {
      FlashAlertService.stop();
      _userUid = '';
      _userEmail = '';
      _userName = 'User';
      _appRole = AppRole.user;
      _isLoadingProfile = false;
      _profileLoadError = null;
      _ready = true;
      notifyListeners();
      return;
    }

    _userUid = user.uid;
    _userEmail = user.email ?? '';
    FlashAlertService.start(user.uid);
    _isLoadingProfile = true;
    _ready = false;
    notifyListeners();
    try {
      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (authEventId != _authEventId) return;

      final data = profile.data() ?? <String, dynamic>{};
      final profileName = data['name']?.toString().trim() ?? '';
      _userName = profileName.isNotEmpty
          ? profileName
          : user.displayName ?? (user.email?.split('@').first ?? 'User');
      _appRole = AppRole.fromString(data['role']?.toString());
      _profileLoadError = profile.exists
          ? null
          : 'No profile found for this account. Ask an administrator to add users/${user.uid}.';
      if (_profileLoadError != null) {
        debugPrint(_profileLoadError);
      }
      _isLoadingProfile = false;
      _ready = true;
      notifyListeners();

      if (profile.exists) {
        try {
          await _notificationService.registerDevice(user.uid);
        } catch (error) {
          debugPrint(
            'Could not register this device for push notifications: $error',
          );
        }
      }
    } on FirebaseException catch (error) {
      if (authEventId != _authEventId) return;
      debugPrint('Error loading staff profile: $error');
      _userName = user.displayName ?? user.email?.split('@').first ?? 'User';
      _appRole = AppRole.user;
      _profileLoadError = 'Could not load your user profile: ${error.message}';
      _isLoadingProfile = false;
      _ready = true;
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
    _profileLoadError = null;
    _ready = true;
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
    _ready = true;
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
