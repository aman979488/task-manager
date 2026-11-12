import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/staff_member.dart';
import 'staff_detail_screen.dart';
import 'staff_form_screen.dart';

class StaffDirectoryScreen extends StatefulWidget {
  const StaffDirectoryScreen({super.key, this.staffStream});

  final Stream<QuerySnapshot<Map<String, dynamic>>>? staffStream;

  @override
  State<StaffDirectoryScreen> createState() => _StaffDirectoryScreenState();
}

class _StaffDirectoryScreenState extends State<StaffDirectoryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_updateSearch);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_updateSearch)
      ..dispose();
    super.dispose();
  }

  void _updateSearch() {
    setState(() => _query = _searchController.text.trim().toLowerCase());
  }

  Future<void> _openAddStaff() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const StaffFormScreen()),
    );
    if (!mounted || added != true) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Staff added successfully')));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Staff Detail')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddStaff,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Staff'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search staff by name, email or contact',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.clear),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream:
                  widget.staffStream ??
                  FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _MessageState(
                    icon: Icons.error_outline,
                    message: 'Staff list load nahi hui.',
                    detail: snapshot.error.toString(),
                  );
                }
                if (!snapshot.hasData) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    return const _MessageState(
                      icon: Icons.people_outline,
                      message: 'Abhi koi staff nahi hai.',
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                }

                final staff =
                    snapshot.data!.docs
                        .map(
                          (document) =>
                              StaffMember.fromMap(document.id, document.data()),
                        )
                        .where((member) {
                          if (_query.isEmpty) return true;
                          return member.name.toLowerCase().contains(_query) ||
                              member.email.toLowerCase().contains(_query) ||
                              member.contactNo.toLowerCase().contains(_query);
                        })
                        .toList()
                      ..sort(
                        (first, second) => first.name.toLowerCase().compareTo(
                          second.name.toLowerCase(),
                        ),
                      );

                if (staff.isEmpty) {
                  return _MessageState(
                    icon: Icons.people_outline,
                    message: _query.isEmpty
                        ? 'Abhi koi staff nahi hai.'
                        : 'Is search ke liye koi staff nahi mila.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: staff.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final member = staff[index];
                    final initials = member.name.trim().isEmpty
                        ? '?'
                        : member.name
                              .trim()
                              .split(RegExp(r'\s+'))
                              .take(2)
                              .map((part) => part[0].toUpperCase())
                              .join();
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: colors.primaryContainer,
                          foregroundColor: colors.onPrimaryContainer,
                          child: Text(initials),
                        ),
                        title: Text(
                          member.name.isEmpty ? 'No name' : member.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            [
                              member.email,
                              if (member.contactNo.isNotEmpty) member.contactNo,
                            ].join('\n'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _RoleChip(label: member.roleLabel),
                            const SizedBox(height: 4),
                            const Icon(Icons.chevron_right, size: 20),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => StaffDetailScreen(member: member),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(label, style: Theme.of(context).textTheme.labelSmall),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.icon, required this.message, this.detail});

  final IconData icon;
  final String message;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
