import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../utils/task_priority_color.dart';
import 'daily_report_sheet.dart';

typedef _GroupedDoneDate = ({
  DateTime? date,
  List<Task> tasks,
  double totalHours,
  double totalScore,
});

class DoneTasksView extends StatefulWidget {
  const DoneTasksView({
    super.key,
    required this.tasks,
    required this.viewType,
    required this.calendarBuilder,
    required this.refreshable,
    this.onEditTaskTime,
    this.onOpenTask,
    this.onMarkUndone,
  });

  final List<Task> tasks;
  final String viewType;
  final Widget Function(List<Task> tasks) calendarBuilder;
  final Widget Function(Widget child) refreshable;
  final Future<void> Function(Task task)? onEditTaskTime;
  final ValueChanged<Task>? onOpenTask;
  final Future<void> Function(Task task)? onMarkUndone;

  @override
  State<DoneTasksView> createState() => _DoneTasksViewState();
}

class _DoneTasksViewState extends State<DoneTasksView>
    with AutomaticKeepAliveClientMixin<DoneTasksView> {
  final Set<String> _expandedDates = {};
  Timer? _blankTapTimer;
  int _blankTapCount = 0;

  @override
  bool get wantKeepAlive => true;

  String _dateKey(DateTime? date) => date?.toIso8601String() ?? 'unknown';

  @override
  void dispose() {
    _blankTapTimer?.cancel();
    super.dispose();
  }

  void _handleBlankTap(List<String> dateKeys) {
    _blankTapCount++;
    _blankTapTimer?.cancel();
    _blankTapTimer = Timer(const Duration(milliseconds: 350), () {
      final tapCount = _blankTapCount;
      _blankTapCount = 0;
      if (!mounted || dateKeys.isEmpty || tapCount < 2) return;

      final targetKeys = dateKeys.take(tapCount >= 3 ? 2 : 1).toList();
      final allExpanded = targetKeys.every(_expandedDates.contains);
      setState(() {
        if (allExpanded) {
          _expandedDates.removeAll(targetKeys);
        } else {
          _expandedDates.addAll(targetKeys);
        }
      });
    });
  }

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
    final minutesSinceMidnight = parts.length > 1
        ? _minutes(parts[1].trim()) ?? 0
        : 0;
    return DateTime(
      date.year,
      date.month,
      date.day,
      minutesSinceMidnight ~/ 60,
      minutesSinceMidnight % 60,
    );
  }

  DateTime? _completedDateTime(Task task) {
    final ms = task.completedAt;
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  DateTime? _completionDate(Task task) {
    final completed = _completedDateTime(task);
    if (completed != null) {
      return DateTime(completed.year, completed.month, completed.day);
    }
    return _createdDate(task);
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

  String _weekday(DateTime date) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];

  String _dateText(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-${date.year}';

  Future<void> _confirmMarkUndone(BuildContext context, Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mark as undone?'),
        content: const Text('This task will return to your active work.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Mark as undone'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await widget.onMarkUndone?.call(task);
    }
  }

  Widget _taskRow(BuildContext context, Task task) {
    final priority = task.priority?.trim();
    final priorityColor = taskPriorityColor(priority);

    return InkWell(
      key: ValueKey('done-task-${task.id ?? task.title}'),
      onTap: widget.onOpenTask == null ? null : () => widget.onOpenTask!(task),
      child: Column(
        children: [
          // Task row: check icon + title, aur right side mein priority + timer badge
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Mark as undone',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: widget.onMarkUndone == null
                      ? null
                      : () => _confirmMarkUndone(context, task),
                  icon: Icon(
                    Icons.check_circle,
                    size: 22,
                    color: Colors.green.shade600,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
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
                const SizedBox(width: 8),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: Container(
                    width: 60,
                    height: 22,
                    constraints: const BoxConstraints(
                      maxWidth: 60,
                      maxHeight: 22,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.07),
                      border: Border.all(
                        color: priorityColor.withValues(alpha: 0.42),
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        priority?.isNotEmpty == true ? priority! : 'None',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: priorityColor,
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.onEditTaskTime != null) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Edit task time',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () => widget.onEditTaskTime!(task),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.viewType == 'Calendar') {
      return widget.calendarBuilder(widget.tasks);
    }
    if (widget.tasks.isEmpty) {
      return widget.refreshable(
        CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('No tasks found in this category.')),
            ),
          ],
        ),
      );
    }

    final tasksByDate = <DateTime?, List<Task>>{};
    for (final task in widget.tasks) {
      tasksByDate.putIfAbsent(_completionDate(task), () => []).add(task);
    }
    final entries = tasksByDate.entries.toList()
      ..sort((a, b) {
        if (a.key == null) return b.key == null ? 0 : 1;
        if (b.key == null) return -1;
        return b.key!.compareTo(a.key!);
      });
    final groupedRows = entries.map<_GroupedDoneDate>((entry) {
      final totalHours =
          entry.value.fold<int>(
            0,
            (total, task) => total + _workedMinutes(task),
          ) /
          60;
      final roundedHours = double.parse(totalHours.toStringAsFixed(2));
      return (
        date: entry.key,
        tasks: entry.value,
        totalHours: roundedHours,
        totalScore: double.parse((roundedHours * 4).toStringAsFixed(2)),
      );
    }).toList();

    final allDateKeys = groupedRows.map((row) => _dateKey(row.date)).toSet();
    Widget bottomBlankArea({Key? key, double? height}) => GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleBlankTap(allDateKeys.toList()),
      child: SizedBox(height: height, width: double.infinity),
    );

    return widget.refreshable(
      CustomScrollView(
        key: const PageStorageKey('done-work-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          for (final row in groupedRows)
            SliverMainAxisGroup(
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _DoneWorkDateHeaderDelegate(
                    height: 48,
                    child: _dateHeader(
                      context,
                      row,
                      expanded: _expandedDates.contains(_dateKey(row.date)),
                      onTap: () {
                        setState(() {
                          final key = _dateKey(row.date);
                          if (!_expandedDates.add(key)) {
                            _expandedDates.remove(key);
                          }
                        });
                      },
                      onDoubleTap: () {
                        setState(() {
                          final allExpanded = allDateKeys.every(
                            _expandedDates.contains,
                          );
                          _expandedDates
                            ..clear()
                            ..addAll(
                              allExpanded ? const <String>{} : allDateKeys,
                            );
                        });
                      },
                    ),
                  ),
                ),
                if (_expandedDates.contains(_dateKey(row.date)))
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _taskRow(context, row.tasks[index]),
                      childCount: row.tasks.length,
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 6)),
              ],
            ),
          SliverToBoxAdapter(child: bottomBlankArea(height: 100)),
          SliverFillRemaining(
            hasScrollBody: false,
            child: bottomBlankArea(
              key: const ValueKey('done-work-bottom-blank-area'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateHeader(
    BuildContext context,
    _GroupedDoneDate row, {
    required bool expanded,
    required VoidCallback onTap,
    required VoidCallback onDoubleTap,
  }) {
    final date = row.date;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Material(
        key: ValueKey('done-work-date-${_dateKey(date)}'),
        color: const Color(0xFFF1F2F4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 420;
            final horizontalPadding = compact ? 10.0 : 14.0;
            final metricFontSize = compact ? 11.0 : 12.0;
            final durationWidth = compact ? 58.0 : 52.0;
            final scoreWidth = compact ? 60.0 : 64.0;
            final reportWidth = compact ? 56.0 : 66.0;
            final dateStyle = TextStyle(
              fontSize: compact ? 12 : 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF265492),
            );
            Widget metric(String text, double width) => SizedBox(
              width: width,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  text,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: metricFontSize,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF265492),
                  ),
                ),
              ),
            );

            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 6,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: date == null
                          ? Text('Date not set', style: dateStyle)
                          : Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: _dateText(date),
                                    style: dateStyle,
                                  ),
                                  TextSpan(
                                    text:
                                        '  ${_weekday(date)} (${row.tasks.length})',
                                    style: dateStyle.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              softWrap: false,
                            ),
                    ),
                  ),
                  if (date != null) ...[
                    SizedBox(width: compact ? 4 : 6),
                    metric(
                      '${_formatDuration(row.totalHours)} Hr',
                      durationWidth,
                    ),
                    SizedBox(width: compact ? 4 : 6),
                    metric('Score ${_formatScore(row.totalScore)}', scoreWidth),
                    SizedBox(width: compact ? 4 : 6),
                    SizedBox(
                      width: reportWidth,
                      child: FilledButton(
                        key: ValueKey(
                          'done-work-daily-report-${date.toIso8601String()}',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFBE64E),
                          foregroundColor: const Color(0xFF6B5800),
                          minimumSize: Size(reportWidth, 34),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () => DailyReportSheet.show(
                          context,
                          date: date,
                          entries: row.tasks
                              .map(DailyReportEntry.fromTask)
                              .toList(),
                        ),
                        child: Text(
                          'Report',
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: compact ? 11 : 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                  SizedBox(width: compact ? 2 : 8),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: compact ? 22 : 24,
                    color: const Color(0xFF265492),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DoneWorkDateHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _DoneWorkDateHeaderDelegate({
    required this.height,
    required this.child,
  });

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;

  @override
  bool shouldRebuild(_DoneWorkDateHeaderDelegate oldDelegate) =>
      height != oldDelegate.height || child != oldDelegate.child;
}
