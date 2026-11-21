import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../viewmodels/auth_viewmodel.dart';
import '../../models/task.dart';
import '../../models/weekly_goal.dart';
import '../../utils/task_goal_metrics.dart';
import '../../utils/task_week_helpers.dart';
import '../../viewmodels/add_task_viewmodel.dart';
import '../../viewmodels/map_screen_viewmodel.dart';
import '../../viewmodels/weekly_goals_viewmodel.dart';
import 'add_task_bottom_sheet.dart';
import 'task_suggestions_sheet.dart';

const Color _brand = Color(0xFF6B5800);
const Color _brandSoft = Color(0xFF8A7320);
const Color _currentTint = Color(0xFFFFF8DC);

class GoalsTabView extends StatelessWidget {
  const GoalsTabView({
    super.key,
    required this.viewModel,
    required this.authViewModel,
    required this.taskResultsBuilder,
  });

  final MapScreenViewModel viewModel;
  final AuthViewModel authViewModel;
  final Widget Function(List<Task> tasks) taskResultsBuilder;

  @override
  Widget build(BuildContext context) {
    return _WeeklyGoalsView(
      viewModel: viewModel,
      authViewModel: authViewModel,
      taskResultsBuilder: taskResultsBuilder,
    );
  }
}

class _WeeklyGoalsView extends StatefulWidget {
  const _WeeklyGoalsView({
    required this.viewModel,
    required this.authViewModel,
    required this.taskResultsBuilder,
  });

  final MapScreenViewModel viewModel;
  final AuthViewModel authViewModel;
  final Widget Function(List<Task> tasks) taskResultsBuilder;

  @override
  State<_WeeklyGoalsView> createState() => _WeeklyGoalsViewState();
}

