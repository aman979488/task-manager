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
}
