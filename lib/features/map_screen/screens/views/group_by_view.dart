import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../widgets/task_metadata_badges.dart';

class GroupByView extends StatelessWidget {
  const GroupByView({
    super.key,
    required this.groups,
    required this.groupBy,
    required this.pageStorageId,
    required this.onOpenAssignee,
    required this.onOpenTask,
    required this.refreshable,
    this.openAssigneeOnTap = false,
  });

  final Map<String, List<Task>> groups;
  final String groupBy;
  final String pageStorageId;
  final void Function(String name, List<Task> tasks) onOpenAssignee;
  final ValueChanged<Task> onOpenTask;
  final Widget Function(Widget child) refreshable;
  final bool openAssigneeOnTap;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return refreshable(
        ListView(
          key: PageStorageKey('$pageStorageId-list'),
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
        key: PageStorageKey('$pageStorageId-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 100),
        itemCount: names.length,
        itemBuilder: (context, index) {
          final name = names[index];
          final tasks = groups[name]!;
          final completedCount = tasks.where((task) => task.isDone).length;
          final pendingCount = tasks.length - completedCount;
          final cardContents = openAssigneeOnTap && groupBy == 'Assignee'
              ? ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFFFBE64E)
                        .withValues(alpha: 0.3),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B5800),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    'Total: ${tasks.length} • Pending: $pendingCount • Done: $completedCount',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => onOpenAssignee(name, tasks),
                )
              : ExpansionTile(
                  key: PageStorageKey('$pageStorageId-group-$name'),
                  dense: true,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                  childrenPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFFFBE64E)
                        .withValues(alpha: 0.3),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B5800),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    'Total: ${tasks.length} • Pending: $pendingCount • Done: $completedCount',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                  trailing: groupBy == 'Assignee'
                      ? const Icon(Icons.chevron_right_rounded)
                      : null,
                  children: [
                    if (groupBy == 'Assignee')
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => onOpenAssignee(name, tasks),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text(
                            'Open assignee task view',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ...tasks.map(
                      (task) => ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        leading: Icon(
                          task.isDone
                              ? Icons.check_circle_outline
                              : Icons.radio_button_unchecked,
                          color: task.isDone ? Colors.green : Colors.grey,
                        ),
                        title: Text(
                          task.title,
                          style: const TextStyle(fontSize: 12),
                        ),
                        subtitle:
                            task.assignee?.trim().isNotEmpty == true ||
                                task.clientName?.trim().isNotEmpty == true ||
                                task.workType?.trim().isNotEmpty == true
                            ? TaskMetadataBadges(task: task, compact: true)
                            : null,
                        onTap: () => onOpenTask(task),
                      ),
                    ),
                  ],
                );
          return Container(
            margin: const EdgeInsets.only(bottom: 4),
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
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: cardContents,
            ),
          );
        },
      ),
    );
  }
}
