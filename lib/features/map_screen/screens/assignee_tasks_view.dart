import 'package:flutter/material.dart';

import '../models/task.dart';
import '../utils/task_constants.dart';
import '../viewmodels/map_screen_viewmodel.dart';
import 'views/my_work_view.dart';
import 'widgets/task_metadata_badges.dart';

class AssigneeTasksView extends StatefulWidget {
  final String assigneeName;
  final List<Task> tasks;
  final ValueChanged<Task> onOpenTask;
  final ValueChanged<Task> onToggleTaskDone;
  final Future<List<Task>> Function()? onAddTask;

  const AssigneeTasksView({
    super.key,
    required this.assigneeName,
    required this.tasks,
    required this.onOpenTask,
    this.onToggleTaskDone = _defaultToggleTaskDone,
    this.onAddTask,
  });

  static void _defaultToggleTaskDone(Task task) {}

  static const Color primaryColor = Color(0xFFFBE64E);
  static const Color secondaryColor = Color(0xFF6B5800);

  @override
  State<AssigneeTasksView> createState() => _AssigneeTasksViewState();
}

class _AssigneeTasksViewState extends State<AssigneeTasksView> {
  late List<Task> _tasks;
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
                fontSize: 16,
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
        taskResultsBuilder: (sectionTasks) => Column(
          children: [
            for (final task in sectionTasks)
              Material(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(
                    horizontal: -1,
                    vertical: -1,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: GestureDetector(
                    onTap: () => widget.onToggleTaskDone(task),
                    child: Icon(
                      task.isDone
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: task.isDone ? Colors.green : Colors.grey.shade500,
                    ),
                  ),
                  title: Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      decoration: task.isDone
                          ? TextDecoration.lineThrough
                          : null,
                      color: task.isDone ? Colors.grey : Colors.black87,
                    ),
                  ),
                  subtitle:
                      task.note.trim().isNotEmpty ||
                          task.assignee?.trim().isNotEmpty == true ||
                          task.clientName?.trim().isNotEmpty == true ||
                          task.workType?.trim().isNotEmpty == true
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (task.note.trim().isNotEmpty)
                              Text(
                                task.note.trim(),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            if (task.assignee?.trim().isNotEmpty == true ||
                                task.clientName?.trim().isNotEmpty == true ||
                                task.workType?.trim().isNotEmpty == true)
                              TaskMetadataBadges(task: task, compact: true),
                          ],
                        )
                      : null,
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: AssigneeTasksView.secondaryColor,
                  ),
                  onTap: () => widget.onOpenTask(task),
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
