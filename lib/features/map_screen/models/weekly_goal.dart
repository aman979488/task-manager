import 'package:cloud_firestore/cloud_firestore.dart';

class WeeklyGoal {
  const WeeklyGoal({
    required this.userUid,
    required this.weekKey,
    required this.title,
    required this.target,
    this.createdAt,
  });

  final String userUid;
  final String weekKey;
  final String title;
  final int target;
  final DateTime? createdAt;

  factory WeeklyGoal.fromMap(Map<String, dynamic> data) {
    final createdAtValue = data['createdAt'];
    return WeeklyGoal(
      userUid: data['userUid']?.toString() ?? '',
      weekKey: data['weekKey']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      target: data['target'] is num ? (data['target'] as num).toInt() : 0,
      createdAt: createdAtValue is Timestamp
          ? createdAtValue.toDate()
          : createdAtValue is DateTime
          ? createdAtValue
          : null,
    );
  }
}
