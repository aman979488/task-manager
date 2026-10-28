import 'package:flutter/material.dart';

import '../../models/task.dart';

class DoneTasksView extends StatelessWidget {
  const DoneTasksView({
    super.key,
    required this.tasks,
    required this.viewType,
    required this.calendarBuilder,
    required this.refreshable,
    this.onEditTaskTime,
    this.onOpenTask,
  });

  final List<Task> tasks;
  final String viewType;
  final Widget Function(List<Task> tasks) calendarBuilder;
  final Widget Function(Widget child) refreshable;
  final Future<void> Function(Task task)? onEditTaskTime;
  final ValueChanged<Task>? onOpenTask;

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
    if (value == null || value.trim().isEmpty) return null;
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?:\s*(AM|PM))?$',
      caseSensitive: false,
    ).firstMatch(value.trim());
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

  // Manual time (timer icon se set kiya hua) ho toh wahi use hota hai,
  // warna task banne ke time se done tick hone ke time tak automatic.
  bool _hasManualTime(Task task) =>
      _minutes(task.startTime) != null && _minutes(task.endTime) != null;

  DateTime? _createdDateTime(Task task) {
    final date = _createdDate(task);
    if (date == null) return null;
    final parts = task.createdDate.split(' • ');
    var hour = 0;
    var minute = 0;
    if (parts.length > 1) {
      final time = parts[1].trim().split(':');
      hour = int.tryParse(time.first) ?? 0;
      minute = time.length > 1 ? int.tryParse(time[1]) ?? 0 : 0;
    }
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  DateTime? _completedDateTime(Task task) {
    final ms = task.completedAt;
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  String _clock(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${hour.toString().padLeft(2, '0')}:$minute'
        '${dt.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _compactTime(String? value) {
    final text = value?.replaceAll(RegExp(r'\s+'), '') ?? '';
    return text.isEmpty ? '—' : text;
  }

  String _startLabel(Task task) {
    if (_hasManualTime(task)) return _compactTime(task.startTime);
    final created = _createdDateTime(task);
    return created == null ? '—' : _clock(created);
  }

  String _endLabel(Task task) {
    if (_hasManualTime(task)) return _compactTime(task.endTime);
    final done = _completedDateTime(task);
    return done == null ? '—' : _clock(done);
  }

  int _workedMinutes(Task task) {
    if (!_hasManualTime(task)) {
      final start = _createdDateTime(task);
      final end = _completedDateTime(task);
      if (start == null || end == null) return 0;
      final diff = end.difference(start).inMinutes;
      return diff < 0 ? 0 : diff;
    }
    final start = _minutes(task.startTime)!;
    final end = _minutes(task.endTime)!;
    if (end >= start) return end - start;
    return (end + 24 * 60) - start;
  }

  double _taskHours(Task task) {
    final mins = _workedMinutes(task);
    return double.parse((mins / 60.0).toStringAsFixed(2));
  }

  double _taskScore(Task task) {
    final hours = _taskHours(task);
    return double.parse((hours * 4.0).toStringAsFixed(2));
  }

  String _formatDuration(double hours) {
    if (hours == 0) return '0';
    return hours.toStringAsFixed(2);
  }

  String _formatScore(double score) {
    if (score == score.roundToDouble()) {
      return score.toInt().toString();
    }
    return score.toStringAsFixed(2);
  }

  // Done hone ki date aur task banne ki date ka farak (din mein).
  // Done time na ho toh deadline aur created date ka farak.
  int _daysDiff(Task task) {
    final created = _createdDate(task);
    if (created == null) return 0;
    final done = _completedDateTime(task);
    if (done != null) {
      return DateTime(
        done.year,
        done.month,
        done.day,
      ).difference(created).inDays;
    }
    final parsed = DateTime.tryParse(task.deadline ?? '');
    if (parsed == null) return 0;
    return DateTime(
      parsed.year,
      parsed.month,
      parsed.day,
    ).difference(created).inDays;
  }

  // 10:00AM-10:10AM_0.17Hr_0 Days_Personal  (last mein client name)
  String _timeLine(Task task) {
    final client = task.clientName?.trim() ?? '';
    return '${_startLabel(task)}-${_endLabel(task)}'
        '_${_formatDuration(_taskHours(task))}Hr'
        '_${_daysDiff(task)} Days'
        '${client.isEmpty ? '' : '_$client'}';
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

  String _dateHeaderLabel(DateTime date, double totalHours, double totalScore) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekday = weekdays[date.weekday - 1];
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');

    final durStr = '${_formatDuration(totalHours)}Hr';
    final scoStr = _formatScore(totalScore);

    return '$y $m $d ${weekday}_Dur-${durStr}_Sco-$scoStr';
  }

  Widget _taskRow(Task task) {
    final priority = task.priority?.trim();
    final priorityColor = _priorityColor(priority);

    return Column(
      children: [
        // Task row: check icon + title, aur right side mein priority + timer badge
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
          child: Row(
            children: [
              Icon(Icons.check_circle, size: 22, color: Colors.green.shade600),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: onOpenTask == null ? null : () => onOpenTask!(task),
                  child: Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blueGrey.shade800,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: Colors.blueGrey.shade400,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.08),
                  border: Border.all(
                    color: priorityColor.withValues(alpha: 0.35),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  priority?.isNotEmpty == true ? priority! : 'None',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: priorityColor,
                  ),
                ),
              ),
              if (onEditTaskTime != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Edit task time',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () => onEditTaskTime!(task),
                  icon: const Icon(
                    Icons.timer_outlined,
                    size: 17,
                    color: Color(0xFF526D8A),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Time line: date header ke same left edge se start (14)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _timeLine(task),
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ),
        ),
        const Divider(height: 1, indent: 14, endIndent: 14),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (viewType == 'Calendar') {
      return calendarBuilder(tasks);
    }
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

    // Har task apni alag date header ke saath (grouping nahi)
    final entries =
        [
          for (var i = 0; i < tasks.length; i++)
            (index: i, task: tasks[i], date: _createdDate(tasks[i])),
        ]..sort((a, b) {
          if (a.date == null && b.date == null) {
            return a.index.compareTo(b.index);
          }
          if (a.date == null) {
            return 1;
          }
          if (b.date == null) {
            return -1;
          }
          final byDate = b.date!.compareTo(a.date!);
          return byDate != 0 ? byDate : a.index.compareTo(b.index);
        });

    return refreshable(
      ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          for (final entry in entries) ...[
            _dateHeader(entry.task, entry.date),
            _taskRow(entry.task),
          ],
        ],
      ),
    );
  }

  Widget _dateHeader(Task task, DateTime? date) {
    final headerText = date == null
        ? 'Date not set'
        : _dateHeaderLabel(date, _taskHours(task), _taskScore(task));

    return Container(
      width: double.infinity,
      color: const Color(0xFFF1F2F4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      child: Text(
        headerText,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF265492),
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}