class _WeeklyGoalsViewState extends State<_WeeklyGoalsView> {
  final Set<String> _expanded = {};
  final Set<int> _expandedMonths = {};
  int? _defaultExpandedMonthKey;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _expanded.add(weekKeyFor(now));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userUid = widget.authViewModel.userUid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<WeeklyGoalsViewModel>().watchGoals(userUid);
    });
  }

  List<Task> _tasksForWeek(String key) => widget.viewModel.tasks.where((task) {
    return (task.weekKey ?? weekKeyForCreatedDate(task.createdDate)) == key;
  }).toList();

  List<DateTime> _monthsToDisplay(WeeklyGoalsViewModel goals) {
    final now = DateTime.now();
    var oldest = DateTime(now.year, now.month - 11);

    void includeMonth(int year, int month) {
      final date = DateTime(year, month);
      if (date.isBefore(oldest)) {
        oldest = date;
      }
    }

    for (final task in widget.viewModel.tasks) {
      final weekKey = task.weekKey ?? weekKeyForCreatedDate(task.createdDate);
      final week = weekKey == null ? null : dateRangeForWeek(weekKey);
      if (week != null) includeMonth(week.year, week.month);
    }
    for (final goal in goals.goalsByWeek.values) {
      final week = dateRangeForWeek(goal.weekKey);
      if (week != null) includeMonth(week.year, week.month);
    }

    final months = <DateTime>[];
    var month = DateTime(now.year, now.month);
    while (!month.isBefore(oldest)) {
      months.add(month);
      month = DateTime(month.year, month.month - 1);
    }
    return months;
  }

  Future<void> _createNewTaskForWeek(TaskWeek week) async {
    await AddTaskBottomSheet.show(context, initialWeekKey: week.key);
    if (mounted) await widget.viewModel.refreshTasks(widget.authViewModel);
  }

  Future<void> _showTaskSuggestionsForWeek(TaskWeek week) =>
      _showTaskSuggestions(
        context: context,
        week: week,
        viewModel: widget.viewModel,
        authViewModel: widget.authViewModel,
      );

  void _openWeekPage(TaskWeek week) {
    final goals = context.read<WeeklyGoalsViewModel>();
    final addTasks = context.read<AddTaskViewModel>();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider<MapScreenViewModel>.value(
              value: widget.viewModel,
            ),
            ChangeNotifierProvider<WeeklyGoalsViewModel>.value(value: goals),
            ChangeNotifierProvider<AddTaskViewModel>.value(value: addTasks),
            ChangeNotifierProvider<AuthViewModel>.value(
              value: widget.authViewModel,
            ),
          ],
          child: _WeekPage(
            week: week,
            viewModel: widget.viewModel,
            authViewModel: widget.authViewModel,
            taskResultsBuilder: widget.taskResultsBuilder,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<MapScreenViewModel>();
    final goals = context.watch<WeeklyGoalsViewModel>();
    final currentWeek = weekKeyFor(DateTime.now());
    final months = _monthsToDisplay(goals);
    if (months.isNotEmpty) {
      final topMonth = months.first;
      final topMonthKey = _monthKey(topMonth.year, topMonth.month);
      if (_defaultExpandedMonthKey != topMonthKey) {
        _expandedMonths.add(topMonthKey);
        _defaultExpandedMonthKey = topMonthKey;
      }
    }

    return Column(
      children: [
        if (goals.isLoading) const LinearProgressIndicator(minHeight: 2),
        if (goals.errorMessage != null)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    goals.errorMessage!,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      goals.retryGoals(widget.authViewModel.userUid),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            itemCount: months.length,
            itemBuilder: (context, index) {
              final month = months[index];
              final monthKey = _monthKey(month.year, month.month);
              final monthExpanded = _expandedMonths.contains(monthKey);
              final weeks = weeksOfMonth(month.year, month.month);
              final monthTaskCount = weeks.fold<int>(
                0,
                (count, week) => count + _tasksForWeek(week.key).length,
              );
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                color: Colors.grey.shade50,
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        '${_monthName(month.month)} ${month.year}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text('$monthTaskCount tasks'),
                      trailing: Icon(
                        monthExpanded ? Icons.expand_less : Icons.expand_more,
                      ),
                      onTap: () => setState(() {
                        if (monthExpanded) {
                          _expandedMonths.remove(monthKey);
                        } else {
                          _expandedMonths.add(monthKey);
                        }
                      }),
                    ),
                    if (monthExpanded)
                      ...weeks.map((week) {
                        final tasks = _tasksForWeek(week.key);
                        final doneCount = tasks
                            .where((task) => task.isDone)
                            .length;
                        final goal = goals.goalsByWeek[week.key];
                        final weekExpanded = _expanded.contains(week.key);
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: _WeekTile(
                            week: week,
                            goal: goal,
                            tasks: tasks,
                            taskResultsBuilder: widget.taskResultsBuilder,
                            isCurrent: week.key == currentWeek,
                            expanded: weekExpanded,
                            onExpand: () => setState(() {
                              if (weekExpanded) {
                                _expanded.remove(week.key);
                              } else {
                                _expanded.add(week.key);
                              }
                            }),
                            onOpen: () => _openWeekPage(week),
                            onAddTask: () => _showTaskSuggestionsForWeek(week),
                            onNewTask: () => _createNewTaskForWeek(week),
                            doneCount: doneCount,
                            score: weeklyGoalScore(tasks),
                          ),
                        );
                      }),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

Future<void> _showTaskSuggestions({
  required BuildContext context,
  required TaskWeek week,
  required MapScreenViewModel viewModel,
  required AuthViewModel authViewModel,
}) {
  final candidates = viewModel.myTasks(authViewModel).where((task) {
    final taskWeek = task.weekKey ?? weekKeyForCreatedDate(task.createdDate);
    return !task.isDone && taskWeek != week.key;
  }).toList();
  final suggestions = viewModel.getVisibleTasks(source: candidates);

  return TaskSuggestionsSheet.show(
    context: context,
    suggestions: suggestions,
    suggestionBuilder: (task, onAdd) => ListTile(
      title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        tooltip: 'Add to week',
        onPressed: onAdd,
        icon: const Icon(Icons.add, color: _brand),
      ),
    ),
    onAddTask: (task) async {
      final previousWeekKey = task.weekKey;
      task.weekKey = week.key;
      try {
        await viewModel.updateTask(task);
      } catch (_) {
        task.weekKey = previousWeekKey;
        rethrow;
      }
    },
    onError: (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add task to week: $error')),
      );
    },
  );
}

class _InfoChip extends StatelessWidget {
  const _InfoChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }
}

class _WeekTile extends StatelessWidget {
  const _WeekTile({
    required this.week,
    required this.goal,
    required this.tasks,
    required this.taskResultsBuilder,
    required this.isCurrent,
    required this.expanded,
    required this.onExpand,
    required this.onOpen,
    required this.onAddTask,
    required this.onNewTask,
    required this.doneCount,
    required this.score,
  });

