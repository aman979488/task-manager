import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInputFormatter;
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:provider/provider.dart';

import '../../../viewmodels/auth_viewmodel.dart';
import '../models/floating_sheet_type.dart';
import '../models/task.dart';
import '../services/task_assignment_notification_service.dart';
import '../services/task_detail_data_service.dart';
import '../utils/priority_reminder.dart';
import '../utils/task_week_helpers.dart';
import 'views/task_detail_overlay.dart';
import 'views/date_time_picker_dialog.dart';
import 'views/task_files_section.dart';
import 'views/task_step_list_widget.dart';

class TaskDetailPage extends StatefulWidget {
  final Task task;
  final VoidCallback onChanged;
  final Future<void> Function() onSave;
  final bool isNewTask;

  const TaskDetailPage({
    super.key,
    required this.task,
    required this.onSave,
    VoidCallback? onChanged,
    this.isNewTask = false,
  }) : onChanged = onChanged ?? _defaultCallback;

  static void _defaultCallback() {}

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage>
    with WidgetsBindingObserver {
  static const int _maxTitleWords = 30;

  late final TaskAssignmentNotificationService _assignmentNotificationService =
      TaskAssignmentNotificationService();
  late final TaskDetailDataService _dataService = TaskDetailDataService();
  late final TaskDetailOverlay _overlay = TaskDetailOverlay();

  late TextEditingController _noteController;
  bool _showAdditionalDetails = false;
  Future<String?>? _createdByNameFuture;

  // for editing main title
  late TextEditingController _titleController;
  final GlobalKey _titleInputKey = GlobalKey();
  final GlobalKey _priorityAnchorKey = GlobalKey();
  final GlobalKey _workTypeAnchorKey = GlobalKey();
  final GlobalKey _reminderAnchorKey = GlobalKey();
  final GlobalKey _assigneeAnchorKey = GlobalKey();
  final GlobalKey _clientNameAnchorKey = GlobalKey();
  final GlobalKey _deadlineAnchorKey = GlobalKey();
  final GlobalKey _refProjectAnchorKey = GlobalKey();
  final GlobalKey _folderAnchorKey = GlobalKey();
  final GlobalKey _goalAnchorKey = GlobalKey();
  Timer? _titleVisibilityTimer;
  bool _isEditingTitle = false;
  bool _needsPersistDefaultFollowUp = false;

  Task get task => widget.task;
  bool _isSaving = false;

  static const Color primaryColor = Color(0xFFFBE64E);
  static const Color secondaryColor = Color(0xFF6B5800);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _noteController = TextEditingController(
      text: task.note.trim().isNotEmpty ? task.note : task.remark ?? '',
    );
    _titleController = TextEditingController(text: task.title)
      ..selection = TextSelection.collapsed(offset: task.title.length);
    _isEditingTitle = widget.isNewTask;
    if (task.followUp == null || task.followUp!.isEmpty) {
      task.followUp = DateTime.now().toIso8601String();
      _needsPersistDefaultFollowUp = !widget.isNewTask;
    }
    if (_needsPersistDefaultFollowUp) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_needsPersistDefaultFollowUp) return;
        _needsPersistDefaultFollowUp = false;
        _saveTask(automatic: true, showSavedMessage: false);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _titleVisibilityTimer?.cancel();
    _overlay.dispose();
    task.note = _noteController.text;
    _noteController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (!_isEditingTitle ||
        WidgetsBinding
                .instance
                .platformDispatcher
                .views
                .first
                .viewInsets
                .bottom ==
            0) {
      return;
    }

