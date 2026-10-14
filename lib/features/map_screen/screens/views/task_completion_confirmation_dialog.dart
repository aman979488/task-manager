import 'package:flutter/material.dart';

Future<bool> showTaskCompletionConfirmation(
  BuildContext context,
  String taskTitle,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Mark task as done?'),
      content: Text('Mark "$taskTitle" as completed?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
