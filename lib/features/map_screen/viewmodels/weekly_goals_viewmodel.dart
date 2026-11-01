import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/weekly_goal.dart';
import '../repositories/weekly_goal_repository.dart';

class WeeklyGoalsViewModel extends ChangeNotifier {
  WeeklyGoalsViewModel({
    this.repository,
    this.watchGoalsStream,
    this.initialLoadTimeout = const Duration(seconds: 15),
  });

  final WeeklyGoalRepository? repository;
  final Stream<List<WeeklyGoal>> Function(String userUid)? watchGoalsStream;
  final Duration initialLoadTimeout;
  late final Stream<List<WeeklyGoal>> Function(String userUid) _watchGoals =
      watchGoalsStream ?? (repository ?? WeeklyGoalRepository()).watchGoals;
  StreamSubscription<List<WeeklyGoal>>? _subscription;
  Timer? _loadTimeout;
  Map<String, WeeklyGoal> _goalsByWeek = {};
  bool _isLoading = true;
  String? _errorMessage;
  String? _subscribedUid;

  Map<String, WeeklyGoal> get goalsByWeek => Map.unmodifiable(_goalsByWeek);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void watchGoals(String userUid) {
    final uid = userUid.trim();
    if (_subscribedUid == uid) return;
    _subscribedUid = uid;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _loadTimeout?.cancel();
    _goalsByWeek = {};
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    if (uid.isEmpty) {
      _isLoading = false;
      _errorMessage = 'Could not load weekly goals: user is not signed in.';
      notifyListeners();
      return;
    }

    _loadTimeout = Timer(initialLoadTimeout, () {
      if (!_isLoading) return;
      _isLoading = false;
      _errorMessage = 'Weekly goals are taking too long to load. Check your connection and retry.';
      notifyListeners();
    });

    try {
      _subscription = _watchGoals(uid).listen(
        (goals) {
          _loadTimeout?.cancel();
          _goalsByWeek = {for (final goal in goals) goal.weekKey: goal};
          _isLoading = false;
          _errorMessage = null;
          notifyListeners();
        },
        onError: (Object error) {
          _loadTimeout?.cancel();
          _isLoading = false;
          _errorMessage = 'Could not load weekly goals: $error';
          notifyListeners();
        },
      );
    } catch (error) {
      _loadTimeout?.cancel();
      _isLoading = false;
      _errorMessage = 'Could not load weekly goals: $error';
      notifyListeners();
    }
  }

  void retryGoals(String userUid) {
    _subscribedUid = null;
    watchGoals(userUid);
  }

  Future<void> saveGoal({
    required String userUid,
    required String weekKey,
    required String title,
    required int target,
  }) async {
    final existingGoal = _goalsByWeek[weekKey];
    await (repository ?? WeeklyGoalRepository()).saveGoal(
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
    _loadTimeout?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
