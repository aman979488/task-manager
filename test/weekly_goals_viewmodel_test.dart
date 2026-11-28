import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/map_screen/models/weekly_goal.dart';
import 'package:task_manager/features/map_screen/viewmodels/weekly_goals_viewmodel.dart';

void main() {
  test('weekly goal loading stops and can retry a stalled stream', () async {
    var streamCalls = 0;
    final viewModel = WeeklyGoalsViewModel(
      initialLoadTimeout: const Duration(milliseconds: 5),
      watchGoalsStream: (_) => Stream<List<WeeklyGoal>>.multi((controller) {
        streamCalls++;
        if (streamCalls > 1) controller.add(const []);
      }),
    );

    viewModel.watchGoals('user-1');
    viewModel.watchGoals('user-1');
    expect(streamCalls, 1);
    expect(viewModel.isLoading, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(viewModel.isLoading, isFalse);
    expect(viewModel.errorMessage, contains('taking too long'));

    viewModel.retryGoals('user-1');
    await Future<void>.delayed(Duration.zero);
    expect(streamCalls, 2);
    expect(viewModel.isLoading, isFalse);
    expect(viewModel.errorMessage, isNull);
    viewModel.dispose();
  });

  test('missing user does not leave weekly goals loading', () {
    final viewModel = WeeklyGoalsViewModel(
      watchGoalsStream: (_) => const Stream<List<WeeklyGoal>>.empty(),
    );

    viewModel.watchGoals('  ');

    expect(viewModel.isLoading, isFalse);
    expect(viewModel.errorMessage, contains('not signed in'));
    viewModel.dispose();
  });

  test('admin can load every user goal including same-week goals', () async {
    const sharedWeek = '2026-11-W4';
    const adminGoal = WeeklyGoal(
      userUid: 'admin-1',
      weekKey: sharedWeek,
      title: 'Admin goal',
      target: 4,
    );
    const userGoal = WeeklyGoal(
      userUid: 'nirmal-1',
      weekKey: sharedWeek,
      title: 'Nirmal goal',
      target: 3,
    );
    var allGoalsStreamCalls = 0;
    var userGoalsStreamCalls = 0;
    final viewModel = WeeklyGoalsViewModel(
      watchGoalsStream: (_) {
        userGoalsStreamCalls++;
        return Stream.value(const [adminGoal]);
      },
      watchAllGoalsStream: () {
        allGoalsStreamCalls++;
        return Stream.value(const [adminGoal, userGoal]);
      },
    );

    viewModel.watchGoals('admin-1', includeAllUsers: true);
    await Future<void>.delayed(Duration.zero);

    expect(allGoalsStreamCalls, 1);
    expect(userGoalsStreamCalls, 0);
    expect(viewModel.goalsForWeek(sharedWeek), [adminGoal, userGoal]);
    viewModel.dispose();
  });

  test('regular users subscribe only to their own goals', () async {
    const ownGoal = WeeklyGoal(
      userUid: 'nirmal-1',
      weekKey: '2026-11-W4',
      title: 'Nirmal goal',
      target: 3,
    );
    var requestedUid = '';
    var allGoalsStreamCalls = 0;
    final viewModel = WeeklyGoalsViewModel(
      watchGoalsStream: (userUid) {
        requestedUid = userUid;
        return Stream.value(const [ownGoal]);
      },
      watchAllGoalsStream: () {
        allGoalsStreamCalls++;
        return const Stream<List<WeeklyGoal>>.empty();
      },
    );

    viewModel.watchGoals('nirmal-1');
    await Future<void>.delayed(Duration.zero);

    expect(requestedUid, 'nirmal-1');
    expect(allGoalsStreamCalls, 0);
    expect(viewModel.goals, [ownGoal]);
    viewModel.dispose();
  });
}
