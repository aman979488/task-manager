import 'package:flutter/material.dart';

import '../../models/task.dart';

class GroupByView extends StatelessWidget {
  const GroupByView({
    super.key,
    required this.groups,
    required this.groupBy,
    required this.onOpenAssignee,
    required this.onOpenTask,
    required this.refreshable,
  });

  final Map<String, List<Task>> groups;
  final String groupBy;
  final void Function(String name, List<Task> tasks) onOpenAssignee;
  final ValueChanged<Task> onOpenTask;
  final Widget Function(Widget child) refreshable;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return refreshable(
        ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(
              height: 240,
              child: Center(
                child: Text(
                  'No tasks to group.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final names = groups.keys.toList()..sort();
    return refreshable(
      ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: names.length,
        itemBuilder: (context, index) {
          final name = names[index];
          final tasks = groups[name]!;
          final completedCount = tasks.where((task) => task.isDone).length;
          final pendingCount = tasks.length - completedCount;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFFBE64E).withValues(alpha: 0.3),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B5800),
                  ),
                ),
              ),
              title: Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
              subtitle: Text(
                'Total: ${tasks.length} • Pending: $pendingCount • Done: $completedCount',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              children: [
                if (groupBy == 'Assignee')
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => onOpenAssignee(name, tasks),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Open assignee task view'),
                    ),
                  ),
                ...tasks.map(
                  (task) => ListTile(
                    dense: true,
                    leading: Icon(
                      task.isDone
                          ? Icons.check_circle_outline
                          : Icons.radio_button_unchecked,
                      color: task.isDone ? Colors.green : Colors.grey,
                    ),
                    title: Text(task.title),
                    onTap: () => onOpenTask(task),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
