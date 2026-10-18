import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/task.dart';
import '../viewmodels/map_screen_viewmodel.dart';
import 'views/my_work_view.dart';
import 'widgets/task_metadata_badges.dart';

class AssigneeTasksView extends StatelessWidget {
  final String assigneeName;
  final List<Task> tasks;

  const AssigneeTasksView({
    super.key,
    required this.assigneeName,
    required this.tasks,
  });

  static const Color primaryColor = Color(0xFFFBE64E);
  static const Color secondaryColor = Color(0xFF6B5800);

  @override
  Widget build(BuildContext context) {
    final completedCount = tasks.where((t) => t.isDone).length;
    final pendingCount = tasks.length - completedCount;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: secondaryColor),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              assigneeName,
              style: const TextStyle(
                color: secondaryColor,
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
        sections: MapScreenViewModel.sectionsForWork(tasks),
        emptyMessage: 'No pending tasks assigned to this person.',
        taskResultsBuilder: (sectionTasks) => Column(
          children: [
            for (final task in sectionTasks)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                tileColor: Colors.grey.shade50,
                leading: Icon(
                  task.isDone
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: task.isDone ? Colors.green : Colors.grey.shade500,
                ),
                title: Text(
                  task.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    decoration: task.isDone ? TextDecoration.lineThrough : null,
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
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
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
                  color: secondaryColor,
                ),
                onTap: () {
                  context.push('/task', extra: task);
                },
              ),
          ],
        ),
      ),
    );
  }
}
