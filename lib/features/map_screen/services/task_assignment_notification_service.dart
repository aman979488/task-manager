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
  }) async {
    final recipient = assignee.trim();
    if (recipient.isEmpty) return;
    final normalizedAssignee = recipient.toLowerCase();
    if (normalizedAssignee == senderName.trim().toLowerCase() ||
        normalizedAssignee == senderUid.trim().toLowerCase() ||
        normalizedAssignee == senderEmail.trim().toLowerCase()) {
      return;
    }

    String? recipientUid;
    String? targetFcmToken;
    final userQuery = await _firestore
        .collection('users')
        .where('name', isEqualTo: recipient)
        .limit(1)
        .get();
    if (userQuery.docs.isNotEmpty) {
      final profile = userQuery.docs.first;
      final data = profile.data();
      recipientUid = data['uid']?.toString().trim();
      if (recipientUid == null || recipientUid.isEmpty) {
        recipientUid = profile.id;
      }
      targetFcmToken = data['fcmToken']?.toString();
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
      'recipientUid': recipientUid,
      'recipientFcmToken': targetFcmToken,
      'title': 'New Task Assigned',
      'body': '$senderName assigned you a task: "$taskTitle"',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'type': 'task_assigned',
    });
  }
}
