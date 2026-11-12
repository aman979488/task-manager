import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/staff/screens/staff_directory_screen.dart';
import '../utils/role_permissions.dart';
import '../viewmodels/auth_viewmodel.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, this.staffDirectoryBuilder});

  final WidgetBuilder? staffDirectoryBuilder;

  Future<void> _openStaffDirectory(BuildContext context) async {
    final authViewModel = context.read<AuthViewModel>();
    if (!RolePermissions.canManageStaff(authViewModel.appRole)) return;

    final navigator = Navigator.of(context);
    navigator.pop();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!context.mounted) return;
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (routeContext) =>
            staffDirectoryBuilder?.call(routeContext) ??
            const StaffDirectoryScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final canManageStaff = RolePermissions.canManageStaff(
      authViewModel.appRole,
    );

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFFFBE64E)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  'Task Manager',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B5800),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  authViewModel.userName,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                Text(
                  authViewModel.userEmail,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: const Text('Tasks Map'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: const Text('My Tasks'),
            onTap: () => Navigator.pop(context),
          ),
          if (canManageStaff)
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: const Text('Staff Detail'),
              onTap: () => _openStaffDirectory(context),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              Navigator.pop(context);
              try {
                await context.read<AuthViewModel>().signOut();
              } on FirebaseAuthException catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      error.message ?? 'Could not sign out. Please try again.',
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
