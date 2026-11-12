import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/staff_member.dart';
import 'staff_form_screen.dart';

class StaffDetailScreen extends StatelessWidget {
  const StaffDetailScreen({
    super.key,
    required this.member,
    this.profileStream,
  });

  final StaffMember member;
  final Stream<DocumentSnapshot<Map<String, dynamic>>>? profileStream;

  Future<void> _editStaff(
    BuildContext context,
    StaffMember currentMember,
  ) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => StaffFormScreen(member: currentMember),
      ),
    );
    if (!context.mounted || updated != true) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Staff details updated')));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          profileStream ??
          FirebaseFirestore.instance
              .collection('users')
              .doc(member.documentId)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Staff Detail')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Staff detail load nahi hua: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final currentMember = snapshot.hasData && snapshot.data!.exists
            ? StaffMember.fromMap(snapshot.data!.id, snapshot.data!.data()!)
            : member;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Staff Detail'),
            actions: [
              IconButton(
                tooltip: 'Edit staff',
                onPressed: () => _editStaff(context, currentMember),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 12),
              Center(
                child: CircleAvatar(
                  radius: 42,
                  child: Text(
                    currentMember.name.trim().isEmpty
                        ? '?'
                        : currentMember.name
                              .trim()
                              .split(RegExp(r'\s+'))
                              .take(2)
                              .map((part) => part[0].toUpperCase())
                              .join(),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                currentMember.name.isEmpty ? 'No name' : currentMember.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Center(child: Chip(label: Text(currentMember.roleLabel))),
              const SizedBox(height: 28),
              _DetailRow(
                icon: Icons.email_outlined,
                label: 'Gmail',
                value: currentMember.email,
              ),
              _DetailRow(
                icon: Icons.phone_outlined,
                label: 'Contact',
                value: currentMember.contactNo,
              ),
              _DetailRow(
                icon: Icons.badge_outlined,
                label: 'Role',
                value: currentMember.roleLabel,
              ),
              _DetailRow(
                icon: Icons.fingerprint,
                label: 'Staff ID',
                value: currentMember.uid,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _editStaff(context, currentMember),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit Staff'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(value.isEmpty ? 'Not provided' : value),
      ),
    );
  }
}
