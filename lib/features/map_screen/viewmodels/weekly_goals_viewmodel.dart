import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/weekly_goal.dart';
import '../repositories/weekly_goal_repository.dart';

class WeeklyGoalsViewModel extends ChangeNotifier {
  WeeklyGoalsViewModel({
    this.repository,
    this.watchGoalsStream,
    this.watchAllGoalsStream,
    this.initialLoadTimeout = const Duration(seconds: 15),
  });

  final WeeklyGoalRepository? repository;
  final Stream<List<WeeklyGoal>> Function(String userUid)? watchGoalsStream;
  final Stream<List<WeeklyGoal>> Function()? watchAllGoalsStream;
  final Duration initialLoadTimeout;
  late final Stream<List<WeeklyGoal>> Function(String userUid) _watchGoals =
      watchGoalsStream ?? (repository ?? WeeklyGoalRepository()).watchGoals;
  late final Stream<List<WeeklyGoal>> Function() _watchAllGoals =
      watchAllGoalsStream ??
      (repository ?? WeeklyGoalRepository()).watchAllGoals;
  StreamSubscription<List<WeeklyGoal>>? _subscription;
  Timer? _loadTimeout;
  Map<(String, String), WeeklyGoal> _goalsByUserAndWeek = {};
  bool _isLoading = true;
  String? _errorMessage;
  String? _subscribedUid;
  bool? _subscribedToAllUsers;

  List<WeeklyGoal> get goals =>
      List<WeeklyGoal>.unmodifiable(_goalsByUserAndWeek.values);

  List<WeeklyGoal> goalsForWeek(String weekKey) =>
      _goalsByUserAndWeek.values
          .where((goal) => goal.weekKey == weekKey)
          .toList()
        ..sort((first, second) => first.userUid.compareTo(second.userUid));

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void watchGoals(String userUid, {bool includeAllUsers = false}) {
    final uid = userUid.trim();
    if (_subscribedUid == uid && _subscribedToAllUsers == includeAllUsers) {
      return;
    }
    _subscribedUid = uid;
    _subscribedToAllUsers = includeAllUsers;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _loadTimeout?.cancel();
    _goalsByUserAndWeek = {};
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
      final goalStream = includeAllUsers ? _watchAllGoals() : _watchGoals(uid);
      _subscription = goalStream.listen(
        (goals) {
          _loadTimeout?.cancel();
          _goalsByUserAndWeek = {
            for (final goal in goals) (goal.userUid, goal.weekKey): goal,
          };
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

  void retryGoals(String userUid, {bool includeAllUsers = false}) {
    _subscribedUid = null;
    _subscribedToAllUsers = null;
    watchGoals(userUid, includeAllUsers: includeAllUsers);
  }

  Future<void> saveGoal({
    required String userUid,
    required String weekKey,
    required String title,
    required int target,
  }) async {
    final existingGoal = _goalsByUserAndWeek[(userUid, weekKey)];
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
