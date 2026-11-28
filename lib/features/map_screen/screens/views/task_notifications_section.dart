import 'dart:async';

import 'package:flutter/material.dart';

import '../../../flash/flash_alert_service.dart';
import '../../models/task.dart';
import '../dialogs/task_notification_setup_dialog.dart';
import 'date_time_picker_dialog.dart';

class TaskFlashReminderButton extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onToggle;
  final Color color;

  const TaskFlashReminderButton({
    super.key,
    required this.isExpanded,
    required this.onToggle,
    this.color = const Color(0xFF6B5800),
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Flash message',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      onPressed: onToggle,
      icon: Icon(Icons.bolt, color: color),
    );
  }
}

class TaskNotificationsSection extends StatefulWidget {
  final Task task;
  final bool isExpanded;
  final VoidCallback onChanged;
  final Color secondaryColor;
  final Color primaryColor;
  final Future<DateTime?> Function({DateTime? initial})? pickCustomTime;
  final Future<List<FlashTemplate>> Function()? loadTemplates;
  final Future<bool> Function(TaskNotification notification)
  onNotificationScheduled;

  const TaskNotificationsSection({
    super.key,
    required this.task,
    required this.isExpanded,
    required this.onChanged,
    required this.onNotificationScheduled,
    this.secondaryColor = const Color(0xFF6B5800),
    this.primaryColor = const Color(0xFFFBE64E),
    this.pickCustomTime,
    this.loadTemplates,
  });

  @override
  State<TaskNotificationsSection> createState() =>
      _TaskNotificationsSectionState();
}

class _TaskNotificationsSectionState extends State<TaskNotificationsSection> {
  String? _selectedNotificationTemplate;
  String? _selectedNotificationMessage;

  Task get task => widget.task;

  static String formatTaskNotificationTime(String isoDateTime) {
    final value = DateTime.tryParse(isoDateTime);
    if (value == null) return isoDateTime;
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final meridiem = value.hour >= 12 ? 'PM' : 'AM';
    return '${value.month}/${value.day} $hour:$minute $meridiem';
  }

  Future<void> _selectNotificationTemplate() async {
    final loadTemplates =
        widget.loadTemplates ?? FlashAlertService.loadTemplates;
    final templates = await loadTemplates();
    if (!mounted) return;

    final selected = await showDialog<FlashTemplate>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Choose a template'),
        content: SizedBox(
          width: double.maxFinite,
          height: (MediaQuery.sizeOf(dialogContext).height * 0.6)
              .clamp(160.0, 400.0)
              .toDouble(),
          child: ListView.builder(
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              return ListTile(
                title: Text(template.label),
                subtitle: Text(
                  template.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.of(dialogContext).pop(template),
              );
            },
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedNotificationTemplate = selected.label;
      _selectedNotificationMessage = selected.text;
    });
  }

  Future<void> _addTaskNotification() async {
    if (_isSchedulingNotification) return;
    final templateLabel = _selectedNotificationTemplate;
    final message = _selectedNotificationMessage;
    if (templateLabel == null || message == null || message.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a notification template first.')),
      );
      return;
    }

    final reminder = DateTime.tryParse(task.reminder ?? '');
    final notification = await showTaskNotificationSetupDialog(
      context,
      reminderAt: reminder,
      templateLabel: templateLabel,
      message: message,
      pickCustomTime: () => widget.pickCustomTime != null
          ? widget.pickCustomTime!(initial: reminder)
          : showDateTimePickerWithTabs(context, initial: reminder),
    );
    if (notification == null || !mounted) return;
    setState(() => _isSchedulingNotification = true);
    try {
      final scheduled = await widget.onNotificationScheduled(notification);
      if (!scheduled || !mounted) return;
      setState(() => task.taskNotifications.add(notification));
      widget.onChanged();
    } finally {
      if (mounted) setState(() => _isSchedulingNotification = false);
    }
  }

  bool _isSchedulingNotification = false;

  Widget _buildBorderedTile({required Widget child, bool selected = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected
            ? widget.primaryColor.withValues(alpha: 0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: selected ? widget.secondaryColor : Colors.grey.shade300,
          width: selected ? 2 : 1,
        ),
      ),
      child: Material(color: Colors.transparent, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: widget.isExpanded
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildBorderedTile(
                  selected: _selectedNotificationTemplate != null,
                  child: ListTile(
                    leading: Icon(
                      Icons.message_outlined,
                      color: widget.secondaryColor,
                    ),
                    title: const Text('Template'),
                    subtitle: Text(
                      _selectedNotificationTemplate ??
                          'Choose a notification template',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: widget.secondaryColor,
                    ),
                    onTap: _selectNotificationTemplate,
                  ),
                ),
                if (_selectedNotificationTemplate != null)
                  _buildBorderedTile(
                    child: ListTile(
                      leading: Icon(
                        Icons.notification_add,
                        color: widget.secondaryColor,
                      ),
                      title: const Text('Add notification'),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: widget.secondaryColor,
                      ),
                      onTap: _isSchedulingNotification
                          ? null
                          : _addTaskNotification,
                    ),
                  ),
                for (
                  var index = 0;
                  index < task.taskNotifications.length;
                  index++
                )
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.notifications_outlined,
                      color: widget.secondaryColor,
                    ),
                    title: Text(
                      '${task.taskNotifications[index].templateLabel} · '
                      '${task.taskNotifications[index].timing == 'Custom' ? 'Custom · ${formatTaskNotificationTime(task.taskNotifications[index].scheduledAt)}' : task.taskNotifications[index].timing}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      task.taskNotifications[index].message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: task.taskNotifications[index].isEnabled,
                          onChanged: (enabled) {
                            setState(() {
                              final notification =
                                  task.taskNotifications[index];
                              task.taskNotifications[index] = TaskNotification(
                                templateLabel: notification.templateLabel,
                                message: notification.message,
                                timing: notification.timing,
                                scheduledAt: notification.scheduledAt,
                                isEnabled: enabled,
                              );
                            });
                            widget.onChanged();
                          },
                        ),
                        IconButton(
                          tooltip: 'Remove notification',
                          onPressed: () {
                            setState(
                              () => task.taskNotifications.removeAt(index),
                            );
                            widget.onChanged();
                          },
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                  ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }
}
