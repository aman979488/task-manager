import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/auth_viewmodel.dart';

class FlashSentMessagesScreen extends StatelessWidget {
  const FlashSentMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final senderUid = context.watch<AuthViewModel>().userUid;
    final messages = FirebaseFirestore.instance
        .collection('flashMessages')
        .where('senderUid', isEqualTo: senderUid)
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Flash messages')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: messages.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Could not load Flash messages. Please try again.'),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final documents = snapshot.data?.docs ?? [];
          if (documents.isEmpty) {
            return const Center(child: Text('No Flash messages sent yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final data = documents[index].data();
              final response = data['response']?.toString();
              final responseText = data['responseText']?.toString();
              final status = data['status']?.toString() ?? 'sent';
              final hasResponse = response != null && response.isNotEmpty;
              final answer =
                  response == 'Others' &&
                      responseText != null &&
                      responseText.isNotEmpty
                  ? responseText
                  : response;
              final timestamp = data['createdAt'];
              final sentAt = timestamp is Timestamp ? timestamp.toDate() : null;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bolt, color: Color(0xFFB88A00)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'To: ${data['recipientName'] ?? 'Staff'}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Text(
                            _statusLabel(status, hasResponse),
                            style: TextStyle(
                              color: hasResponse
                                  ? Colors.green.shade700
                                  : Colors.blueGrey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (sentAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _formatDateTime(sentAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text(data['text']?.toString() ?? ''),
                      const Divider(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.reply, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              hasResponse
                                  ? 'Response: $answer'
                                  : status == 'seen'
                                  ? 'Seen — no response selected'
                                  : status == 'scheduled'
                                  ? 'Scheduled'
                                  : 'Waiting for response',
                              style: TextStyle(
                                fontWeight: hasResponse
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static String _statusLabel(String status, bool hasResponse) {
    if (hasResponse) return 'Replied';
    if (status == 'scheduled') return 'Scheduled';
    if (status == 'seen') return 'Seen';
    return 'Sent';
  }

  static String _formatDateTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '${value.day}/${value.month}/${value.year} $hour:$minute $period';
  }
}
