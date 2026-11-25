import 'package:flutter/material.dart';

import '../../models/task.dart';

const Color _yellow = Color(0xFFFBE64E);
const Color _brown = Color(0xFF6B5800);

enum DailyReportType { call, message, meet, other }

class _TypeStyle {
  const _TypeStyle(this.icon, this.color, this.label);

  final IconData icon;
  final Color color;
  final String label;
}

_TypeStyle _styleFor(DailyReportType type) {
  switch (type) {
    case DailyReportType.call:
      return const _TypeStyle(Icons.call, Color(0xFFC65353), 'Call');
    case DailyReportType.message:
      return const _TypeStyle(Icons.chat_bubble, Color(0xFF2E8B57), 'Message');
    case DailyReportType.meet:
      return const _TypeStyle(Icons.groups, Color(0xFF6A5ACD), 'Meeting');
    case DailyReportType.other:
      return const _TypeStyle(Icons.assignment, _brown, 'Task');
  }
}

/// Ek din ke report ki ek row. Task se bhi ban sakti hai, ya haath se bhi.
class DailyReportEntry {
  const DailyReportEntry({
    required this.type,
    required this.title,
    this.workType = '',
    this.client = '',
    this.note = '',
    this.timeLabel = '',
    this.onEdit,
  });

  final DailyReportType type;
  final String title;
  final String workType;
  final String client;
  final String note;
  final String timeLabel;
  final VoidCallback? onEdit;

  factory DailyReportEntry.fromTask(Task task, {VoidCallback? onEdit}) {
    final workType = task.workType?.trim() ?? '';
    return DailyReportEntry(
      type: _typeFor(workType),
      title: task.title,
      workType: workType,
      client: task.clientName?.trim() ?? '',
      note: task.note.trim(),
      timeLabel: _timeLabel(task),
      onEdit: onEdit,
    );
  }

  static DailyReportType _typeFor(String workType) {
    final value = workType.toLowerCase();
    if (value.contains('call')) return DailyReportType.call;
    if (value.contains('whatsapp') ||
        value.contains('message') ||
        value.contains('email')) {
      return DailyReportType.message;
    }
    if (value.contains('visit') || value.contains('meet')) {
      return DailyReportType.meet;
    }
    return DailyReportType.other;
  }

  static String _timeLabel(Task task) {
    final start = task.startTime?.trim() ?? '';
    final end = task.endTime?.trim() ?? '';
    if (start.isNotEmpty && end.isNotEmpty) return '$start - $end';
    if (start.isNotEmpty) return start;
    final deadline = DateTime.tryParse(task.deadline ?? '');
    if (deadline == null) return '';
    final hour = deadline.hour % 12 == 0 ? 12 : deadline.hour % 12;
    final minute = deadline.minute.toString().padLeft(2, '0');
    final period = deadline.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

class DailyReportSheet extends StatefulWidget {
  const DailyReportSheet({
    super.key,
    required this.dateLabel,
    required this.entries,
    this.onAddEntry,
  });

  final String dateLabel;
  final List<DailyReportEntry> entries;
  final VoidCallback? onAddEntry;

  static Future<void> show(
    BuildContext context, {
    required DateTime date,
    required List<DailyReportEntry> entries,
    VoidCallback? onAddEntry,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.8,
        child: DailyReportSheet(
          dateLabel: _dateLabel(date),
          entries: entries,
          onAddEntry: onAddEntry,
        ),
      ),
    );
  }

  @override
  State<DailyReportSheet> createState() => _DailyReportSheetState();
}

class _DailyReportSheetState extends State<DailyReportSheet> {
  DailyReportType? _filter;
  double? _pointerStartDy;
  double _pointerDragDy = 0;

  int _count(DailyReportType type) =>
      widget.entries.where((entry) => entry.type == type).length;

