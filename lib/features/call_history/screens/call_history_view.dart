import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/call_log_controller.dart';
import '../models/contact_model.dart';
import '../widgets/call_log_tile.dart';
import '../widgets/contact_avatar.dart';

class CallHistoryView extends StatelessWidget {
  final ContactModel contact;

  const CallHistoryView({super.key, required this.contact});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CallLogController>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(contact.name)),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  ContactAvatar(contact: contact, radius: 48),
                  const SizedBox(height: 12),
                  Text(
                    contact.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  for (final number in contact.phoneNumbers)
                    Text(number, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          if (controller.isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (controller.permissionDenied)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Call log permission is needed'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => controller.loadFor(contact),
                      child: const Text('Try again'),
                    ),
                    TextButton(
                      onPressed: controller.openCallLogSettings,
                      child: const Text('Open settings'),
                    ),
                  ],
                ),
              ),
            )
          else if (controller.logs.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('No calls with this contact')),
            )
          else
            SliverList(
              delegate: SliverChildListDelegate([
                for (final entry in controller.groupedLogs.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 4),
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  for (final log in entry.value) CallLogTile(log: log),
                ],
              ]),
            ),
        ],
      ),
    );
  }
}