    _titleVisibilityTimer?.cancel();
    _titleVisibilityTimer = Timer(const Duration(milliseconds: 120), () {
      final titleContext = _titleInputKey.currentContext;
      if (!mounted || titleContext == null) return;
      Scrollable.ensureVisible(
        titleContext,
        alignment: 0.15,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendTaskAssignmentNotification(
    String? assignee,
    String taskTitle,
    BuildContext ctx,
  ) async {
    if (assignee == null || assignee.trim().isEmpty) return;
    final authVM = Provider.of<AuthViewModel>(ctx, listen: false);
    try {
      await _assignmentNotificationService.sendAssignmentNotification(
        assignee: assignee,
        taskTitle: taskTitle,
        senderName: authVM.userName,
        senderUid: authVM.userUid,
        senderEmail: authVM.userEmail,
        notificationsEnabled: authVM.allowNotifications,
      );
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  void _onSelectOption(String key, String label) {
    setState(() {
      switch (key) {
        case 'priority':
          task.priority = label;
          task.priorityUpdatedAt = DateTime.now().millisecondsSinceEpoch;
          final reminder = reminderForPriority(label);
          if (reminder != null) {
            task
              ..reminder = reminder.toIso8601String()
              ..reminderSent = false;
          }
          break;
        case 'assignee':
          task.assignee = label;
          _sendTaskAssignmentNotification(label, task.title, context);
          break;
        case 'workType':
          task.workType = label;
          break;
        case 'clientName':
          task.clientName = label;
          break;
        case 'refProject':
          task.refProject = label;
          break;
        case 'folder':
          task.folder = label;
          break;
        case 'goal':
          task.weekKey = label;
          break;
        default:
          break;
      }
    });
    widget.onChanged();
  }

  void _onSelectDateTime(String key, DateTime dt) {
    final iso = dt.toIso8601String();
    setState(() {
      if (key == 'reminder') {
        task.reminder = iso;
      } else {
        task.deadline = iso;
      }
    });
    widget.onChanged();
  }

  void _showOverlay(
    BuildContext buttonContext,
    FloatingSheetType type, {
    String? fieldKey,
  }) {
    _overlay.show(
      buttonContext: buttonContext,
      type: type,
      fieldKey: fieldKey,
      loadWorkTypes: _dataService.loadWorkTypes,
      loadAssignees: _dataService.loadAssignees,
      loadClients: _dataService.loadClients,
      loadFolders: _dataService.loadFolders,
      loadProjects: _dataService.loadProjects,
      goalWeekKeys: _goalWeekOptions,
      onSelectOption: _onSelectOption,
      onSelectDateTime: _onSelectDateTime,
    );
  }

  List<String> get _goalWeekOptions {
    final now = DateTime.now();
    final selected = dateRangeForWeek(task.weekKey ?? '');
    final keys = <String>{
      ...weeksOfMonth(now.year, now.month).map((week) => week.key),
      if (selected != null)
        ...weeksOfMonth(selected.year, selected.month).map((week) => week.key),
    };
    return keys.toList()..sort();
  }

  void _saveTitle(String value) {
    _commitTitle(value);
  }

  void _commitTitle(String value) {
    final title = value.trim();
    if (title.isEmpty) {
      setState(() {
        _titleController.text = task.title;
        _isEditingTitle = false;
      });
      return;
    }
    setState(() {
      task.title = title;
      _titleController.text = title;
      _titleController.selection = TextSelection.collapsed(
        offset: title.length,
      );
      _isEditingTitle = false;
    });
    widget.onChanged();
  }

  Widget _animatedBorderedTile({
    required Widget child,
    required bool isSelected,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? primaryColor.withValues(alpha: 0.1) : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isSelected ? secondaryColor : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(color: Colors.transparent, child: child),
    );
  }

  Widget _buildOverlayTile({
    required GlobalKey anchorKey,
    required String? value,
    required IconData icon,
    required String label,
    required FloatingSheetType type,
    String? fieldKey,
  }) {
    return _animatedBorderedTile(
      isSelected: _isSelected(value),
      child: SizedBox(
        key: anchorKey,
        child: ListTile(
          leading: Icon(icon, color: secondaryColor),
          title: Text(label),
          trailing: _infoTrailing(value),
          onTap: () =>
              _showOverlayFromAnchor(anchorKey, type, fieldKey: fieldKey),
        ),
      ),
    );
  }

  void _showOverlayFromAnchor(
    GlobalKey anchorKey,
    FloatingSheetType type, {
    String? fieldKey,
  }) {
    final anchorContext = anchorKey.currentContext;
    if (anchorContext == null) {
      throw StateError('Task detail overlay anchor is not mounted.');
    }
    _showOverlay(anchorContext, type, fieldKey: fieldKey);
  }

  Widget _infoTrailing(String? value) {
    if (value == null || value.isEmpty) {
      return Text(
        "None",
        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
      );
    }

    try {
      final dt = DateTime.parse(value);
      final month = dt.month.toString().padLeft(2, '0');
      final day = dt.day.toString().padLeft(2, '0');
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final timeStr =
          '${hour.toString().padLeft(2, '0')}:$minute '
          '${dt.hour >= 12 ? 'PM' : 'AM'}';
      final display = '$month/$day/${dt.year}, $timeStr';

      return Text(
        display,
        style: const TextStyle(
          color: secondaryColor,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      );
    } catch (_) {
      return Text(
        value,
        style: const TextStyle(
          color: secondaryColor,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      );
    }
  }

  bool _isSelected(String? value) => value != null && value.isNotEmpty;

  Future<void> _pickFollowUp() async {
    final picked = await showDateTimePickerWithTabs(
      context,
      initial: DateTime.tryParse(task.followUp ?? ''),
    );
    if (picked == null || !mounted) return;
    setState(() => task.followUp = picked.toIso8601String());
    widget.onChanged();
  }

  int _wordCount(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? 0 : trimmed.split(RegExp(r'\s+')).length;
  }

  Future<bool> _saveTask({
    bool automatic = false,
    bool showSavedMessage = true,
  }) async {
    if (_isSaving) return false;
    final titleToSave = _isEditingTitle
        ? _titleController.text.trim()
        : task.title.trim();
    if (widget.isNewTask && titleToSave.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Task title is required')));
      return false;
    }
    if ((_isEditingTitle || widget.isNewTask) &&
        _wordCount(titleToSave) > _maxTitleWords) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Work name cannot exceed 30 words')),
      );
      return false;
    }
    if ((!automatic || widget.isNewTask) &&
        (task.followUp == null || task.followUp!.isEmpty)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Date & Time is required')));
      return false;
    }
    setState(() => _isSaving = true);
    if (_isEditingTitle) {
      _commitTitle(_titleController.text);
    }

    task.note = _noteController.text;
    try {
      await widget.onSave();
      if (!mounted) return true;
      if (widget.isNewTask) {
        Navigator.of(context).pop(true);
        return true;
      }
      setState(() {
        _isEditingTitle = false;
        _titleController.text = task.title;
      });
      if (showSavedMessage) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Task saved')));
      }
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Could not save task: $error')));
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _setTaskDone(bool isDone) async {
    if (_isSaving || isDone == task.isDone) return;
    final previousIsDone = task.isDone;
    final previousCompletedAt = task.completedAt;
    setState(() {
      task.isDone = isDone;
      task.completedAt = isDone ? DateTime.now().millisecondsSinceEpoch : null;
    });
    widget.onChanged();

    final saved = await _saveTask(automatic: true);
    if (!saved && mounted) {
      setState(() {
        task.isDone = previousIsDone;
        task.completedAt = previousCompletedAt;
      });
      widget.onChanged();
    }
  }

  Widget _buildExtraFieldTile({
    required String label,
    required String? value,
    required IconData icon,
    required Future<void> Function(BuildContext) onTap,
  }) {
    return Builder(
      builder: (buttonContext) => _animatedBorderedTile(
        isSelected: _isSelected(value),
        child: ListTile(
          leading: Icon(icon, color: secondaryColor),
          title: Text(label),
          trailing: _infoTrailing(value),
          onTap: () => onTap(buttonContext),
        ),
      ),
    );
  }

  Future<void> _pickExtraTime(
    BuildContext buttonContext,
    void Function(String) onChanged,
  ) async {
    final time = await showTimePicker(
      context: buttonContext,
      initialTime: TimeOfDay.now(),
    );
    if (time == null || !mounted) return;
    setState(() => onChanged(time.format(context)));
    widget.onChanged();
  }

  Future<void> _selectTaskPeople(
    BuildContext buttonContext, {
    required String label,
    required String? selectedValue,
    required void Function(String) onChanged,
  }) async {
    List<List<String>> peopleLists;
    try {
      peopleLists = await Future.wait([
        _dataService.loadClients(),
        _dataService.loadAssignees(),
      ]);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load clients and staff: $error')),
        );
      }
      return;
    }

    if (!buttonContext.mounted) return;
    final clients = peopleLists[0];
    final staff = peopleLists[1];
    final selected = <String, String>{
      for (final name
          in (selectedValue ?? '')
              .split(RegExp(r'[,;\n]'))
              .map((name) => name.trim())
              .where((name) => name.isNotEmpty))
        name.toLowerCase(): name,
    };

    final result = await showDialog<List<String>>(
      context: buttonContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Select $label'),
          content: SizedBox(
            width: 360,
            height: MediaQuery.sizeOf(context).height * 0.6,
            child: ListView(
              children: [
                _peopleSectionTitle('Clients'),
                if (clients.isEmpty)
                  const ListTile(
                    dense: true,
                    title: Text(
                      'No clients found',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                for (final name in clients)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(name, style: const TextStyle(fontSize: 14)),
                    value: selected.containsKey(name.toLowerCase()),
                    onChanged: (value) => setDialogState(() {
                      if (value == true) {
                        selected[name.toLowerCase()] = name;
                      } else {
                        selected.remove(name.toLowerCase());
                      }
                    }),
                  ),
                _peopleSectionTitle('Staff'),
                if (staff.isEmpty)
                  const ListTile(
                    dense: true,
                    title: Text(
                      'No staff found',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                for (final name in staff)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(name, style: const TextStyle(fontSize: 14)),
                    value: selected.containsKey(name.toLowerCase()),
                    onChanged: (value) => setDialogState(() {
                      if (value == true) {
                        selected[name.toLowerCase()] = name;
                      } else {
                        selected.remove(name.toLowerCase());
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                selected.values.toList()
                  ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );

    if (result == null || !mounted) return;
    setState(() => onChanged(result.join(', ')));
    widget.onChanged();
  }

  Widget _peopleSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 4),
    child: Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text(
          "Task",
          style: TextStyle(color: secondaryColor, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: secondaryColor),
        actions: [
          TextButton(
            onPressed: _isSaving
                ? null
                : () {
                    _saveTask();
                  },
            style: TextButton.styleFrom(foregroundColor: secondaryColor),
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: secondaryColor,
                    ),
                  )
                : const Text('Save'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWeb = constraints.maxWidth >= 1024;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWeb ? 900 : double.infinity,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: NotificationListener<UserScrollNotification>(
                  onNotification: (notification) {
                    if (notification.direction != ScrollDirection.idle &&
                        _overlay.isShowing) {
                      _overlay.hide();
                    }
                    return false;
                  },
                  child: Scrollbar(
                    notificationPredicate: (_) => false,
                    child: ListView(
                      children: [
                        _buildExtraFieldTile(
                          label: 'Date & Time',
                          value: task.followUp,
                          icon: Icons.calendar_month,
                          onTap: (_) => _pickFollowUp(),
                        ),

                        KeyedSubtree(
                          key: _titleInputKey,
                          child: TextField(
                            key: const ValueKey('task-title-input'),
                            controller: _titleController,
                            readOnly: !_isEditingTitle,
                            autofocus: _isEditingTitle,
                            inputFormatters: [
                              TextInputFormatter.withFunction((
                                oldValue,
                                newValue,
                              ) {
                                final newWordCount = _wordCount(newValue.text);
                                final oldWordCount = _wordCount(oldValue.text);
                                return newWordCount <= _maxTitleWords ||
                                        newWordCount < oldWordCount
                                    ? newValue
                                    : oldValue;
                              }),
                            ],
                            onTap: () {
                              if (_isEditingTitle) return;
                              setState(() {
                                _isEditingTitle = true;
                                _titleController.selection =
                                    TextSelection.collapsed(
                                      offset: _titleController.text.length,
                                    );
                              });
                            },
                            decoration: InputDecoration(
                              labelText: 'Work Detail',
                              labelStyle: const TextStyle(
                                fontSize: 13,
                                color: secondaryColor,
                              ),
                              floatingLabelStyle: const TextStyle(
                                fontSize: 13,
                                color: secondaryColor,
                              ),
                              floatingLabelBehavior: FloatingLabelBehavior.auto,
                              floatingLabelAlignment:
                                  FloatingLabelAlignment.start,
                              prefixIcon: const Icon(
                                Icons.work_outline,
                                color: secondaryColor,
                              ),
                              suffixIcon: SizedBox(
                                width: 68,
                                child: Switch(
                                  key: const ValueKey('task-done-toggle'),
                                  value: task.isDone,
                                  onChanged: _isSaving
                                      ? null
                                      : _setTaskDone,
                                  activeTrackColor: secondaryColor,
                                ),
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(
                                  color: _isSelected(task.title)
                                      ? secondaryColor
                                      : Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: const BorderSide(
                                  color: secondaryColor,
                                  width: 2,
                                ),
                              ),
                            ),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              decoration: task.isDone
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                            onSubmitted: _saveTitle,
                          ),
                        ),

                        // ── Steps ────────────────────────────────────────
                        TaskStepListWidget(
                          task: task,
                          onChanged: widget.onChanged,
                          onSave: widget.onSave,
                          secondaryColor: secondaryColor,
                        ),

                        const SizedBox(height: 8),

                        // ── Fields ───────────────────────────────────────
                        _buildOverlayTile(
                          anchorKey: _priorityAnchorKey,
                          value: task.priority,
                          icon: Icons.flag_sharp,
                          label: 'Priority',
                          type: FloatingSheetType.priority,
                        ),
                        _buildOverlayTile(
                          anchorKey: _workTypeAnchorKey,
                          value: task.workType,
                          icon: Icons.insert_drive_file,
                          label: 'Work Type',
                          type: FloatingSheetType.workType,
                          fieldKey: 'workType',
                        ),
                        _buildOverlayTile(
                          anchorKey: _reminderAnchorKey,
                          value: task.reminder,
                          icon: Icons.notifications_active,
                          label: 'Remind Me',
                          type: FloatingSheetType.remind,
                        ),
                        _buildOverlayTile(
                          anchorKey: _assigneeAnchorKey,
                          value: task.assignee,
                          icon: Icons.checklist,
                          label: 'Assign',
                          type: FloatingSheetType.assign,
                        ),
                        _buildOverlayTile(
                          anchorKey: _clientNameAnchorKey,
                          value: task.clientName,
                          icon: Icons.business_center_outlined,
                          label: 'Client Name',
                          type: FloatingSheetType.clientName,
                          fieldKey: 'clientName',
                        ),
                        _buildOverlayTile(
                          anchorKey: _deadlineAnchorKey,
                          value: task.deadline,
                          icon: Icons.alarm,
                          label: 'Deadline',
                          type: FloatingSheetType.deadline,
                        ),
                        Align(
                          alignment: Alignment.center,
                          child: InkWell(
                            onTap: () => setState(
                              () => _showAdditionalDetails =
                                  !_showAdditionalDetails,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _showAdditionalDetails
                                        ? Icons.keyboard_arrow_up
                                        : Icons.keyboard_arrow_down,
                                    color: Colors.black87,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _showAdditionalDetails
                                        ? 'View less'
                                        : 'View more',
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (_showAdditionalDetails) ...[
                          _buildOverlayTile(
                            anchorKey: _refProjectAnchorKey,
                            value: task.refProject,
                            icon: Icons.apartment_outlined,
                            label: 'Ref Project',
                            type: FloatingSheetType.refProject,
                            fieldKey: 'refProject',
                          ),
                          _buildOverlayTile(
                            anchorKey: _goalAnchorKey,
                            value: task.weekKey == null
                                ? null
                                : weekLabelForKey(task.weekKey!),
                            icon: Icons.flag_outlined,
                            label: 'Goal (week)',
                            type: FloatingSheetType.goal,
                          ),
                          SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            dense: true,
                            title: const Text(
                              'Monthly Goal',
                              style: TextStyle(fontSize: 14),
                            ),
                            value: task.isMonthlyGoal,
                            onChanged: (value) {
                              setState(() => task.isMonthlyGoal = value);
                              widget.onChanged();
                            },
                          ),
                          _buildExtraFieldTile(
                            label: 'Start Time',
                            value: task.startTime,
                            icon: Icons.access_time,
                            onTap: (buttonContext) => _pickExtraTime(
                              buttonContext,
                              (value) => task.startTime = value,
                            ),
                          ),
                          _buildExtraFieldTile(
                            label: 'End Time',
                            value: task.endTime,
                            icon: Icons.access_time,
                            onTap: (buttonContext) => _pickExtraTime(
                              buttonContext,
                              (value) => task.endTime = value,
                            ),
                          ),
                          _buildExtraFieldTile(
                            label: 'Accompanied By',
                            value: task.accompaniedBy,
                            icon: Icons.person_outline,
                            onTap: (buttonContext) => _selectTaskPeople(
                              buttonContext,
                              label: 'Accompanied By',
                              selectedValue: task.accompaniedBy,
                              onChanged: (value) => task.accompaniedBy = value,
                            ),
                          ),
                          _buildExtraFieldTile(
                            label: 'Monitor',
                            value: task.monitor,
                            icon: Icons.desktop_windows_outlined,
                            onTap: (buttonContext) => _selectTaskPeople(
                              buttonContext,
                              label: 'Monitor',
                              selectedValue: task.monitor,
                              onChanged: (value) => task.monitor = value,
                            ),
                          ),
                          _buildOverlayTile(
                            anchorKey: _folderAnchorKey,
                            value: task.folder,
                            icon: Icons.folder_outlined,
                            label: 'Folder',
                            type: FloatingSheetType.folder,
                            fieldKey: 'folder',
                          ),
                          const SizedBox(height: 15),
                          const Text(
                            'Remark',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _noteController,
                            maxLines: 12,
                            onChanged: (value) {
                              task.note = value;
                              task.remark = null;
                              widget.onChanged();
                            },
                            decoration: const InputDecoration(
                              hintText: 'Enter remark',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),

                        // ── Uploaded files ───────────────────────────────
                        TaskFilesSection(
                          task: task,
                          onChanged: widget.onChanged,
                          secondaryColor: secondaryColor,
                        ),

                        const SizedBox(height: 15),

                        // ── Creator & Editor ───────────────────────────────
                        if (task.createdBy != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: FutureBuilder<String?>(
                              future: _createdByNameFuture ??= _dataService
                                  .loadCreatorName(task.createdBy),
                              builder: (context, snapshot) {
                                if (snapshot.hasError) {
                                  debugPrint(
                                    'Could not load task creator name: ${snapshot.error}',
                                  );
                                }
                                final metadataName = _dataService
                                    .metadataCreatorName(task.createdBy);
                                final emailName = _dataService.creatorEmailName(
                                  task.createdBy,
                                );
                                final name =
                                    snapshot.data ??
                                    metadataName ??
                                    emailName ??
                                    'Unknown';
                                return Text(
                                  "Created By: $name",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                );
                              },
                            ),
                          ),
                        if (task.editedBy != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              "Last Edited By: ${task.editedBy!['name'] ?? task.editedBy!['email'] ?? 'Unknown'}",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),

                        const SizedBox(height: 15),
                      ],
                    ), // ListView
                  ), // Scrollbar
                ), // NotificationListener
              ), // Padding
            ), // ConstrainedBox
          ); // Align (return statement)
        }, // LayoutBuilder builder
      ), // LayoutBuilder
    ); // Scaffold
  }
}
