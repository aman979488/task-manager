import 'package:flutter/material.dart';

import '../../models/task.dart';

class DoneTasksView extends StatelessWidget {
  const DoneTasksView({
    super.key,
    required this.tasks,
    required this.viewType,
    required this.calendarBuilder,
    required this.refreshable,
    required this.onEditTaskTime,
  });

  final List<Task> tasks;
  final String viewType;
  final Widget Function(List<Task> tasks) calendarBuilder;
  final Widget Function(Widget child) refreshable;
  final Future<void> Function(Task task) onEditTaskTime;

  DateTime? _createdDate(Task task) {
    final dateText = task.createdDate.split(' • ').first;
    final parts = dateText.split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  int? _minutes(String? value) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?:\s*(AM|PM))?$',
      caseSensitive: false,
    ).firstMatch(value?.trim() ?? '');
    if (match == null) return null;
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final meridiem = match.group(3)?.toUpperCase();
    if (minute > 59 || hour > 23) return null;
    if (meridiem != null) {
      if (hour < 1 || hour > 12) return null;
      hour %= 12;
      if (meridiem == 'PM') hour += 12;
    }
    return hour * 60 + minute;
  }

  int? _workedMinutes(Task task) {
    final start = _minutes(task.startTime);
    final end = _minutes(task.endTime);
    if (start == null || end == null) return null;
    return (end > start ? end : end + 24 * 60) - start;
  }

  String _timeLabel(String? value) =>
      value?.trim().isNotEmpty == true ? value!.trim() : '—';

  String _workedHours(Task task) {
    final minutes = _workedMinutes(task);
    if (minutes == null) return '—';
    return '${(minutes / 60).toStringAsFixed(2)} hr';
  }

  String _clientLabel(Task task) {
    final workType = task.workType?.trim() ?? '';
    final client = task.clientName?.trim() ?? '';
    if (client.isEmpty) return workType;
    return workType.isEmpty ? client : '$workType ($client)';
  }

  Color _priorityColor(String? priority) {
    switch (priority?.trim().toLowerCase()) {
      case 'u1':
      case 'u2':
      case 'u3':
      case 'urgent':
        return const Color(0xFF9B5965);
      case 'imp':
        return const Color(0xFF526D8A);
      case 'today':
      case 'tomorrow':
        return const Color(0xFF557E9B);
      case 'hold':
        return const Color(0xFF99765B);
      case 'process':
        return const Color(0xFF667F89);
      default:
        return const Color(0xFF71808D);
    }
  }

  String _dateLabel(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _taskRow(Task task) {
    final client = _clientLabel(task);
    final priority = task.priority?.trim();
    final priorityColor = _priorityColor(priority);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.check_circle, size: 21, color: Colors.green.shade600),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey.shade800,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(45, 0, 14, 8),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(
                      '${_timeLabel(task.startTime)} - ${_timeLabel(task.endTime)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                    if (client.isNotEmpty)
                      Text(
                        client,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.08),
                  border: Border.all(
                    color: priorityColor.withValues(alpha: 0.35),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      priority?.isNotEmpty == true ? priority! : 'None',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: priorityColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Edit task time',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                onPressed: () => onEditTaskTime(task),
                icon: const Icon(
                  Icons.timer_outlined,
                  size: 17,
                  color: Color(0xFF526D8A),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, indent: 14, endIndent: 14),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (viewType == 'Calendar') return calendarBuilder(tasks);
    if (tasks.isEmpty) {
      return refreshable(
        ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(
              height: 240,
              child: Center(child: Text('No tasks found in this category.')),
            ),
          ],
        ),
      );
    }

    final groups = <DateTime?, List<Task>>{};
    for (final task in tasks) {
      groups.putIfAbsent(_createdDate(task), () => []).add(task);
    }
    final dates = groups.keys.toList()
      ..sort((a, b) {
        if (a == null) return 1;
        if (b == null) return -1;
        return b.compareTo(a);
      });
    return refreshable(
      ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          for (final date in dates) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Text(
                date == null ? 'Date not set' : _dateLabel(date),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.blueGrey,
                ),
              ),
            ),
            for (final task in groups[date]!) _taskRow(task),
          ],
        ],
      ),
    );
  }
}
