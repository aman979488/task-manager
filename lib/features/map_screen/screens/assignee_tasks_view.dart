import 'package:flutter/material.dart';

import '../models/task.dart';
import '../utils/task_constants.dart';
import '../viewmodels/map_screen_viewmodel.dart';
import 'views/my_work_view.dart';
import 'views/task_completion_confirmation_dialog.dart';
import 'widgets/task_substeps_summary.dart';

class AssigneeTasksView extends StatefulWidget {
  final String assigneeName;
  final List<Task> tasks;
  final ValueChanged<Task> onOpenTask;
  final Future<void> Function(
    Task task, {
    bool confirmCompletion,
    bool keepInMyDay,
  })
  onToggleTaskDone;
  final Future<void> Function(Task task)? onAddSubstep;
  final Future<List<Task>> Function()? onAddTask;
  final Widget Function(List<Task> tasks)? taskResultsBuilder;

  const AssigneeTasksView({
    super.key,
    required this.assigneeName,
    required this.tasks,
    required this.onOpenTask,
    this.onToggleTaskDone = _defaultToggleTaskDone,
    this.onAddSubstep,
    this.onAddTask,
    this.taskResultsBuilder,
  });

  static Future<void> _defaultToggleTaskDone(
    Task task, {
    bool confirmCompletion = false,
    bool keepInMyDay = false,
  }) async {}

  static const Color primaryColor = Color(0xFFFBE64E);
  static const Color secondaryColor = Color(0xFF6B5800);

  @override
  State<AssigneeTasksView> createState() => _AssigneeTasksViewState();
}

class _AssigneeTasksViewState extends State<AssigneeTasksView> {
  late List<Task> _tasks;
  final Set<Task> _tasksBeingToggled = {};
  bool _isAddingTask = false;

  @override
  void initState() {
    super.initState();
    _tasks = List.of(widget.tasks);
  }

  @override
  void didUpdateWidget(covariant AssigneeTasksView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tasks != widget.tasks) {
      _tasks = List.of(widget.tasks);
    }
  }

  Future<void> _addTask() async {
    final addTask = widget.onAddTask;
    if (_isAddingTask || addTask == null) return;
    setState(() => _isAddingTask = true);
    try {
      final refreshedTasks = await addTask();
      if (mounted) setState(() => _tasks = refreshedTasks);
    } finally {
      if (mounted) setState(() => _isAddingTask = false);
    }
  }

  Future<void> _toggleTaskDone(Task task) async {
    if (!_tasksBeingToggled.add(task)) return;

    try {
      if (!task.isDone) {
        final confirmed = await showTaskCompletionConfirmation(
          context,
          task.title,
        );
        if (!confirmed || !mounted) return;
      }

      await widget.onToggleTaskDone(
        task,
        confirmCompletion: false,
        keepInMyDay: false,
      );
      if (mounted) setState(() {});
    } finally {
      _tasksBeingToggled.remove(task);
    }
  }

  Future<void> _addSubstep(Task task) async {
    final addSubstep = widget.onAddSubstep;
    if (addSubstep == null) return;
    await addSubstep(task);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _tasks.where((t) => t.isDone).length;
    final pendingCount = _tasks.length - completedCount;

    final pendingTasks = _tasks.where((t) => !t.isDone).toList();
    final completedTasks = _tasks.where((t) => t.isDone).toList();

    final sections = MapScreenViewModel.sectionsForWork(pendingTasks);
    if (completedTasks.isNotEmpty) {
      sections['Completed Tasks'] = completedTasks;
    }
    final sectionNames = [
      'Monthly Goals',
      'Weekly Goals',
      'Urgent Works',
      'Today Works',
      'Overdue Works',
      'IMP Works',
      'Tomorrow Works',
      'Later Works',
      'Day Later Works',
      'Process Works',
      'Hold Works',
      'Monitor Works',
      'Free Works',
      if (completedTasks.isNotEmpty) 'Completed Tasks',
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: BackButton(color: AssigneeTasksView.secondaryColor),
        iconTheme: const IconThemeData(color: AssigneeTasksView.secondaryColor),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.assigneeName,
              style: const TextStyle(
                color: AssigneeTasksView.secondaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              '$pendingCount Pending • $completedCount Done',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      body: MyWorkView(
        sections: sections,
        sectionNames: sectionNames,
        emptyMessage: 'No tasks assigned to this person.',
        taskResultsBuilder:
            widget.taskResultsBuilder ??
            (sectionTasks) => Column(
              children: [
                for (final task in sectionTasks)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Material(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => widget.onOpenTask(task),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                key: ValueKey(
                                  'assignee-task-toggle-${task.title}',
                                ),
                                onTap: () => _toggleTaskDone(task),
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    right: 10,
                                    top: 2,
                                  ),
                                  child: Icon(
                                    task.isDone
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    size: 24,
                                    color: task.isDone
                                        ? Colors.green
                                        : Colors.black54,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            task.title,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF26364A),
                                              decoration: task.isDone
                                                  ? TextDecoration.lineThrough
                                                  : TextDecoration.none,
                                            ),
                                          ),
                                        ),
                                        if (task.priority?.trim().isNotEmpty ==
                                            true) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AssigneeTasksView
                                                  .primaryColor
                                                  .withValues(alpha: 0.3),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              task.priority!.trim(),
                                              style: const TextStyle(
                                                color: AssigneeTasksView
                                                    .secondaryColor,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (task.note.trim().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          task.note.trim(),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blueGrey.shade500,
                                          ),
                                        ),
                                      ),
                                    if (task.steps.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: TaskSubstepsSummary(
                                          steps: task.steps,
                                          dense: true,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Add subtask',
                                visualDensity: VisualDensity.compact,
                                onPressed: widget.onAddSubstep == null
                                    ? null
                                    : () => _addSubstep(task),
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                  color: AssigneeTasksView.secondaryColor,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
      ),
      floatingActionButton: widget.onAddTask == null
          ? null
          : FloatingActionButton(
              tooltip: 'Add task for ${widget.assigneeName}',
              onPressed: _isAddingTask ? null : _addTask,
              backgroundColor: TaskConstants.primaryColor,
              child: _isAddingTask
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: TaskConstants.secondaryColor,
                      ),
                    )
                  : const Icon(Icons.add, color: TaskConstants.secondaryColor),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
