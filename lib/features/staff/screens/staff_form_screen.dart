import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../utils/role_permissions.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../models/staff_member.dart';
import '../services/staff_admin_service.dart';

class StaffFormScreen extends StatefulWidget {
  const StaffFormScreen({super.key, this.member});

  final StaffMember? member;

  @override
  State<StaffFormScreen> createState() => _StaffFormScreenState();
}

class _StaffFormScreenState extends State<StaffFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _contactController;
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  late AppRole _selectedRole;
  var _obscurePassword = true;
  var _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.member != null;

  static const _availableRoles = [
    AppRole.admin,
    AppRole.superAdmin,
    AppRole.user,
  ];

  @override
  void initState() {
    super.initState();
    final member = widget.member;
    _nameController = TextEditingController(text: member?.name ?? '');
    _contactController = TextEditingController(text: member?.contactNo ?? '');
    _emailController = TextEditingController(text: member?.email ?? '');
    _selectedRole = member?.role ?? AppRole.user;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _roleValue(AppRole role) => switch (role) {
    AppRole.superAdmin => 'superAdmin',
    AppRole.admin => 'admin',
    AppRole.user => 'user',
  };

  String _roleLabel(AppRole role) => switch (role) {
    AppRole.superAdmin => 'Super Admin',
    AppRole.admin => 'Admin',
    AppRole.user => 'User',
  };

  List<AppRole> get _formRoles {
    final roles = _availableRoles;
    if (roles.contains(_selectedRole)) return roles;
    return [...roles, _selectedRole];
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final authViewModel = context.read<AuthViewModel>();
    if (!RolePermissions.canManageStaff(authViewModel.appRole)) {
      setState(() => _errorMessage = 'You are not allowed to manage staff.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    FirebaseApp? staffApp;
    User? createdUser;
    try {
      final name = _nameController.text.trim();
      final contactNo = _contactController.text.trim();
      final email = _emailController.text.trim().toLowerCase();
      final role = _roleValue(_selectedRole);

      if (_isEditing) {
        final member = widget.member!;
        final requiresAdminFunction = StaffAdminService.requiresAdminFunction(
          currentEmail: member.email,
          newEmail: email,
        );

        if (!requiresAdminFunction) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(member.documentId)
              .update({'name': name, 'contactNo': contactNo, 'role': role});
        } else {
          await StaffAdminService().updateStaffProfile(
            uid: member.uid,
            name: name,
            contactNo: contactNo,
            email: email,
            role: role,
          );
        }
      } else {
        staffApp = await Firebase.initializeApp(
          name: 'staff-creator-${DateTime.now().microsecondsSinceEpoch}',
          options: Firebase.app().options,
        );
        final credential = await FirebaseAuth.instanceFor(app: staffApp)
            .createUserWithEmailAndPassword(
              email: email,
              password: _passwordController.text,
            );
        createdUser = credential.user;
        if (createdUser == null) {
          throw FirebaseAuthException(
            code: 'user-creation-failed',
            message: 'Firebase did not return the created account.',
          );
        }

        await createdUser.updateDisplayName(name);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(createdUser.uid)
            .set({
              'uid': createdUser.uid,
              'name': name,
              'email': email,
              'contactNo': contactNo,
              'photoUrl': null,
              'role': role,
            });
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FirebaseFunctionsException catch (error) {
      debugPrint('Could not update staff profile: $error');
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = error.code == 'not-found'
            ? 'Deploy the Firebase backend function to update this staff member\'s email. Cloud Functions are not deployed for this project.'
            : error.message ?? 'Could not save staff details.';
      });
    } on FirebaseException catch (error) {
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } on FirebaseException catch (cleanupError) {
          debugPrint(
            'Could not remove incomplete staff account: ${cleanupError.message}',
          );
        }
      }
      debugPrint('Could not save staff: ${error.message}');
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = error.code == 'permission-denied'
            ? 'Firestore rules denied permission to save staff. Deploy the updated Firestore rules, then try again.'
            : error.message ?? 'Could not save staff details.';
      });
    } catch (error) {
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } on FirebaseException catch (cleanupError) {
          debugPrint(
            'Could not remove incomplete staff account: ${cleanupError.message}',
          );
        }
      }
      debugPrint('Could not save staff: $error');
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      await staffApp?.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Staff' : 'Add Staff')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Contact',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a contact number'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Gmail',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            MenuAnchor(
              key: const ValueKey('staff-role-menu'),
              style: const MenuStyle(alignment: AlignmentDirectional.bottomEnd),
              menuChildren: [
                for (final role in _formRoles)
                  MenuItemButton(
                    leadingIcon: role == _selectedRole
                        ? const Icon(Icons.check)
                        : const SizedBox(width: 24),
                    onPressed: _isSaving
                        ? null
                        : () => setState(() => _selectedRole = role),
                    child: SizedBox(width: 200, child: Text(_roleLabel(role))),
                  ),
              ],
              builder: (context, controller, _) => InkWell(
                onTap: _isSaving
                    ? null
                    : () => controller.isOpen
                          ? controller.close()
                          : controller.open(),
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    prefixIcon: Icon(Icons.badge_outlined),
                    suffixIcon: Icon(Icons.arrow_drop_down),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(_roleLabel(_selectedRole)),
                ),
              ),
            ),
            if (!_isEditing) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                obscureText: _obscurePassword,
                obscuringCharacter: '*',
                validator: (value) => value == null || value.length < 6
                    ? 'Password must be at least 6 characters'
                    : null,
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _isEditing ? Icons.save_outlined : Icons.person_add_alt_1,
                  ),
            label: Text(
              _isSaving
                  ? 'Saving...'
                  : _isEditing
                  ? 'Save Changes'
                  : 'Add Staff',
            ),
          ),
        ),
      ),
    );
  }
}
