import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../features/auth/models/app_user.dart';
import '../features/flash/flash_alert_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../utils/role_permissions.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({required this._notificationService, AuthService? authService})
    : _authService = authService ?? AuthService() {
    _authSubscription = _authService.authStateChanges.listen(
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
  final AuthService _authService;
  late final StreamSubscription<User?> _authSubscription;

  AppRole _appRole = AppRole.user;
  String _userUid = '';
  String _userEmail = '';
  String _userName = 'User';
  bool _allowNotifications = true;
  bool _isLoadingProfile = false;
  bool _ready = false;
  String? _profileLoadError;
  String? _googleSignInError;
  int _authEventId = 0;
  bool _isCreatingAccount = false;

  AppRole get appRole => _appRole;
  String get userUid => _userUid;
  String get userEmail => _userEmail;
  String get userName => _userName;
  bool get allowNotifications => _allowNotifications;
  bool get isLoadingProfile => _isLoadingProfile;
  bool get ready => _ready;
  bool get loggedIn => _userUid.isNotEmpty;
  String? get profileLoadError => _profileLoadError;
  String? get googleSignInError => _googleSignInError;

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
      await _authService.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (error) {
      return switch (error.code) {
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' => 'Incorrect email or password.',
        'invalid-email' => 'Enter a valid email address.',
        'too-many-requests' =>
          'Too many sign-in attempts. Please try again later.',
        'network-request-failed' => 'Check your internet connection.',
        'user-disabled' => 'This account has been disabled.',
        _ => 'Unable to sign in (${error.code}).',
      };
    }
  }

  Future<bool> signInWithGoogle() async {
    _googleSignInError = null;
    try {
      final credential = await _authService.signInWithGoogle();
      final user = credential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'google-sign-in-failed',
          message: 'Firebase did not return the signed-in user.',
        );
      }

      final profileRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      if (!(await profileRef.get()).exists) {
        await profileRef.set(
          AppUser(
            uid: user.uid,
            name: user.displayName ?? '',
            email: user.email ?? '',
            contactNo: user.phoneNumber ?? '',
            photoUrl: user.photoURL,
          ).toMap(),
        );
      }
      await _applyProfile(user, profileRef);
      return true;
    } on Object catch (error) {
      _googleSignInError = message(error);
      if (_googleSignInError!.isNotEmpty) {
        debugPrint('Google sign-in failed: $error');
      }
      return false;
    }
  }

  static String message(Object? error) {
    if (error is GoogleSignInException) {
      return error.code == GoogleSignInExceptionCode.canceled &&
              (error.description == null || error.description!.trim().isEmpty)
          ? ''
          : 'Google sign-in failed';
    }
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'network-request-failed' => 'Check your internet connection.',
        'account-exists-with-different-credential' =>
          'This email is already registered with another sign-in method.',
        _ => 'Google sign-in failed',
      };
    }
    if (error is FirebaseException) {
      return 'Could not save your account profile. Please try again.';
    }
    return 'Google sign-in failed';
  }

  Future<void> createAccount({
    required String name,
    required String email,
    required String password,
    required String contactNo,
  }) async {
    _isCreatingAccount = true;
    try {
      final credential = await _authService.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
        displayName: name.trim(),
      );

      final user = credential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-creation-failed',
          message: 'Firebase did not return the created account.',
        );
      }

      final profileRef = await _findOrCreateProfile(
        uid: user.uid,
        email: user.email ?? email.trim(),
        name: name.trim(),
        contactNo: contactNo.trim(),
      );
      await _applyProfile(user, profileRef);
    } finally {
      _isCreatingAccount = false;
    }
  }

  Future<void> signOut() => _authService.signOut();

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
      final profileRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      var profile = await profileRef.get();
      if (authEventId != _authEventId) return;

      if (!profile.exists && !_isCreatingAccount) {
        final displayName = user.displayName?.trim() ?? '';
        await profileRef.set(
          AppUser(
            uid: user.uid,
            name: displayName.isNotEmpty
                ? displayName
                : user.email?.split('@').first ?? 'User',
            email: user.email ?? '',
            contactNo: user.phoneNumber ?? '',
            photoUrl: user.photoURL,
          ).toMap(),
        );
        profile = await profileRef.get();
        if (authEventId != _authEventId) return;
      }

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
    final profileRef = users.doc(uid);
    if ((await profileRef.get()).exists) return profileRef;

    Map<String, dynamic>? existingProfile;
    final byUid = await users.where('uid', isEqualTo: uid).limit(1).get();
    if (byUid.docs.isNotEmpty) {
      existingProfile = byUid.docs.first.data();
    }

    if (existingProfile == null && email.isNotEmpty) {
      final byEmail = await users
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (byEmail.docs.isNotEmpty) {
        existingProfile = byEmail.docs.first.data();
      }
    }

    final existingName = existingProfile?['name']?.toString().trim() ?? '';
    final trimmedName = name.trim();
    final photoUrl = existingProfile?['photoUrl'];
    await profileRef.set(
      AppUser(
        uid: uid,
        name: trimmedName.isNotEmpty
            ? trimmedName
            : existingName.isNotEmpty
            ? existingName
            : email.split('@').first,
        email: email,
        contactNo: contactNo.trim().isNotEmpty
            ? contactNo.trim()
            : existingProfile?['contactNo']?.toString() ?? '',
        photoUrl: photoUrl is String ? photoUrl : null,
      ).toMap(),
    );
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