  @override
  Widget build(BuildContext context) {
    final visible = _filter == null
        ? widget.entries
        : widget.entries.where((entry) => entry.type == _filter).toList();

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _pointerStartDy = event.position.dy;
        _pointerDragDy = 0;
      },
      onPointerMove: (event) {
        if (_pointerStartDy == null) return;
        _pointerDragDy = event.position.dy - _pointerStartDy!;
      },
      onPointerUp: (event) {
        final shouldClose = _pointerDragDy >= 64;
        _pointerStartDy = null;
        _pointerDragDy = 0;
        if (shouldClose && mounted) {
          Navigator.of(context).pop();
        }
      },
      onPointerCancel: (_) {
        _pointerStartDy = null;
        _pointerDragDy = 0;
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Report',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        widget.dateLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.onAddEntry != null)
                  FilledButton.icon(
                    onPressed: widget.onAddEntry,
                    style: FilledButton.styleFrom(
                      backgroundColor: _yellow,
                      foregroundColor: _brown,
                      shape: const StadiumBorder(),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    icon: const Icon(Icons.add_circle_outline, size: 16),
                    label: const Text(
                      'Add Entry',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _FilterTabs(
            selected: _filter,
            onSelected: (type) => setState(() => _filter = type),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              children: [
                _SummaryCard(
                  total: widget.entries.length,
                  calls: _count(DailyReportType.call),
                  messages: _count(DailyReportType.message),
                  meets: _count(DailyReportType.meet),
                  others: _count(DailyReportType.other),
                  dateLabel: widget.dateLabel,
                ),
                const SizedBox(height: 12),
                if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 32,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No work done on this day.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (var i = 0; i < visible.length; i++)
                    _TimelineItem(
                      entry: visible[i],
                      isLast: i == visible.length - 1,
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({required this.selected, required this.onSelected});

  final DailyReportType? selected;
  final ValueChanged<DailyReportType?> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = <(DailyReportType?, IconData, String)>[
      (null, Icons.all_inclusive, 'All'),
      (DailyReportType.call, Icons.call, 'Calls'),
      (DailyReportType.message, Icons.chat_bubble, 'Messages'),
      (DailyReportType.meet, Icons.groups, 'Meetings'),
      (DailyReportType.other, Icons.assignment, 'Tasks'),
    ];

    return Row(
      children: [
        for (final item in items)
          Expanded(
            child: Tooltip(
              message: item.$3,
              child: InkWell(
                onTap: () => onSelected(item.$1),
                child: Container(
                  padding: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selected == item.$1
                            ? _brown
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Icon(
                      item.$2,
                      size: 20,
                      color: selected == item.$1
                          ? _brown
                          : Colors.grey.shade500,
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.total,
    required this.calls,
    required this.messages,
    required this.meets,
    required this.others,
    required this.dateLabel,
  });

  final int total;
  final int calls;
  final int messages;
  final int meets;
  final int others;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8DC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2E6A8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.event_available, color: _brown),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Work done',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      total == 1 ? '1 task' : '$total tasks',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      dateLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Stat(DailyReportType.call, calls, 'Calls'),
              _Stat(DailyReportType.message, messages, 'Msg'),
              _Stat(DailyReportType.meet, meets, 'Meets'),
              _Stat(DailyReportType.other, others, 'Tasks'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.type, this.count, this.label);

  final DailyReportType type;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(type);
    return Column(
      children: [
        Container(
          height: 30,
          width: 30,
          decoration: BoxDecoration(
            color: style.color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(style.icon, size: 18, color: style.color),
        ),
        const SizedBox(height: 3),
        Text(
          '$count',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
        ),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.entry, required this.isLast});

  final DailyReportEntry entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(entry.type);
    final typeLabel = entry.workType.isNotEmpty ? entry.workType : style.label;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  height: 30,
                  width: 30,
                  decoration: BoxDecoration(
                    color: style.color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(style.icon, size: 16, color: style.color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: Colors.grey.shade300,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _Chip(label: typeLabel, color: style.color),
                              if (entry.client.isNotEmpty)
                                _Chip(
                                  label: entry.client,
                                  color: Colors.blueGrey,
                                ),
                            ],
                          ),
                        ),
                        if (entry.timeLabel.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 6, top: 2),
                            child: Text(
                              entry.timeLabel,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        if (entry.onEdit != null)
                          InkWell(
                            onTap: entry.onEdit,
                            borderRadius: BorderRadius.circular(16),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: _brown,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (entry.note.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          entry.note,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
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
  return '${weekdays[date.weekday - 1]}, ${date.day} '
      '${months[date.month - 1]} ${date.year}';
}
