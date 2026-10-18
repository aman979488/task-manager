import 'package:flutter/material.dart';

Future<bool> showTaskDeleteConfirmationDialog(
  BuildContext context,
  int taskCount,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text('Delete $taskCount task(s)?'),
        scrollable: true,
        content: const Text(
          'Are you sure you want to delete selected tasks?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
