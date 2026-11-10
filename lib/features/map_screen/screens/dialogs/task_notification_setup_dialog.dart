import 'package:flutter/material.dart';

import '../../models/task.dart';

const _timingOffsets = <String, Duration>{
  '5 minutes before': Duration(minutes: 5),
  '10 minutes before': Duration(minutes: 10),
  '30 minutes before': Duration(minutes: 30),
  '1 hour before': Duration(hours: 1),
  '3 hours before': Duration(hours: 3),
  '1 day before': Duration(days: 1),
  '2 days before': Duration(days: 2),
};

Future<TaskNotification?> showTaskNotificationSetupDialog(
  BuildContext context, {
  required DateTime? reminderAt,
  required String templateLabel,
  required String message,
  required Future<DateTime?> Function() pickCustomTime,
}) {
  return showDialog<TaskNotification>(
    context: context,
    builder: (_) => _TaskNotificationTimingDialog(
      reminderAt: reminderAt,
      templateLabel: templateLabel,
      message: message,
      pickCustomTime: pickCustomTime,
    ),
  );
}

class _TaskNotificationTimingDialog extends StatefulWidget {
  const _TaskNotificationTimingDialog({
    required this.reminderAt,
    required this.templateLabel,
    required this.message,
    required this.pickCustomTime,
  });

  final DateTime? reminderAt;
  final String templateLabel;
  final String message;
  final Future<DateTime?> Function() pickCustomTime;

  @override
  State<_TaskNotificationTimingDialog> createState() =>
      _TaskNotificationTimingDialogState();
}

class _TaskNotificationTimingDialogState
    extends State<_TaskNotificationTimingDialog> {
  TaskNotification _notificationFor(String timing, DateTime? scheduledAt) {
    return TaskNotification(
      templateLabel: widget.templateLabel,
      message: widget.message,
      timing: timing,
      scheduledAt: scheduledAt?.toIso8601String() ?? '',
    );
  }

  Future<void> _selectTiming(BuildContext dialogContext, String timing) async {
    if (timing == 'Now') {
      Navigator.pop(dialogContext, _notificationFor(timing, DateTime.now()));
      return;
    }
    if (timing == 'Custom') {
      final selected = await widget.pickCustomTime();
      if (selected == null || !mounted || !dialogContext.mounted) return;
      final notification = _notificationFor(timing, selected);
      Navigator.pop(dialogContext, notification);
      return;
    }

    final reminderAt = widget.reminderAt;
    final offset = _timingOffsets[timing];
    final notification = _notificationFor(
      timing,
      reminderAt != null && offset != null ? reminderAt.subtract(offset) : null,
    );
    Navigator.pop(dialogContext, notification);
  }

  @override
  Widget build(BuildContext context) {
    final options = [..._timingOffsets.keys, 'Custom', 'Now'];
    final mediaQuery = MediaQuery.of(context);
    final availableHeight =
        mediaQuery.size.height - mediaQuery.viewInsets.bottom - 180;
    final visibleOptionsHeight = availableHeight.clamp(120.0, 320.0).toDouble();
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      scrollable: true,
      title: const Text('When to notify'),
      contentPadding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
      content: SizedBox(
        width: 300,
        height: visibleOptionsHeight,
        child: ListView.builder(
          padding: EdgeInsets.zero,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemExtent: 48,
          itemCount: options.length,
          itemBuilder: (context, index) {
            final option = options[index];
            return ListTile(
              dense: true,
              leading: const Icon(Icons.radio_button_off),
              title: Text(option),
              onTap: () => _selectTiming(context, option),
            );
          },
        ),
      ),
    );
  }
}
