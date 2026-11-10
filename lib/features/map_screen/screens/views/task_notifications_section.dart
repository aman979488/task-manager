import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../viewmodels/auth_viewmodel.dart';
import '../../../flash/flash_alert_service.dart';
import '../../../flash/flash_compose_sheet.dart';
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
      constraints: const BoxConstraints.tightFor(
        width: 36,
        height: 36,
      ),
      onPressed: onToggle,
      icon: Icon(
        Icons.bolt,
        color: color,
      ),
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
  final Future<DateTime?> Function()? pickFlashScheduleTime;

  const TaskNotificationsSection({
    super.key,
    required this.task,
    required this.isExpanded,
    required this.onChanged,
    this.secondaryColor = const Color(0xFF6B5800),
    this.primaryColor = const Color(0xFFFBE64E),
    this.pickCustomTime,
    this.pickFlashScheduleTime,
  });

  @override
  State<TaskNotificationsSection> createState() =>
      _TaskNotificationsSectionState();
}

class _TaskNotificationsSectionState extends State<TaskNotificationsSection> {
  final TextEditingController _otherNotificationMessageController =
      TextEditingController();
  String _selectedNotificationTemplate =
      FlashAlertService.defaultTemplates.first.label;
  String? _selectedNotificationMessage;

  Task get task => widget.task;

  @override
  void dispose() {
    _otherNotificationMessageController.dispose();
    super.dispose();
  }

  static String formatTaskNotificationTime(String isoDateTime) {
    final value = DateTime.tryParse(isoDateTime);
    if (value == null) return isoDateTime;
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final meridiem = value.hour >= 12 ? 'PM' : 'AM';
    return '${value.month}/${value.day} $hour:$minute $meridiem';
  }

  Future<void> _addTaskNotification() async {
    final isCustom = _selectedNotificationTemplate == 'Others';
    final templates = FlashAlertService.defaultTemplates.where(
      (template) => template.label == _selectedNotificationTemplate,
    );
    final defaultMessage = templates.isEmpty ? '' : templates.first.text;
    final message = isCustom
        ? _otherNotificationMessageController.text.trim()
        : _selectedNotificationMessage ?? defaultMessage;
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a notification message first.')),
      );
      return;
    }

    final reminder = DateTime.tryParse(task.reminder ?? '');
    final notification = await showTaskNotificationSetupDialog(
      context,
      reminderAt: reminder,
      templateLabel: _selectedNotificationTemplate,
      message: message,
      pickCustomTime: () => widget.pickCustomTime != null
          ? widget.pickCustomTime!(initial: reminder)
          : showDateTimePickerWithTabs(context, initial: reminder),
    );
    if (notification == null || !mounted) return;
    setState(() => task.taskNotifications.add(notification));
    widget.onChanged();
  }

  Future<void> _openFlashMessageDialog() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    if (!authViewModel.loggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to send a flash message.')),
      );
      return;
    }

    final draft = await showFlashComposeSheet(
      context,
      senderUid: authViewModel.userUid,
      pickTime: () => widget.pickFlashScheduleTime != null
          ? widget.pickFlashScheduleTime!()
          : showDateTimePickerWithTabs(
              context,
              initial: DateTime.now().add(const Duration(minutes: 5)),
            ),
    );
    if (draft == null || !mounted) return;

    try {
      await FlashAlertService.send(
        draft.copyWith(taskId: task.id),
        senderUid: authViewModel.userUid,
        senderName: authViewModel.userName,
      );
      if (!mounted) return;
      setState(() {
        _selectedNotificationTemplate = draft.templateLabel ?? 'Others';
        _selectedNotificationMessage = draft.text;
        if (_selectedNotificationTemplate == 'Others') {
          _otherNotificationMessageController.text = draft.text;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            draft.sendAt == null
                ? 'Flash message sent to ${draft.recipient.name}.'
                : 'Flash message scheduled for ${draft.recipient.name}.',
          ),
        ),
      );
    } on FirebaseException catch (error) {
      debugPrint('Could not send flash message: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not send the flash message. Please try again.',
            ),
          ),
        );
      }
    } catch (error) {
      debugPrint('Unexpected error sending flash message: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not send the flash message. Please try again.',
            ),
          ),
        );
      }
    }
  }

  Widget _buildBorderedTile({required Widget child}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
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
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: widget.secondaryColor.withValues(alpha: 0.55),
                      width: 1.2,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.notification_add,
                        color: widget.secondaryColor,
                      ),
                      title: const Text('Add notification'),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: widget.secondaryColor,
                      ),
                      onTap: _addTaskNotification,
                    ),
                  ),
                ),
                _buildBorderedTile(
                  child: ListTile(
                    leading: Icon(
                      Icons.message_outlined,
                      color: widget.secondaryColor,
                    ),
                    title: const Text('Template'),
                    subtitle: Text(
                      _selectedNotificationTemplate,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: widget.secondaryColor,
                    ),
                    onTap: _openFlashMessageDialog,
                  ),
                ),
                for (var index = 0; index < task.taskNotifications.length; index++)
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
                          icon: const Icon(
                            Icons.close,
                            size: 18,
                          ),
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
