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
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            labelColor: _brand,
            unselectedLabelColor: Colors.black54,
            indicatorColor: _brand,
            indicatorWeight: 3,
            dividerColor: Colors.grey.shade200,
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
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
        _MonthSwitcher(
          month: _month,
          onPrevious: () =>
              setState(() => _month = DateTime(_month.year, _month.month - 1)),
          onNext: () =>
              setState(() => _month = DateTime(_month.year, _month.month + 1)),
          chips: [
            '${monthlyTasks.length} goals',
            '$doneCount done',
            'Score ${_scoreText(weeklyGoalScore(monthlyTasks))}',
          ],
        ),
        if (monthlyTasks.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.flag_outlined,
                    size: 40,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No monthly goals marked yet.',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              children: [widget.taskResultsBuilder(monthlyTasks)],
            ),
          ),
      ],
    );
  }
}

class _WeeklyGoalsViewState extends State<_WeeklyGoalsView> {
  late DateTime _month;
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
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
        _MonthSwitcher(
          month: _month,
          onPrevious: () =>
              setState(() => _month = DateTime(_month.year, _month.month - 1)),
          onNext: () =>
              setState(() => _month = DateTime(_month.year, _month.month + 1)),
          chips: ['$monthTaskCount tasks'],
        ),
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
            itemCount: weeks.length,
            itemBuilder: (context, index) {
              final week = weeks[index];
              final tasks = _tasksForWeek(week.key);
              final doneCount = tasks.where((task) => task.isDone).length;
              final goal = goals.goalsByWeek[week.key];
              final expanded = _expanded.contains(week.key);
              return _WeekTile(
                week: week,
                goal: goal,
                tasks: tasks,
                taskResultsBuilder: widget.taskResultsBuilder,
                isCurrent: week.key == currentWeek,
                expanded: expanded,
                onExpand: () => setState(() {
                  if (expanded) {
                    _expanded.remove(week.key);
                  } else {
                    _expanded.add(week.key);
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

class _MonthSwitcher extends StatelessWidget {
  const _MonthSwitcher({
    required this.month,
    required this.onPrevious,
    required this.onNext,
    required this.chips,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final List<String> chips;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${_monthName(month.month)} ${month.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [for (final text in chips) _InfoChip(text)],
          ),
        ],
      ),
    );
  }
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
                        TextButton.icon(
                          onPressed: onAddTask,
                          style: TextButton.styleFrom(
                            foregroundColor: _brand,
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 32),
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text(
                            'Add task',
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
    final hasGoal = goal?.title.isNotEmpty == true;

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
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasGoal ? goal!.title : 'No weekly goal set',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: hasGoal
                                    ? Colors.black87
                                    : Colors.grey.shade600,
                              ),
                            ),
                            if (hasGoal)
                              Text(
                                'Target ${goal!.target}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
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
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
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
      title: const Text(
        'Weekly goal',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Goal title',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 14),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _target,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Task target',
              border: OutlineInputBorder(),
              isDense: true,
            ),
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
  Widget build(BuildContext context) => Center(
    child: Text(
      text,
      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
    ),
  );
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
