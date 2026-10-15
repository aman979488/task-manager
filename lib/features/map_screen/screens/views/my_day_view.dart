import 'package:flutter/material.dart';

import '../../models/task.dart';

class MyDayView extends StatefulWidget {
  const MyDayView({
    super.key,
    required this.tasks,
    required this.suggestions,
    required this.taskBuilder,
    required this.suggestionBuilder,
    required this.onRefresh,
  });

  final List<Task> tasks;
  final List<Task> suggestions;
  final Widget Function(Task task, int index) taskBuilder;
  final Widget Function(Task task, VoidCallback onAdd) suggestionBuilder;
  final Future<void> Function() onRefresh;

  @override
  State<MyDayView> createState() => _MyDayViewState();
}

class _MyDayViewState extends State<MyDayView> {
  final Map<String, Task> _addedTasks = {};
  final Set<String> _addedInSuggestionsSheet = {};

  String _taskKey(Task task) =>
      task.id ?? '${task.title}\u0000${task.createdDate}';

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

  List<Task> get _dayTasks {
    final tasksByKey = <String, Task>{
      for (final task in _addedTasks.values)
        if (!task.isDone) _taskKey(task): task,
      for (final task in widget.tasks)
        if (!task.isDone) _taskKey(task): task,
    };
    return tasksByKey.values.toList();
  }

  List<Task> get _suggestions {
    final dayTaskKeys = _dayTasks.map(_taskKey).toSet();
    return widget.suggestions
        .where((task) => !task.isDone && !dayTaskKeys.contains(_taskKey(task)))
        .toList();
  }

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

    final groups = <String, List<Task>>{
      for (final date
          in datedGroups.keys.toList()..sort((a, b) => b.compareTo(a)))
        'From ${_dateLabel(date)}': datedGroups[date]!,
      if (earlier.isNotEmpty) 'From earlier': earlier,
      if (recent.isNotEmpty) 'Recently added': recent,
    };
    return groups;
  }

  Future<void> _showSuggestions(List<Task> suggestions) {
    _addedInSuggestionsSheet.clear();
    return showModalBottomSheet<void>(
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
        builder: (context, scrollController) {
          final groups = _suggestionGroups(suggestions);
          return Material(
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
                                '${suggestions.length - _addedInSuggestionsSheet.length}',
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
                        (task) =>
                            !_addedInSuggestionsSheet.contains(_taskKey(task)),
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
                                  (task) => !_addedInSuggestionsSheet.contains(
                                    _taskKey(task),
                                  ),
                                )
                                .toList();
                            final task = visibleTasks[index];
                            final key = _taskKey(task);
                            return widget.suggestionBuilder(task, () {
                              setState(() => _addedTasks[key] = task);
                              setSheetState(
                                () => _addedInSuggestionsSheet.add(key),
                              );
                            });
                          },
                          childCount: entry.value
                              .where(
                                (task) => !_addedInSuggestionsSheet.contains(
                                  _taskKey(task),
                                ),
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
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayTasks = _dayTasks;
    final suggestions = _suggestions;
    final today = MaterialLocalizations.of(context)
        .formatFullDate(DateTime.now());

    return Stack(
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'My Day',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      today,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: RefreshIndicator(
                onRefresh: widget.onRefresh,
                child: dayTasks.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.only(bottom: 76),
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: 220,
                            child: Center(
                              child: Text(
                                'No tasks planned for today yet.',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 76),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: dayTasks.length,
                        itemBuilder: (context, index) =>
                            widget.taskBuilder(dayTasks[index], index),
                      ),
              ),
            ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 16 + MediaQuery.paddingOf(context).bottom,
          child: Center(
            child: Material(
              color: const Color(0xFF526D8A),
              elevation: 6,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                onTap: suggestions.isEmpty
                    ? null
                    : () => _showSuggestions(suggestions),
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lightbulb_outline,
                        size: 19,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'Suggestions',
                        style: TextStyle(
                          color: suggestions.isEmpty
                              ? Colors.white60
                              : Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