  final TaskWeek week;
  final WeeklyGoal? goal;
  final List<Task> tasks;
  final Widget Function(List<Task> tasks) taskResultsBuilder;
  final bool isCurrent;
  final bool expanded;
  final VoidCallback onExpand;
  final VoidCallback onOpen;
  final VoidCallback onAddTask;
  final VoidCallback onNewTask;
  final int doneCount;
  final double score;

  @override
  Widget build(BuildContext context) {
    final target = goal?.target ?? 0;
    final progress = target > 0 ? (tasks.length / target).clamp(0.0, 1.0) : 0.0;
    final hasGoal = goal?.title.isNotEmpty == true;
    final stats =
        '$doneCount/${tasks.length} done'
        '${target > 0 ? ' · Target $target' : ''}'
        ' · Score ${_scoreText(score)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: isCurrent ? _currentTint : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '${_monthName(week.month)} '
                                  'Week ${week.weekNumber}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (isCurrent) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF2E6A8),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'Current',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _brand,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: expanded ? 'Collapse week' : 'Expand week',
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints.tightFor(
                            width: 34,
                            height: 34,
                          ),
                          onPressed: onExpand,
                          icon: Icon(
                            expanded ? Icons.expand_less : Icons.expand_more,
                            size: 22,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${_dateLabel(week.start)} - ${_dateLabel(week.end)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        hasGoal ? goal!.title : 'Set a weekly goal',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: hasGoal
                              ? FontWeight.w500
                              : FontWeight.normal,
                          color: hasGoal
                              ? Colors.black87
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          color: _brandSoft,
                          backgroundColor: Colors.grey.shade200,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            stats,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed: onAddTask,
                          style: TextButton.styleFrom(
                            foregroundColor: _brand,
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minimumSize: const Size(0, 32),
                          ),
                          child: const Text(
                            'Add task',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed: onNewTask,
                          style: TextButton.styleFrom(
                            foregroundColor: _brand,
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minimumSize: const Size(0, 32),
                          ),
                          child: const Text(
                            'New task',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded)
            if (tasks.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'No tasks for this week.',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 2),
                child: taskResultsBuilder(tasks),
              ),
        ],
      ),
    );
  }
}

class _WeekPage extends StatelessWidget {
  const _WeekPage({
    required this.week,
    required this.viewModel,
    required this.authViewModel,
    required this.taskResultsBuilder,
  });

  final TaskWeek week;
  final MapScreenViewModel viewModel;
  final AuthViewModel authViewModel;
  final Widget Function(List<Task> tasks) taskResultsBuilder;

  @override
  Widget build(BuildContext context) {
    context.watch<MapScreenViewModel>();
    final tasks = viewModel.tasks.where((task) {
      return (task.weekKey ?? weekKeyForCreatedDate(task.createdDate)) ==
          week.key;
    }).toList();
    final doneCount = tasks.where((task) => task.isDone).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${_monthName(week.month)} Week ${week.weekNumber}',
          style: const TextStyle(fontSize: 14),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_dateLabel(week.start)} - ${_dateLabel(week.end)}, '
                  '${week.year}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _InfoChip('${tasks.length} tasks'),
                        _InfoChip('$doneCount done'),
                        _InfoChip(
                          'Score ${_scoreText(weeklyGoalScore(tasks))}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => _showTaskSuggestions(
                            context: context,
                            week: week,
                            viewModel: viewModel,
                            authViewModel: authViewModel,
                          ),
                          child: const Text('Add task'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () async {
                            await AddTaskBottomSheet.show(
                              context,
                              initialWeekKey: week.key,
                            );
                            if (context.mounted) {
                              await viewModel.refreshTasks(authViewModel);
                            }
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text(
                            'New task',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: tasks.isEmpty
                ? Center(
                    child: Text(
                      'No tasks for this week.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  )
                : SingleChildScrollView(child: taskResultsBuilder(tasks)),
          ),
        ],
      ),
    );
  }
}

int _monthKey(int year, int month) => year * 12 + month;

String _monthName(int month) => const [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
][month - 1];

String _dateLabel(DateTime date) => '${_monthName(date.month)} ${date.day}';

String _scoreText(double score) => score == score.roundToDouble()
    ? score.toInt().toString()
    : score.toStringAsFixed(2);
