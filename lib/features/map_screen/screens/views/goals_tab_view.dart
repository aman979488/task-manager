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
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            labelColor: Color(0xFF6B5800),
            unselectedLabelColor: Colors.black54,
            indicatorColor: Color(0xFF6B5800),
            labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: 'Weekly'),
              Tab(text: 'Monthly'),
              Tab(text: 'My Goal'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _WeeklyGoalsView(
                  viewModel: viewModel,
                  authViewModel: authViewModel,
                  taskResultsBuilder: taskResultsBuilder,
                ),
                _MonthlyGoalsView(
                  viewModel: viewModel,
                  taskResultsBuilder: taskResultsBuilder,
                ),
                const _Placeholder(
                  text: 'Personal goals will be available soon.',
                ),
              ],
            ),
          ),
        ],
      ),
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

class _MonthlyGoalsView extends StatefulWidget {
  const _MonthlyGoalsView({
    required this.viewModel,
    required this.taskResultsBuilder,
  });

  final MapScreenViewModel viewModel;
  final Widget Function(List<Task> tasks) taskResultsBuilder;

  @override
  State<_MonthlyGoalsView> createState() => _MonthlyGoalsViewState();
}

class _MonthlyGoalsViewState extends State<_MonthlyGoalsView> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<MapScreenViewModel>();
    final monthlyTasks = widget.viewModel.tasks.where((task) {
      if (!task.isMonthlyGoal) return false;
      final key = task.weekKey ?? weekKeyForCreatedDate(task.createdDate);
      final week = key == null ? null : dateRangeForWeek(key);
      return week != null &&
          week.year == _month.year &&
          week.month == _month.month;
    }).toList();
    final doneCount = monthlyTasks.where((task) => task.isDone).length;

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous month',
              onPressed: () => setState(
                () => _month = DateTime(_month.year, _month.month - 1),
              ),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '${_monthName(_month.month)} ${_month.year} · '
                '${monthlyTasks.length} goals · $doneCount done · '
                'Score ${_scoreText(weeklyGoalScore(monthlyTasks))}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next month',
              onPressed: () => setState(
                () => _month = DateTime(_month.year, _month.month + 1),
              ),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        if (monthlyTasks.isEmpty)
          const Expanded(
            child: Center(
              child: Text(
                'No monthly goals marked yet.',
                style: TextStyle(fontSize: 14),
              ),
            ),
          )
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              children: [widget.taskResultsBuilder(monthlyTasks)],
            ),
          ),
      ],
    );
  }
}

