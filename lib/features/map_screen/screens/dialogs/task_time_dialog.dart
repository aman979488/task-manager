import 'package:flutter/material.dart';

Future<(String, String)?> showTaskTimeDialog(
  BuildContext context, {
  String? startTime,
  String? endTime,
}) {
  TimeOfDay? parseTime(String? value) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?:\s*(AM|PM))?$',
      caseSensitive: false,
    ).firstMatch(value?.trim() ?? '');
    if (match == null) return null;

    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final meridiem = match.group(3)?.toUpperCase();
    if (minute > 59) return null;
    if (meridiem != null) {
      if (hour < 1 || hour > 12) return null;
      hour %= 12;
      if (meridiem == 'PM') hour += 12;
    } else if (hour > 23) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  final selectedStart = parseTime(startTime) ?? TimeOfDay.now();
  final startMinutes = selectedStart.hour * 60 + selectedStart.minute;
  var selectedStartTime = selectedStart;
  var selectedEndTime =
      parseTime(endTime) ??
      TimeOfDay(
        hour: (startMinutes + 60) ~/ 60 % 24,
        minute: (startMinutes + 60) % 60,
      );

  return showDialog<(String, String)>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Set task time'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TaskTimePickerRow(
              label: 'Start time',
              value: selectedStartTime,
              onTap: () async {
                final selected = await showTimePicker(
                  context: context,
                  initialTime: selectedStartTime,
                );
                if (selected != null) {
                  setState(() => selectedStartTime = selected);
                }
              },
            ),
            _TaskTimePickerRow(
              label: 'End time',
              value: selectedEndTime,
              onTap: () async {
                final selected = await showTimePicker(
                  context: context,
                  initialTime: selectedEndTime,
                );
                if (selected != null) {
                  setState(() => selectedEndTime = selected);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, (
              selectedStartTime.format(context),
              selectedEndTime.format(context),
            )),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

class _TaskTimePickerRow extends StatelessWidget {
  const _TaskTimePickerRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final TimeOfDay value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    trailing: TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.access_time),
      label: Text(value.format(context)),
    ),
  );
}
