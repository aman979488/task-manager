import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/task.dart';

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
            Text(assigneeName, style: const TextStyle(color: secondaryColor, fontWeight: FontWeight.bold, fontSize: 18)),
            Text('$pendingCount Pending • $completedCount Done', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
      body: tasks.isEmpty
          ? const Center(
              child: Text('No tasks assigned to this person.', style: TextStyle(color: Colors.grey)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
              itemBuilder: (context, index) {
                final task = tasks[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  tileColor: Colors.grey.shade50,
                  leading: Icon(
                    task.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
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
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (task.workType != null && task.workType!.isNotEmpty)
                        Text('Work Type: ${task.workType}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      if (task.priority != null && task.priority!.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Priority: ${task.priority}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: secondaryColor)),
                        ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: secondaryColor),
                  onTap: () {
                    context.push('/task', extra: task);
                  },
                );
              },
            ),
    );
  }
}