class _WeeklyGoalsViewState extends State<_WeeklyGoalsView> {
  late DateTime _month;
  final Set<String> _collapsed = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.read<WeeklyGoalsViewModel>().watchGoals(
      widget.authViewModel.userUid,
    );
  }

  List<Task> _tasksForWeek(String key) => widget.viewModel.tasks.where((task) {
    return (task.weekKey ?? weekKeyForCreatedDate(task.createdDate)) == key;
  }).toList();

  Future<void> _addTaskForWeek(TaskWeek week) async {
    await AddTaskBottomSheet.show(context, initialWeekKey: week.key);
    if (mounted) await widget.viewModel.refreshTasks(widget.authViewModel);
  }

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
    final weeks = weeksOfMonth(_month.year, _month.month);
    final currentWeek = weekKeyFor(DateTime.now());
    final monthTaskCount = weeks.fold<int>(
      0,
      (count, week) => count + _tasksForWeek(week.key).length,
    );

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous month',
              onPressed: () => setState(
                () => _month = DateTime(_month.year, _month.month - 1),
              ),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '${_monthName(_month.month)} ${_month.year} · '
                '$monthTaskCount tasks',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next month',
              onPressed: () => setState(
                () => _month = DateTime(_month.year, _month.month + 1),
              ),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        if (goals.isLoading) const LinearProgressIndicator(minHeight: 2),
        if (goals.errorMessage != null)
          Material(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                        goals.watchGoals(widget.authViewModel.userUid),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            itemCount: weeks.length,
            itemBuilder: (context, index) {
              final week = weeks[index];
              final tasks = _tasksForWeek(week.key);
              final doneCount = tasks.where((task) => task.isDone).length;
              final goal = goals.goalsByWeek[week.key];
              final expanded = !_collapsed.contains(week.key);
              return _WeekTile(
                week: week,
                goal: goal,
                tasks: tasks,
                taskResultsBuilder: widget.taskResultsBuilder,
                isCurrent: week.key == currentWeek,
                expanded: expanded,
                onExpand: () => setState(() {
                  if (expanded) {
                    _collapsed.add(week.key);
                  } else {
                    _collapsed.remove(week.key);
                  }
                }),
                onOpen: () => _openWeekPage(week),
                onAddTask: () => _addTaskForWeek(week),
                doneCount: doneCount,
                score: weeklyGoalScore(tasks),
              );
            },
          ),
        ),
      ],
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
  final int doneCount;
  final double score;

  @override
  Widget build(BuildContext context) {
    final target = goal?.target ?? 0;
    final progress = target > 0 ? (tasks.length / target).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isCurrent ? const Color(0xFF6B5800) : Colors.grey.shade300,
              width: isCurrent ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: onOpen,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            '${_monthName(week.month)} Week ${week.weekNumber}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (isCurrent)
                      const Text(
                        'Current week',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B5800),
                        ),
                      ),
                    IconButton(
                      tooltip: expanded ? 'Collapse week' : 'Expand week',
                      onPressed: onExpand,
                      icon: Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: onOpen,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_dateLabel(week.start)} - ${_dateLabel(week.end)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        goal?.title.isNotEmpty == true
                            ? goal!.title
                            : 'Set a weekly goal',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${tasks.length} tasks · $doneCount done'
                        '${target > 0 ? ' · Target $target' : ''}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Add task to Week ${week.weekNumber}',
                      visualDensity: VisualDensity.compact,
                      onPressed: onAddTask,
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: Color(0xFF6B5800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(6),
                  color: const Color(0xFF6B5800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Score: ${_scoreText(score)}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(
                'No tasks for this week.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: taskResultsBuilder(tasks),
            ),
      ],
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

  Future<void> _editGoal(
    BuildContext context,
    WeeklyGoalsViewModel goals,
  ) async {
    final existing = goals.goalsByWeek[week.key];
    final result = await showDialog<(String, int)>(
      context: context,
      builder: (_) => _GoalEditor(goal: existing),
    );
    if (result == null || !context.mounted) return;
    try {
      await goals.saveGoal(
        userUid: authViewModel.userUid,
        weekKey: week.key,
        title: result.$1,
        target: result.$2,
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save weekly goal: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<MapScreenViewModel>();
    final goals = context.watch<WeeklyGoalsViewModel>();
    final tasks = viewModel.tasks.where((task) {
      return (task.weekKey ?? weekKeyForCreatedDate(task.createdDate)) ==
          week.key;
    }).toList();
    final doneCount = tasks.where((task) => task.isDone).length;
    final goal = goals.goalsByWeek[week.key];

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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_dateLabel(week.start)} - ${_dateLabel(week.end)}, ${week.year}',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        goal?.title.isNotEmpty == true
                            ? '${goal!.title} · Target ${goal.target}'
                            : 'No weekly goal set',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _editGoal(context, goals),
                      child: Text(
                        goal == null ? 'Set goal' : 'Edit',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${tasks.length} tasks · $doneCount done · '
                        'Score ${_scoreText(weeklyGoalScore(tasks))}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
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
                      label: const Text('Add', style: TextStyle(fontSize: 14)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: tasks.isEmpty
                ? const Center(
                    child: Text(
                      'No tasks for this week.',
                      style: TextStyle(fontSize: 14),
                    ),
                  )
                : SingleChildScrollView(child: taskResultsBuilder(tasks)),
          ),
        ],
      ),
    );
  }
}

class _GoalEditor extends StatefulWidget {
  const _GoalEditor({this.goal});

  final WeeklyGoal? goal;

  @override
  State<_GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends State<_GoalEditor> {
  late final TextEditingController _title;
  late final TextEditingController _target;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.goal?.title ?? '');
    _target = TextEditingController(
      text: widget.goal == null || widget.goal!.target == 0
          ? ''
          : widget.goal!.target.toString(),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parsedTarget = int.tryParse(_target.text);
    final valid =
        _title.text.trim().isNotEmpty &&
        parsedTarget != null &&
        parsedTarget > 0;
    return AlertDialog(
      title: const Text('Weekly goal', style: TextStyle(fontSize: 14)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Goal title'),
            style: const TextStyle(fontSize: 14),
            onChanged: (_) => setState(() {}),
          ),
          TextField(
            controller: _target,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Task target'),
            style: const TextStyle(fontSize: 14),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: valid
              ? () => Navigator.pop(context, (_title.text.trim(), parsedTarget))
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Center(child: Text(text, style: const TextStyle(fontSize: 14)));
}

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
