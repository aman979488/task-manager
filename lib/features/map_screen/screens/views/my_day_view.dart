import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/task.dart';

class MyDayView extends StatefulWidget {
  const MyDayView({
    super.key,
    required this.tasks,
    required this.suggestions,
    required this.taskBuilder,
    required this.calendarViewType,
    required this.selectedDate,
    required this.onDateChanged,
    required this.onTaskTap,
    required this.suggestionBuilder,
    required this.onAddToMyDay,
    required this.onRefresh,
  });

  final List<Task> tasks;
  final List<Task> suggestions;
  final Widget Function(Task task, int index) taskBuilder;
  final String calendarViewType;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<Task> onTaskTap;
  final Widget Function(Task task, VoidCallback onAdd) suggestionBuilder;
  final Future<void> Function(Task task) onAddToMyDay;
  final Future<void> Function() onRefresh;

  @override
  State<MyDayView> createState() => _MyDayViewState();
}

class _MyDayViewState extends State<MyDayView> {
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

  List<Task> get _dayTasks => widget.tasks;

  DateTime? _scheduledDate(Task task) {
    final parsed = DateTime.tryParse(task.deadline ?? task.reminder ?? '');
    if (parsed != null) return DateTime(parsed.year, parsed.month, parsed.day);
    if (task.priority?.trim().toLowerCase() == 'today' || task.isInMyDay) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day);
    }
    return null;
  }

  List<Task> _calendarTasks() {
    final selected = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
    );
    final start = switch (widget.calendarViewType) {
      'Week' => selected.subtract(Duration(days: selected.weekday - 1)),
      'Month' => DateTime(selected.year, selected.month),
      _ => selected,
    };
    final end = switch (widget.calendarViewType) {
      '3 Day' => start.add(const Duration(days: 2)),
      'Week' => start.add(const Duration(days: 6)),
      'Month' => DateTime(selected.year, selected.month + 1, 0),
      _ => start,
    };
    final tasksByKey = <String, Task>{
      for (final task in _dayTasks) _taskKey(task): task,
      for (final task in widget.suggestions) _taskKey(task): task,
    };
    return tasksByKey.values.where((task) {
      final date = _scheduledDate(task);
      return date != null && !date.isBefore(start) && !date.isAfter(end);
    }).toList();
  }

  int? _minutesForTime(String? value) {
    if (value == null) return null;
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?:\s*(AM|PM))?$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) return null;

    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final meridiem = match.group(3)?.toUpperCase();
    if (hour > 23 || minute > 59) return null;
    if (meridiem != null) {
      if (hour < 1 || hour > 12) return null;
      hour %= 12;
      if (meridiem == 'PM') hour += 12;
    }
    return hour * 60 + minute;
  }

  int _taskStartMinutes(Task task) {
    final explicitTime = _minutesForTime(task.startTime);
    if (explicitTime != null) return explicitTime;
    final date = DateTime.tryParse(task.deadline ?? task.reminder ?? '');
    if (date != null && (date.hour != 0 || date.minute != 0)) {
      return date.hour * 60 + date.minute;
    }
    return 9 * 60;
  }

  int _taskDurationMinutes(Task task, int startMinutes) {
    final endMinutes = _minutesForTime(task.endTime);
    if (endMinutes == null || endMinutes <= startMinutes) return 60;
    return endMinutes - startMinutes;
  }

  Widget _buildHourlyCalendar(BuildContext context, {required int dayCount}) {
    const timeColumnWidth = 48.0;
    const hourHeight = 64.0;
    const hoursInDay = 24;
    final selectedDay = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
    );
    final firstDay = widget.calendarViewType == 'Week'
        ? selectedDay.subtract(Duration(days: selectedDay.weekday - 1))
        : selectedDay;
    final days = List.generate(
      dayCount,
      (index) => firstDay.add(Duration(days: index)),
    );
    final tasksByKey = <String, Task>{
      for (final task in _dayTasks) _taskKey(task): task,
      for (final task in widget.suggestions) _taskKey(task): task,
    };
    final tasksByDay = List.generate(
      days.length,
      (dayIndex) => tasksByKey.values.where((task) {
        final date = _scheduledDate(task);
        return date != null &&
            date.year == days[dayIndex].year &&
            date.month == days[dayIndex].month &&
            date.day == days[dayIndex].day;
      }).toList(),
    );

    return Column(
      children: [
        SizedBox(
          height: 52,
          child: Row(
            children: [
              const SizedBox(width: timeColumnWidth),
              for (final day in days)
                Expanded(
                  child: InkWell(
                    onTap: () => widget.onDateChanged(day),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          MaterialLocalizations.of(context)
                              .narrowWeekdays[day.weekday % 7],
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color:
                                day.year == DateTime.now().year &&
                                    day.month == DateTime.now().month &&
                                    day.day == DateTime.now().day
                                ? const Color(0xFF526D8A)
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final dayWidth =
                    (constraints.maxWidth - timeColumnWidth) / days.length;
                final events = <Widget>[];
                for (var dayIndex = 0; dayIndex < days.length; dayIndex++) {
                  for (final task in tasksByDay[dayIndex]) {
                    final startMinutes = _taskStartMinutes(task);
                    final durationMinutes = _taskDurationMinutes(
                      task,
                      startMinutes,
                    );
                    final visibleStart = startMinutes.clamp(0, 24 * 60 - 1);
                    final visibleEnd = (startMinutes + durationMinutes).clamp(
                      visibleStart + 30,
                      24 * 60,
                    );
                    final top = visibleStart / 60 * hourHeight;
                    final eventHeight =
                        (visibleEnd - visibleStart) / 60 * hourHeight;
                    events.add(
                      Positioned(
                        left: timeColumnWidth + dayIndex * dayWidth + 2,
                        top: top,
                        width: dayWidth - 4,
                        height: eventHeight
                            .clamp(34, 24 * hourHeight)
                            .toDouble(),
                        child: Material(
                          color: const Color(0xFFE8F0F8),
                          borderRadius: BorderRadius.circular(5),
                          child: InkWell(
                            onTap: () => widget.onTaskTap(task),
                            borderRadius: BorderRadius.circular(5),
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: Text(
                                task.title,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF26364A),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                }

                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: hoursInDay * hourHeight,
                    child: Stack(
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: timeColumnWidth,
                              child: Column(
                                children: [
                                  for (var hour = 0; hour < hoursInDay; hour++)
                                    SizedBox(
                                      height: hourHeight,
                                      child: Align(
                                        alignment: Alignment.topCenter,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: Text(
                                            '${hour.toString().padLeft(2, '0')}:00',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            for (
                              var dayIndex = 0;
                              dayIndex < days.length;
                              dayIndex++
                            )
                              Expanded(
                                child: Column(
                                  children: [
                                    for (
                                      var hour = 0;
                                      hour < hoursInDay;
                                      hour++
                                    )
                                      Container(
                                        height: hourHeight,
                                        decoration: BoxDecoration(
                                          border: Border(
                                            top: BorderSide(
                                              color: Colors.grey.shade200,
                                            ),
                                            left: BorderSide(
                                              color: Colors.grey.shade200,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        ...events,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _moveCalendar(int direction) {
    final step = switch (widget.calendarViewType) {
      '3 Day' => 3,
      'Week' => 7,
      'Month' => 0,
      _ => 1,
    };
    if (widget.calendarViewType == 'Month') {
      widget.onDateChanged(
        DateTime(
          widget.selectedDate.year,
          widget.selectedDate.month + direction,
          1,
        ),
      );
    } else {
      widget.onDateChanged(
        widget.selectedDate.add(Duration(days: step * direction)),
      );
    }
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
                                    fontSize: 16,
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
                              fontSize: 16,
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
                              unawaited(widget.onAddToMyDay(task));
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
    final isCalendarView = const {
      'Calendar',
      'Day',
      '3 Day',
      'Week',
      'Month',
    }.contains(widget.calendarViewType);
    final calendarTasks = isCalendarView ? _calendarTasks() : dayTasks;
    final selectedDateLabel = widget.calendarViewType == 'Week'
        ? '${MaterialLocalizations.of(context).formatMediumDate(widget.selectedDate.subtract(Duration(days: widget.selectedDate.weekday - 1)))} - '
              '${MaterialLocalizations.of(context).formatMediumDate(widget.selectedDate.add(Duration(days: 7 - widget.selectedDate.weekday)))}'
        : widget.calendarViewType == '3 Day'
        ? '${MaterialLocalizations.of(context).formatMediumDate(widget.selectedDate)} - '
              '${MaterialLocalizations.of(context).formatMediumDate(widget.selectedDate.add(const Duration(days: 2)))}'
        : MaterialLocalizations.of(context).formatFullDate(widget.selectedDate);

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
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!isCalendarView)
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
            if (isCalendarView)
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Previous ${widget.calendarViewType}',
                          onPressed: () => _moveCalendar(-1),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Text(
                            selectedDateLabel,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Next ${widget.calendarViewType}',
                          onPressed: () => _moveCalendar(1),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
                  if (widget.calendarViewType == 'Month' ||
                      widget.calendarViewType == 'Calendar')
                    CalendarDatePicker(
                      initialDate: widget.selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      onDateChanged: widget.onDateChanged,
                    )
                  else if (widget.calendarViewType == 'Week')
                    SizedBox(
                      height: 58,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: 7,
                        itemBuilder: (context, index) {
                          final firstDay = widget.calendarViewType == 'Week'
                              ? widget.selectedDate.subtract(
                                  Duration(
                                    days: widget.selectedDate.weekday - 1,
                                  ),
                                )
                              : widget.selectedDate;
                          final date = firstDay.add(Duration(days: index));
                          return TextButton(
                            onPressed: () => widget.onDateChanged(date),
                            child: Text(
                              MaterialLocalizations.of(context)
                                  .formatShortDate(date),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            Expanded(
              child:
                  widget.calendarViewType == '3 Day' ||
                      widget.calendarViewType == 'Week'
                  ? _buildHourlyCalendar(
                      context,
                      dayCount: widget.calendarViewType == 'Week' ? 7 : 3,
                    )
                  : RefreshIndicator(
                      onRefresh: widget.onRefresh,
                      child: calendarTasks.isEmpty
                          ? ListView(
                              padding: const EdgeInsets.only(bottom: 76),
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height: 220,
                                  child: Center(
                                    child: Text(
                                      isCalendarView
                                          ? 'No tasks scheduled for this period.'
                                          : 'No tasks planned for today yet.',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 76),
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: calendarTasks.length,
                              itemBuilder: (context, index) => widget
                                  .taskBuilder(calendarTasks[index], index),
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
                          fontSize: 14,
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
