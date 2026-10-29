import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/weekly_goal.dart';

class WeeklyGoalRepository {
  WeeklyGoalRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _weeklyGoals =>
      _firestore.collection('weeklyGoals');

  Stream<List<WeeklyGoal>> watchGoals(String userUid) {
    return _weeklyGoals
        .where('userUid', isEqualTo: userUid)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => WeeklyGoal.fromMap(doc.data()))
              .toList(),
        );
  }

  Future<void> saveGoal(WeeklyGoal goal) async {
    await _weeklyGoals.doc('${goal.userUid}_${goal.weekKey}').set({
      'userUid': goal.userUid,
      'weekKey': goal.weekKey,
      'title': goal.title,
      'target': goal.target,
      'createdAt': goal.createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(goal.createdAt!),
    }, SetOptions(merge: true));
  }
}
