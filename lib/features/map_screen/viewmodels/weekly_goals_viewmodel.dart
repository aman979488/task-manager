import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/weekly_goal.dart';
import '../repositories/weekly_goal_repository.dart';

class WeeklyGoalsViewModel extends ChangeNotifier {
  WeeklyGoalsViewModel({WeeklyGoalRepository? repository})
    : _repository = repository ?? WeeklyGoalRepository();

  final WeeklyGoalRepository _repository;
  StreamSubscription<List<WeeklyGoal>>? _subscription;
  Map<String, WeeklyGoal> _goalsByWeek = {};
  bool _isLoading = true;
  String? _errorMessage;
  String? _subscribedUid;

  Map<String, WeeklyGoal> get goalsByWeek =>
      Map.unmodifiable(_goalsByWeek);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void watchGoals(String userUid) {
    if (_subscribedUid == userUid && _errorMessage == null) return;
    _subscribedUid = userUid;
    unawaited(_subscription?.cancel());
    _goalsByWeek = {};
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription = _repository.watchGoals(userUid).listen(
      (goals) {
        _goalsByWeek = {for (final goal in goals) goal.weekKey: goal};
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (Object error) {
        _isLoading = false;
        _errorMessage = 'Could not load weekly goals: $error';
        notifyListeners();
      },
    );
  }

  Future<void> saveGoal({
    required String userUid,
    required String weekKey,
    required String title,
    required int target,
  }) async {
    final existingGoal = _goalsByWeek[weekKey];
    await _repository.saveGoal(
      WeeklyGoal(
        userUid: userUid,
        weekKey: weekKey,
        title: title.trim(),
        target: target,
        createdAt: existingGoal?.createdAt,
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
