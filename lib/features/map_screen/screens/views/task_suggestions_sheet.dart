import 'package:flutter/material.dart';

import '../../models/task.dart';

class TaskSuggestionsSheet {
  static Future<void> show({
    required BuildContext context,
    required List<Task> suggestions,
    required Widget Function(Task task, VoidCallback onAdd) suggestionBuilder,
    required Future<void> Function(Task task) onAddTask,
    required ValueChanged<Object> onError,
  }) async {
    final addedTaskKeys = <String>{};
    final groups = _suggestionGroups(suggestions);

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.48,
        minChildSize: 0.38,
        maxChildSize: 0.94,
        snap: true,
        snapSizes: const [0.48, 0.94],
        expand: false,
        builder: (context, scrollController) => Material(
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: StatefulBuilder(
            builder: (context, setSheetState) => CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: 9),
                      Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: 'Close suggestions',
                              onPressed: () =>
                                  Navigator.of(sheetContext).pop(),
                              icon: const Icon(Icons.close),
                            ),
                            const Expanded(
                              child: Text(
                                'Suggestions',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${suggestions.length - addedTaskKeys.length}',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                  ),
                ),
                if (groups.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('No suggestions available.')),
                  )
                else
                  for (final entry in groups.entries.where(
                    (entry) => entry.value.any(
                      (task) => !addedTaskKeys.contains(_taskKey(task)),
                    ),
                  )) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 16, 4),
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final visibleTasks = entry.value
                              .where(
                                (task) =>
                                    !addedTaskKeys.contains(_taskKey(task)),
                              )
                              .toList();
                          final task = visibleTasks[index];
                          final key = _taskKey(task);
                          return suggestionBuilder(task, () async {
                            try {
                              await onAddTask(task);
                              if (!sheetContext.mounted) return;
                              setSheetState(() => addedTaskKeys.add(key));
                            } catch (error) {
                              onError(error);
                            }
                          });
                        },
                        childCount: entry.value
                            .where(
                              (task) =>
                                  !addedTaskKeys.contains(_taskKey(task)),
                            )
                            .length,
                      ),
                    ),
                  ],
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.paddingOf(context).bottom + 24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _taskKey(Task task) => task.id ?? '${task.title}\u0000${task.createdDate}';

DateTime? _createdAt(Task task) {
  final parts = task.createdDate.split(' • ');
  if (parts.isEmpty) return null;
  final dateParts = parts.first.split('/');
  if (dateParts.length != 3) return null;
  final day = int.tryParse(dateParts[0]);
  final month = int.tryParse(dateParts[1]);
  final year = int.tryParse(dateParts[2]);
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}

Map<String, List<Task>> _suggestionGroups(List<Task> suggestions) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final recentCutoff = today.subtract(const Duration(days: 6));
  final datedGroups = <DateTime, List<Task>>{};
  final earlier = <Task>[];
  final recent = <Task>[];

  for (final task in suggestions) {
    final createdAt = _createdAt(task);
    if (createdAt == null || !createdAt.isBefore(today)) {
      recent.add(task);
    } else if (!createdAt.isBefore(recentCutoff)) {
      final date = DateTime(createdAt.year, createdAt.month, createdAt.day);
      datedGroups.putIfAbsent(date, () => []).add(task);
    } else {
      earlier.add(task);
    }
  }

  return {
    for (final date in datedGroups.keys.toList()..sort((a, b) => b.compareTo(a)))
      'From ${_dateLabel(date)}': datedGroups[date]!,
    if (earlier.isNotEmpty) 'From earlier': earlier,
    if (recent.isNotEmpty) 'Recently added': recent,
  };
}

String _dateLabel(DateTime date) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${weekdays[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
}
