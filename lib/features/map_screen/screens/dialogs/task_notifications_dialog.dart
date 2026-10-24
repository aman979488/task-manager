import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../utils/task_constants.dart';
import '../../utils/task_date_formatter.dart';

Future<void> showTaskNotificationsDialog(
  BuildContext context,
  List<Task> reminders,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final screenHeight = MediaQuery.sizeOf(dialogContext).height;
      final visibleReminderCount = reminders.length.clamp(1, 3);
      final maxListHeight = (screenHeight * 0.75 - 140).clamp(72.0, 216.0);
      final listHeight = (visibleReminderCount * 72.0)
          .clamp(72.0, maxListHeight)
          .toDouble();

      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 360,
            maxHeight: screenHeight * 0.85,
          ),
          child: SizedBox(
            width: 360,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (reminders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No upcoming task reminders.'),
                    )
                  else
                    SizedBox(
                      height: listHeight,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemExtent: 72,
                        itemCount: reminders.length,
                        itemBuilder: (context, index) {
                          final task = reminders[index];
                          final scheduled = TaskDateFormatter.scheduledDate(
                            task.deadline,
                            task.reminder,
                          )!;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.notifications_outlined,
                              color: TaskConstants.secondaryColor,
                            ),
                            title: Text(
                              task.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${scheduled.day}/${scheduled.month}/${scheduled.year} '
                              '${scheduled.hour.toString().padLeft(2, '0')}:'
                              '${scheduled.minute.toString().padLeft(2, '0')}',
                            ),
                          );
                        },
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
