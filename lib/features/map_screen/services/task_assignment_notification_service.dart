import 'package:cloud_firestore/cloud_firestore.dart';

class TaskAssignmentNotificationService {
  TaskAssignmentNotificationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> sendAssignmentNotification({
    required String assignee,
    required String taskTitle,
    required String senderName,
    required String senderUid,
    required String senderEmail,
    required bool notificationsEnabled,
  }) async {
    final recipient = assignee.trim();
    if (recipient.isEmpty || !notificationsEnabled) return;
    final normalizedAssignee = recipient.toLowerCase();
    if (normalizedAssignee == senderName.trim().toLowerCase() ||
        normalizedAssignee == senderUid.trim().toLowerCase() ||
        normalizedAssignee == senderEmail.trim().toLowerCase()) {
      return;
    }

    String? targetFcmToken;
    final userQuery = await _firestore
        .collection('users')
        .where('name', isEqualTo: recipient)
        .limit(1)
        .get();
    if (userQuery.docs.isNotEmpty) {
      targetFcmToken = userQuery.docs.first.data()['fcmToken']?.toString();
    } else {
      final cpQuery = await _firestore
          .collection('cps')
          .where('cpName', isEqualTo: recipient)
          .limit(1)
          .get();
      if (cpQuery.docs.isNotEmpty) {
        targetFcmToken = cpQuery.docs.first.data()['fcmToken']?.toString();
      }
    }

    await _firestore.collection('notifications').add({
      'recipientName': recipient,
      'recipientFcmToken': targetFcmToken,
      'title': 'New Task Assigned',
      'body': '$senderName assigned you a task: "$taskTitle"',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'type': 'task_assigned',
    });
  }
}
