import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 🚀 NAYA: For SystemChannels keyboard show/hide
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';
import '../models/floating_sheet_type.dart';

import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../widgets/app_drawer.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../utils/role_permissions.dart';
import '../../../services/home_screen_shortcut.dart';
import '../../../services/task_home_widget_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.title});

  final String title;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  final TextEditingController taskName = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _taskSearchController = TextEditingController();
  String _searchQuery = '';
  String _taskSearchQuery = '';
  bool _isSearchVisible = false;
  String _sortBy = 'Priority';
  String _groupBy = 'Assignee';
  String _viewType = 'Detailed list';
  double _zoom = 1;
  DateTime _calendarDate = DateTime.now();

  OverlayEntry? _floatingSheetOverlay;

  final List<Task> tasks = [];

  // selected tasks for multi-select
  final Set<Task> _selected = {};

  // temp selections while creating a new task
  String? _newTaskPriority;
  String? _newTaskReminder;
  String? _newTaskAssignee;
  String? _newTaskDeadline;
  String? _newTaskWorkType;
  String? _newTaskFolder;
  String? _newTaskClientName;
  String? _newTaskRefProject; // 🚀 NAYA
  final List<FloatingSheetType> _newTaskMetadataOrder = [];

  // Draggable button order
  final List<FloatingSheetType> _defaultOrder = [
    FloatingSheetType.priority,
    FloatingSheetType.remind,
    FloatingSheetType.assign,
    FloatingSheetType.deadline,
    FloatingSheetType.workType,
    FloatingSheetType.clientName,
    FloatingSheetType.refProject, // 🚀 NAYA
  ];

  late List<FloatingSheetType> _buttonOrder = List.from(_defaultOrder);

  // Firestore collection reference -> MAP collection as requested
  final CollectionReference tasksCollection = FirebaseFirestore.instance
      .collection('map');
  StreamSubscription? _tasksSubscription;
  final Set<Task> _pendingTasks = {};

  bool _isAddingTask = false; // 🚀 NAYA: To prevent double submission
  List<String>? _clientsCache;
  List<String>? _projectsCache; // 🚀 NAYA

  static const Color primaryColor = Color(0xFFFBE64E);
  static const Color secondaryColor = Color(0xFF6B5800);

  late TabController _tabController;
  final Set<String> _expandedMyWorkSections = {};
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadButtonOrder();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenForTaskUpdates();
    });
  }

  String _formatDateTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final date = DateTime(dt.year, dt.month, dt.day);

      final timeStr =
          '${dt.hour % 12 == 0 ? 12 : dt.hour % 12}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}';

      if (date == today) return 'Today $timeStr';
      if (date == tomorrow) return 'Tomorrow $timeStr';
      return '${dt.day}/${dt.month} $timeStr';
    } catch (_) {
      return 'Set';
    }
  }

  String? _newTaskMetadataValue(FloatingSheetType type) {
    return switch (type) {
      FloatingSheetType.priority => _newTaskPriority,
      FloatingSheetType.remind => _newTaskReminder,
      FloatingSheetType.assign => _newTaskAssignee,
      FloatingSheetType.deadline => _newTaskDeadline,
      FloatingSheetType.workType => _newTaskWorkType,
      FloatingSheetType.folder => _newTaskFolder,
      FloatingSheetType.clientName => _newTaskClientName,
      FloatingSheetType.refProject => _newTaskRefProject,
    };
  }

  String _newTaskMetadataLabel(FloatingSheetType type) {
    return switch (type) {
      FloatingSheetType.priority => 'Priority',
      FloatingSheetType.remind => 'Remind Me',
      FloatingSheetType.assign => 'Assign',
      FloatingSheetType.deadline => 'Deadline',
      FloatingSheetType.workType => 'Work Type',
      FloatingSheetType.folder => 'Folder',
      FloatingSheetType.clientName => 'Client Name',
      FloatingSheetType.refProject => 'Ref Project',
    };
  }

  IconData _newTaskMetadataIcon(FloatingSheetType type) {
    return switch (type) {
      FloatingSheetType.priority => Icons.flag_outlined,
      FloatingSheetType.remind => Icons.notifications_active,
      FloatingSheetType.assign => Icons.assignment,
      FloatingSheetType.deadline => Icons.alarm,
      FloatingSheetType.workType => Icons.insert_drive_file,
      FloatingSheetType.folder => Icons.folder_outlined,
      FloatingSheetType.clientName => Icons.business_center_outlined,
      FloatingSheetType.refProject => Icons.apartment_outlined,
    };
  }

  void _setNewTaskMetadata(FloatingSheetType type, String? value) {
    switch (type) {
      case FloatingSheetType.priority:
        _newTaskPriority = value;
        break;
      case FloatingSheetType.remind:
        _newTaskReminder = value;
        break;
      case FloatingSheetType.assign:
        _newTaskAssignee = value;
        break;
      case FloatingSheetType.deadline:
        _newTaskDeadline = value;
        break;
      case FloatingSheetType.workType:
        _newTaskWorkType = value;
        break;
      case FloatingSheetType.folder:
        _newTaskFolder = value;
        break;
      case FloatingSheetType.clientName:
        _newTaskClientName = value;
        break;
      case FloatingSheetType.refProject:
        _newTaskRefProject = value;
        break;
    }

    if (value == null || value.trim().isEmpty) {
      _newTaskMetadataOrder.remove(type);
    } else if (!_newTaskMetadataOrder.contains(type)) {
      _newTaskMetadataOrder.add(type);
    }
  }

  Widget _buildBottomSheetButtonWithState(
    FloatingSheetType type,
    StateSetter setModalState, {
    bool compact = false,
  }) {
    IconData icon = Icons.help_outline;
    String label = "";
    String? selectedValue;
    void Function(String) onSelected = (v) {};
    void Function() onClear = () {};

    switch (type) {
      case FloatingSheetType.priority:
        icon = Icons.flag_outlined;
        label = "Priority";
        selectedValue = _newTaskPriority;
        onSelected = (v) {
          setState(() => _setNewTaskMetadata(type, v));
          setModalState(() {});
        };
        onClear = () {
          setState(() => _setNewTaskMetadata(type, null));
          setModalState(() {});
        };
        break;
      case FloatingSheetType.remind:
        icon = Icons.notifications_active;
        label = "Remind Me";
        selectedValue = _newTaskReminder != null
            ? _formatDateTime(_newTaskReminder!)
            : null;
        onSelected = (v) {
          setState(() => _setNewTaskMetadata(type, v));
          setModalState(() {});
        };
        onClear = () {
          setState(() => _setNewTaskMetadata(type, null));
          setModalState(() {});
        };
        break;
      case FloatingSheetType.assign:
        icon = Icons.assignment;
        label = "Assign";
        selectedValue = _newTaskAssignee;
        onSelected = (v) {
          setState(() {
            final selectedAssignees = (_newTaskAssignee ?? '')
                .split(',')
                .map((name) => name.trim())
                .where((name) => name.isNotEmpty)
                .toList();
            if (!selectedAssignees.any(
              (name) => name.toLowerCase() == v.toLowerCase(),
            )) {
              selectedAssignees.add(v);
            }
            _setNewTaskMetadata(type, selectedAssignees.join(', '));
          });
          setModalState(() {});
        };
        onClear = () {
          setState(() {
            _setNewTaskMetadata(type, null);
          });
          setModalState(() {});
        };
        break;
      case FloatingSheetType.deadline:
        icon = Icons.alarm;
        label = "Deadline";
        selectedValue = _newTaskDeadline != null
            ? _formatDateTime(_newTaskDeadline!)
            : null;
        onSelected = (v) {
          setState(() => _setNewTaskMetadata(type, v));
          setModalState(() {});
        };
        onClear = () {
          setState(() => _setNewTaskMetadata(type, null));
          setModalState(() {});
        };
        break;
      case FloatingSheetType.workType:
        icon = Icons.insert_drive_file;
        label = "Work Type";
        selectedValue = _newTaskWorkType;
        onSelected = (v) {
          setState(() => _setNewTaskMetadata(type, v));
          setModalState(() {});
        };
        onClear = () {
          setState(() => _setNewTaskMetadata(type, null));
          setModalState(() {});
        };
        break;
      case FloatingSheetType.folder:
        icon = Icons.folder_outlined;
        label = "Folder";
        selectedValue = _newTaskFolder;
        onSelected = (v) {
          setState(() => _setNewTaskMetadata(type, v));
          setModalState(() {});
        };
        onClear = () {
          setState(() => _setNewTaskMetadata(type, null));
          setModalState(() {});
        };
        break;
      case FloatingSheetType.clientName:
        icon = Icons.business_center_outlined;
        label = "Client Name";
        selectedValue = _newTaskClientName;
        onSelected = (v) {
          setState(() => _setNewTaskMetadata(type, v));
          setModalState(() {});
        };
        onClear = () {
          setState(() => _setNewTaskMetadata(type, null));
          setModalState(() {});
        };
        break;
      case FloatingSheetType.refProject:
        icon = Icons.apartment_outlined;
        label = "Ref Project";
        selectedValue = _newTaskRefProject;
        onSelected = (v) {
          setState(() => _setNewTaskMetadata(type, v));
          setModalState(() {});
        };
        onClear = () {
          setState(() => _setNewTaskMetadata(type, null));
          setModalState(() {});
        };
        break;
    }

    final bool isSelected = selectedValue != null && selectedValue.isNotEmpty;
    final String displayText = isSelected ? selectedValue : label;

    return Builder(
      builder: (buttonContext) => AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: compact ? 112 : null,
          decoration: BoxDecoration(
            color: isSelected
                ? primaryColor.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? secondaryColor : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                final isMulti = type == FloatingSheetType.assign;
                List<String> currentSelections = [];
                if (isMulti && _newTaskAssignee != null) {
                  currentSelections = _newTaskAssignee!
                      .split(',')
                      .map((e) => e.trim())
                      .toList();
                }

                _showFloatingSheet(
                  buttonContext,
                  type,
                  onSelected: onSelected,
                  multiSelect: isMulti,
                  selectedValues: currentSelections,
                );
              },
              child: Padding(
                padding: compact
                    ? const EdgeInsets.symmetric(horizontal: 4, vertical: 4)
                    : const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
                child: compact
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icon,
                                size: 17,
                                color: isSelected
                                    ? secondaryColor
                                    : Colors.grey.shade700,
                              ),
                              if (isSelected)
                                GestureDetector(
                                  onTap: onClear,
                                  child: const Icon(
                                    Icons.close,
                                    size: 12,
                                    color: secondaryColor,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            displayText,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isSelected
                                  ? secondaryColor
                                  : Colors.grey.shade700,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              fontSize: 12,
                              height: 1.15,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, animation) {
                              return ScaleTransition(
                                scale: animation,
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              );
                            },
                            child: Icon(
                              icon,
                              key: ValueKey('icon_$isSelected'),
                              size: 18,
                              color: isSelected
                                  ? secondaryColor
                                  : Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, animation) {
                              return SizeTransition(
                                sizeFactor: animation,
                                axis: Axis.horizontal,
                                axisAlignment: -1,
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              );
                            },
                            child: Text(
                              displayText,
                              key: ValueKey('text_$displayText'),
                              style: TextStyle(
                                color: isSelected
                                    ? secondaryColor
                                    : Colors.grey.shade700,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: isSelected ? 24 : 0,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 300),
                              opacity: isSelected ? 1.0 : 0.0,
                              child: isSelected
                                  ? GestureDetector(
                                      onTap: () {
                                        onClear();
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.only(left: 8),
                                        child: Icon(
                                          Icons.close,
                                          size: 16,
                                          color: secondaryColor,
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _myWorkSectionColor(String section) {
    switch (section) {
      case 'Urgent Works':
        return const Color(0xFF9B5965);
      case 'IMP Works':
        return const Color(0xFF526D8A);
      case 'Today Works':
      case 'Tomorrow Works':
        return const Color(0xFF557E9B);
      case 'Hold Works':
        return const Color(0xFF99765B);
      case 'Done Works':
        return const Color(0xFF708276);
      default:
        return const Color(0xFF71808D);
    }
  }

  @override
  void dispose() {
    _tasksSubscription?.cancel();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _hideFloatingSheet();
    _focusNode.dispose();
    taskName.dispose();
    _searchController.dispose();
    _taskSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadButtonOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('map_button_order');

    if (!mounted) return;

    setState(() {
      if (saved == null) {
        _buttonOrder = List.from(_defaultOrder);
        return;
      }

      _buttonOrder = saved
          .map(
            (e) => FloatingSheetType.values.firstWhere(
              (v) => v.name == e,
              orElse: () => _defaultOrder.first,
            ),
          )
          .where((type) => type != FloatingSheetType.folder)
          .toList();
    });
  }

  Future<DateTime?> pickDateTimeWithTabs(
    BuildContext context, {
    DateTime? initial,
  }) async {
    DateTime selectedDate = initial ?? DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(initial ?? DateTime.now());

    int tabIndex = 0;

    return showDialog<DateTime>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: SizedBox(
                height: 430,
                child: Column(
                  children: [
                    Row(
                      children: [
                        _tabButton(
                          title: "DATE",
                          selected: tabIndex == 0,
                          onTap: () => setState(() => tabIndex = 0),
                        ),
                        _tabButton(
                          title: "TIME",
                          selected: tabIndex == 1,
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                            );
                            if (picked != null) {
                              selectedTime = picked;
                              setState(() => tabIndex = 1);
                            }
                          },
                        ),
                      ],
                    ),
                    Expanded(
                      child: tabIndex == 0
                          ? CalendarDatePicker(
                              initialDate: selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              onDateChanged: (date) {
                                selectedDate = date;
                              },
                            )
                          : Center(
                              child: Text(
                                selectedTime.format(context),
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("CANCEL"),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                            ),
                            onPressed: () {
                              final result = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                selectedTime.hour,
                                selectedTime.minute,
                              );
                              Navigator.pop(context, result);
                            },
                            child: const Text(
                              "SAVE",
                              style: TextStyle(color: secondaryColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _tabButton({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? secondaryColor : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? secondaryColor : Colors.black54,
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isTaskVisibleToUser(Task task, AuthViewModel authVM) {
    if (authVM.appRole == AppRole.superAdmin ||
        authVM.appRole == AppRole.admin ||
        authVM.appRole == AppRole.officeStaff) {
      return true;
    }
    final String myUid = authVM.userUid.trim().toLowerCase();
    final String myEmail = authVM.userEmail.trim().toLowerCase();
    final String myName = authVM.userName.trim().toLowerCase();

    final cb = task.createdBy;
    if (cb != null) {
      final cbUid = (cb['uid'] ?? '').toString().trim().toLowerCase();
      final cbEmail = (cb['email'] ?? '').toString().trim().toLowerCase();
      final cbName = (cb['name'] ?? '').toString().trim().toLowerCase();
      if ((cbUid.isNotEmpty && (cbUid == myUid || myUid.contains(cbUid))) ||
          (cbEmail.isNotEmpty &&
              (cbEmail == myEmail || myEmail.contains(cbEmail))) ||
          (cbName.isNotEmpty &&
              (cbName == myName || myName.contains(cbName)))) {
        return true;
      }
    }

    final assignee = (task.assignee ?? '').toString().trim().toLowerCase();
    if (assignee.isNotEmpty) {
      if ((myName.isNotEmpty && assignee.contains(myName)) ||
          (myEmail.isNotEmpty && assignee.contains(myEmail)) ||
          (myUid.isNotEmpty && assignee.contains(myUid))) {
        return true;
      }
    }

    return false;
  }

  Future<void> _loadTasksFromFirebase() async {
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    final snapshot = await tasksCollection.get();

    final loaded = snapshot.docs
        .map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return Task.fromMap(doc.id, data);
        })
        .where((task) => _isTaskVisibleToUser(task, authVM))
        .toList();

    if (!mounted) return;
    _replaceTasks(loaded);
    await updateTaskHomeWidget(tasks);
  }

  void _listenForTaskUpdates() {
    _tasksSubscription = tasksCollection.snapshots().listen(
      (snapshot) {
        if (!mounted) return;
        final authVM = Provider.of<AuthViewModel>(context, listen: false);
        final loaded = snapshot.docs
            .map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return Task.fromMap(doc.id, data);
            })
            .where((task) => _isTaskVisibleToUser(task, authVM))
            .toList();

        _replaceTasks(loaded);
        unawaited(_updateTaskHomeWidgetSafely());
      },
      onError: (Object error) {
        debugPrint('Error listening for task updates: $error');
        if (mounted) {
          _showMessage('Could not sync tasks. Pull down to refresh.');
        }
      },
    );
  }

  void _replaceTasks(List<Task> loaded) {
    loaded.sort(_taskComparator);
    final loadedIds = loaded.map((task) => task.id).toSet();
    final pending = _pendingTasks
        .where((task) => task.id == null || !loadedIds.contains(task.id))
        .toList();

    setState(() {
      tasks
        ..clear()
        ..addAll(loaded)
        ..addAll(pending);
      _sortTasks();
    });
  }

  Future<void> _updateTaskHomeWidgetSafely() async {
    try {
      await updateTaskHomeWidget(tasks);
    } catch (error) {
      debugPrint('Error updating task home widget: $error');
    }
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging ||
        _selectedTabIndex == _tabController.index) {
      return;
    }
    setState(() => _selectedTabIndex = _tabController.index);
  }

  Future<void> _refreshTasks() async {
    try {
      await _loadTasksFromFirebase();
    } on FirebaseException catch (error) {
      if (!mounted) return;
      _showMessage(error.message ?? 'Could not refresh tasks.');
    }
  }

  Widget _refreshableScrollView(Widget child) => RefreshIndicator(
    onRefresh: _refreshTasks,
    child: Scrollbar(thumbVisibility: kIsWeb, child: child),
  );

  Map<String, dynamic> _taskData(Task task) {
    final data = task.toMap();
    final reminderDate = task.reminder == null
        ? null
        : DateTime.tryParse(task.reminder!);
    final deadlineDate = task.deadline == null
        ? null
        : DateTime.tryParse(task.deadline!);

    data['reminderAt'] = reminderDate == null
        ? null
        : Timestamp.fromDate(reminderDate);
    data['deadlineAt'] = deadlineDate == null
        ? null
        : Timestamp.fromDate(deadlineDate);
    return data;
  }

  Future<void> _addTaskToFirebase(Task task) async {
    final docRef = tasksCollection.doc();
    task.id = docRef.id;
    await docRef.set(_taskData(task));
  }

  Future<void> _updateTaskInFirebase(Task task) async {
    if (task.id == null) return;
    await tasksCollection.doc(task.id).update(_taskData(task));
    await updateTaskHomeWidget(tasks);
  }

  Future<void> _deleteTaskFromFirebase(Task task) async {
    if (task.id == null) return;
    await tasksCollection.doc(task.id).delete();
  }

  Future<bool> _handleAddTaskFromSheet() async {
    if (_isAddingTask) return false; // 🚀 NAYA: Prevent multiple triggers

    final text = taskName.text.trim();
    if (text.isEmpty) return false;

    setState(() {
      _isAddingTask = true;
    });

    // Capture states
    final priority = _newTaskPriority;
    final reminder = _newTaskReminder;
    final assignee = _newTaskAssignee;
    final deadline = _newTaskDeadline;
    final workType = _newTaskWorkType;
    final folder = _newTaskFolder;
    final clientName = _newTaskClientName;
    final refProject = _newTaskRefProject;

    // Immediately clear input fields to prevent double entry
    taskName.clear();
    setState(() {
      _newTaskPriority = null;
      _newTaskReminder = null;
      _newTaskAssignee = null;
      _newTaskDeadline = null;
      _newTaskWorkType = null;
      _newTaskFolder = null;
      _newTaskClientName = null;
      _newTaskRefProject = null;
      _newTaskMetadataOrder.clear();
    });

    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final newTask = Task(
      text,
      priority: priority,
      reminder: reminder,
      reminderSent: false,
      deadlineReminderSent: false,
      assignee: assignee,
      deadline: deadline,
      workType: workType,
      folder: folder,
      clientName: clientName,
      refProject: refProject,
      createdBy: authVM.actorMetadata,
      assigneeUid: assignee,
      priorityUpdatedAt: priority != null ? nowMs : null,
    );

    if (_isTaskVisibleToUser(newTask, authVM)) {
      _pendingTasks.add(newTask);
      setState(() {
        tasks.add(newTask);
        _sortTasks();
      });
    }

    if (assignee != null && assignee.trim().isNotEmpty) {
      unawaited(_sendTaskAssignmentNotification(assignee, text, authVM));
    }
    unawaited(_saveNewTask(newTask));

    setState(() {
      _isAddingTask = false;
    });
    _focusNode.requestFocus();
    return true;
  }

  Future<void> _saveNewTask(Task task) async {
    try {
      await _addTaskToFirebase(task);
    } catch (error) {
      debugPrint('Error adding task: $error');
      if (mounted) {
        _pendingTasks.remove(task);
        setState(() {
          tasks.removeWhere(
            (existingTask) =>
                identical(existingTask, task) || existingTask.id == task.id,
          );
          _sortTasks();
        });
        _showMessage('Could not send "${task.title}". Please try again.');
      }
      return;
    }

    _pendingTasks.remove(task);
    await _updateTaskHomeWidgetSafely();
  }

  Future<void> _sendTaskAssignmentNotification(
    String? assignee,
    String taskTitle,
    AuthViewModel authVM,
  ) async {
    if (assignee == null ||
        assignee.trim().isEmpty ||
        !authVM.allowNotifications) {
      return;
    }
    final String cleanAssignee = assignee.trim().toLowerCase();
    final String myName = authVM.userName.trim().toLowerCase();

    if (cleanAssignee == myName ||
        cleanAssignee == authVM.userUid.toLowerCase() ||
        cleanAssignee == authVM.userEmail.toLowerCase()) {
      return;
    }

    try {
      String? targetFcmToken;

      // Look up FCM token in 'users' collection first
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('name', isEqualTo: assignee.trim())
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        targetFcmToken = userQuery.docs.first.data()['fcmToken']?.toString();
      } else {
        // Fallback: look up in 'cps' collection
        final cpQuery = await FirebaseFirestore.instance
            .collection('cps')
            .where('cpName', isEqualTo: assignee.trim())
            .limit(1)
            .get();
        if (cpQuery.docs.isNotEmpty) {
          targetFcmToken = cpQuery.docs.first.data()['fcmToken']?.toString();
        }
      }

      await FirebaseFirestore.instance.collection('notifications').add({
        'recipientName': assignee.trim(),
        'recipientFcmToken':
            targetFcmToken, // 🚀 NAYA: FCM Token for background push
        'title': 'New Task Assigned',
        'body': '${authVM.userName} assigned you a task: "$taskTitle"',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': 'task_assigned',
      });
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  int _priorityOrder(String? p) {
    switch (p) {
      case 'U1':
        return 1;
      case 'U2':
        return 2;
      case 'U3':
        return 3;
      case 'Urgent':
        return 4;
      case 'IMP':
        return 5;
      case 'Today':
        return 6;
      case 'Tomorrow':
        return 7;
      case 'Day Later':
        return 8;
      case 'Later':
        return 9;
      case 'Process':
        return 10;
      case 'Hold':
        return 11;
      case 'Free':
        return 12;
      default:
        return 100;
    }
  }

  int _taskComparator(Task a, Task b) {
    if (a.isDone != b.isDone) {
      return a.isDone ? 1 : -1;
    }

    final pa = _priorityOrder(a.priority);
    final pb = _priorityOrder(b.priority);

    if (pa != pb) {
      return pa.compareTo(pb);
    }
    final ta = a.priorityUpdatedAt ?? 0;
    final tb = b.priorityUpdatedAt ?? 0;

    return tb.compareTo(ta);
  }

  void _sortTasks() {
    tasks.sort(_taskComparator);
  }

  Future<List<String>> _loadClientsFromFirestore() async {
    if (_clientsCache != null) return _clientsCache!;
    final snap = await FirebaseFirestore.instance.collection('leads').get();
    final values = snap.docs
        .map((d) {
          final data = d.data();
          final name = data['name']?.toString().trim() ?? '';
          final surname = data['surname']?.toString().trim() ?? '';
          return surname.isNotEmpty ? '$name $surname' : name;
        })
        .where((e) => e.isNotEmpty)
        .toList();
    _clientsCache = values;
    return values;
  }

  Future<List<String>> _loadAssigneesFromFirestore() async {
    final snapshots = await Future.wait([
      FirebaseFirestore.instance.collection('users').get(),
      FirebaseFirestore.instance.collection('cps').get(),
    ]);
    final valuesByName = <String, String>{};

    void addName(Object? value) {
      final name = value?.toString().trim() ?? '';
      if (name.isNotEmpty) {
        valuesByName.putIfAbsent(name.toLowerCase(), () => name);
      }
    }

    for (final doc in snapshots[0].docs) {
      final data = doc.data();
      addName(data['name'] ?? data['fullName'] ?? data['email']);
    }
    for (final doc in snapshots[1].docs) {
      final data = doc.data();
      addName(
        data['cpName'] ?? data['name'] ?? data['fullName'] ?? data['email'],
      );
    }

    final values = valuesByName.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  void _hideFloatingSheet() {
    if (_floatingSheetOverlay != null) {
      _floatingSheetOverlay!.remove();
      _floatingSheetOverlay = null;
    }
    _searchController.clear();
    _searchQuery = '';
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _showFloatingSheet(
    BuildContext buttonContext,
    FloatingSheetType type, {
    void Function(String)? onSelected,
    bool multiSelect = false,
    List<String>? selectedValues,
  }) async {
    if (_floatingSheetOverlay != null && !multiSelect) {
      _hideFloatingSheet();
    }

    // ... logic for fetching types ...
    List<String>? workTypes;
    if (type == FloatingSheetType.workType) {
      final snap = await FirebaseFirestore.instance
          .collection('WorkType')
          .get();
      workTypes = snap.docs
          .map((d) => d['workType']?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }
    List<String>? clients;
    if (type == FloatingSheetType.clientName) {
      clients = await _loadClientsFromFirestore();
    }

    List<String>? projects;
    if (type == FloatingSheetType.refProject) {
      if (_projectsCache != null) {
        projects = _projectsCache;
      } else {
        final snap = await FirebaseFirestore.instance
            .collection('projects')
            .get();
        _projectsCache = snap.docs
            .map((d) => d['projectName']?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList();
        projects = _projectsCache;
      }
    }

    final BuildContext rootContext = Navigator.of(
      buttonContext,
      rootNavigator: true,
    ).context;

    List<String>? assignees;
    if (type == FloatingSheetType.assign) {
      assignees = await _loadAssigneesFromFirestore();
    }

    final RenderBox button = buttonContext.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(buttonContext).context.findRenderObject() as RenderBox;
    final Offset buttonPosition = button.localToGlobal(
      Offset.zero,
      ancestor: overlay,
    );
    final Size overlaySize = overlay.size;

    List<Widget> buildOptions(StateSetter? setOverlayState) {
      List<String> options = [];
      switch (type) {
        case FloatingSheetType.priority:
          options = [
            "U1",
            "U2",
            "U3",
            "Urgent",
            "IMP",
            "Today",
            "Tomorrow",
            "Day Later",
            "Later",
            "Process",
            "Hold",
            "Free",
          ];
          break;
        case FloatingSheetType.remind:
        case FloatingSheetType.deadline:
          options = [
            "Today (1 hour)",
            "Today (3 hour)",
            "Today (6 hour)",
            "Tomorrow (12 pm)",
            "Custom",
          ];
          break;
        case FloatingSheetType.assign:
          options = assignees ?? [];
          break;
        case FloatingSheetType.workType:
          options =
              workTypes ??
              [
                "Call",
                "Message",
                "WhatsApp",
                "1st Visit",
                "Revisit",
                "Follow Up Call",
                "Others",
              ];
          break;
        case FloatingSheetType.folder:
          options = ["Personal", "Office", "Freelance", "Custom"];
          break;
        case FloatingSheetType.clientName:
          options = clients ?? [];
          break;
        case FloatingSheetType.refProject:
          options = projects ?? [];
          break;
      }

      return options.map((opt) {
        final bool isSelected = selectedValues?.contains(opt) ?? false;
        return ListTile(
          dense: true,
          leading:
              type == FloatingSheetType.priority ||
                  type == FloatingSheetType.remind ||
                  type == FloatingSheetType.deadline
              ? Icon(
                  type == FloatingSheetType.priority
                      ? Icons.flag
                      : Icons.access_time,
                  size: 18,
                )
              : null,
          title: Text(
            opt,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? secondaryColor : Colors.black87,
            ),
          ),
          trailing: isSelected
              ? const Icon(Icons.check, size: 16, color: secondaryColor)
              : null,
          onTap: () async {
            final now = DateTime.now();
            final lower = opt.toLowerCase();
            String finalVal = opt;

            if (type == FloatingSheetType.remind ||
                type == FloatingSheetType.deadline) {
              DateTime? computed;
              if (lower.contains('custom')) {
                if (!multiSelect) _hideFloatingSheet();
                computed = await pickDateTimeWithTabs(rootContext);
              } else if (lower.contains('1 hour'))
                computed = now.add(const Duration(hours: 1));
              else if (lower.contains('3 hour'))
                computed = now.add(const Duration(hours: 3));
              else if (lower.contains('6 hour'))
                computed = now.add(const Duration(hours: 6));
              else if (lower.contains('tomorrow')) {
                final t = DateTime(
                  now.year,
                  now.month,
                  now.day,
                ).add(const Duration(days: 1));
                computed = DateTime(t.year, t.month, t.day, 12, 0);
              }
              if (computed != null) {
                finalVal = computed.toIso8601String();
              } else if (lower.contains('custom'))
                return; // Cancelled
            }

            if (onSelected != null) onSelected(finalVal);

            if (!multiSelect) {
              _searchController.clear();
              _searchQuery = '';
              _hideFloatingSheet();
            } else {
              if (setOverlayState != null) setOverlayState(() {});
            }
          },
        );
      }).toList();
    }

    const double padding = 8;
    final double menuWidth = (overlaySize.width - padding * 2).clamp(
      0.0,
      240.0,
    );
    final desiredMenuHeight = (overlaySize.height - padding * 2)
        .clamp(0.0, 400.0)
        .toDouble();
    final spaceAbove = (buttonPosition.dy - padding).clamp(
      0.0,
      desiredMenuHeight,
    );
    final spaceBelow =
        (overlaySize.height - buttonPosition.dy - button.size.height - padding)
            .clamp(0.0, desiredMenuHeight);
    final openAbove = spaceAbove >= spaceBelow;
    final menuMaxHeight = openAbove ? spaceAbove : spaceBelow;
    final top = openAbove
        ? buttonPosition.dy - menuMaxHeight
        : buttonPosition.dy + button.size.height + padding;

    _hideFloatingSheet();
    _floatingSheetOverlay = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _hideFloatingSheet,
              behavior: HitTestBehavior.translucent,
            ),
          ),
          Positioned(
            right: padding,
            top: top,
            child: Material(
              color: Colors.white,
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: menuWidth,
                child: StatefulBuilder(
                  builder: (context, setOverlayState) {
                    final bool showSearch =
                        type == FloatingSheetType.assign ||
                        type == FloatingSheetType.workType ||
                        type == FloatingSheetType.clientName ||
                        type == FloatingSheetType.refProject;
                    final optionListHeight =
                        (menuMaxHeight -
                                (showSearch ? 68 : 0) -
                                (multiSelect ? 64 : 0))
                            .clamp(40.0, 250.0)
                            .toDouble();
                    final allOptions = buildOptions(setOverlayState);
                    final filteredOptions =
                        showSearch && _searchQuery.isNotEmpty
                        ? allOptions
                              .where(
                                (tile) => ((tile as ListTile).title as Text)
                                    .data!
                                    .toLowerCase()
                                    .contains(_searchQuery.toLowerCase()),
                              )
                              .toList()
                        : allOptions;

                    return ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: menuMaxHeight),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showSearch)
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: TextField(
                                controller: _searchController,
                                autofocus: true,
                                decoration: InputDecoration(
                                  hintText: 'Search...',
                                  hintStyle: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade400,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search,
                                    size: 18,
                                    color: Colors.grey.shade50,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.grey.shade100,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                onChanged: (val) {
                                  _searchQuery = val;
                                  setOverlayState(() {});
                                },
                              ),
                            ),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: optionListHeight,
                            ),
                            child: filteredOptions.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text(
                                      'No results',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  )
                                : ListView(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    children: filteredOptions,
                                  ),
                          ),
                          if (multiSelect)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: secondaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: _hideFloatingSheet,
                                  child: const Text(
                                    'Done',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(buttonContext).insert(_floatingSheetOverlay!);
  }

  Widget _thinHairline({
    double indent = 12,
    double endIndent = 12,
    double opacity = 0.06,
  }) {
    final int alpha = (opacity.clamp(0.0, 1.0) * 255).round();
    return Container(
      height: 1,
      margin: EdgeInsets.only(left: indent, right: endIndent),
      color: Colors.grey.withAlpha(alpha),
    );
  }

  Future<void> _showTaskSymbolHelp(BuildContext context) {
    const shortcuts = <(String, String, String)>[
      ('@', 'Assign', 'Type @ to find and assign a person.'),
      ('-', 'Priority', 'Type - to choose a priority.'),
      ('!', 'Deadline', 'Type ! to set a deadline.'),
      ('*', 'Remind Me', 'Type * to set a reminder.'),
      ('+', 'Work Type', 'Type + to choose a work type.'),
      ('#', 'Client Name', 'Type # to choose a client.'),
      ('^', 'Ref Project', 'Type ^ to choose a reference project.'),
    ];

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Task shortcuts'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (symbol, title, description) in shortcuts)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: SizedBox(
                    width: 28,
                    child: Text(
                      symbol,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(title),
                  subtitle: Text(description),
                ),
              const ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: SizedBox(
                  width: 28,
                  child: Icon(Icons.folder_outlined, size: 20),
                ),
                title: Text('Folder'),
                subtitle: Text('Folder does not have a text shortcut symbol.'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _openAddTaskSheet() {
    var initialComposerFocusScheduled = false;
    String? assigneeMentionQuery;
    String assigneeMentionSourceText = '';
    int assigneeMentionStart = -1;
    int assigneeMentionEnd = -1;
    int highlightedAssigneeIndex = 0;
    int metadataTokenStart = -1;

    String mentionSymbol = '@';
    const priorityOptions = [
      "U1",
      "U2",
      "U3",
      "Urgent",
      "IMP",
      "Today",
      "Tomorrow",
      "Day Later",
      "Later",
      "Process",
      "Hold",
      "Free",
    ];
    List<String>? assigneeOptions;
    Future<List<String>>? assigneeOptionsFuture;

    ({int start, String symbol, String query})? parseMention(
      String text,
      int cursor,
    ) {
      final c = cursor.clamp(0, text.length);
      for (var i = c - 1; i >= 0; i--) {
        final ch = text[i];
        if (RegExp(r'\s').hasMatch(ch)) return null;
        if (ch == '@' || ch == '-') {
          if (i == 0 || RegExp(r'\s').hasMatch(text[i - 1])) {
            return (start: i, symbol: ch, query: text.substring(i + 1, c));
          }
          return null;
        }
      }
      return null;
    }

    Future<List<String>> mentionOptions(String symbol, String query) async {
      final q = query.toLowerCase();
      if (symbol == '-') {
        return priorityOptions
            .where((n) => n.toLowerCase().startsWith(q))
            .toList();
      }
      assigneeOptions ??= await (assigneeOptionsFuture ??=
          _loadAssigneesFromFirestore());
      return assigneeOptions!
          .where((n) => n.toLowerCase().startsWith(q) && n.toLowerCase() != q)
          .toList();
    }

    void removeMetadataTokenFromTaskName() {
      if (metadataTokenStart < 0 ||
          metadataTokenStart >= taskName.text.length) {
        return;
      }

      final currentText = taskName.text;
      var tokenEnd = metadataTokenStart + 1;
      while (tokenEnd < currentText.length &&
          !RegExp(r'\s').hasMatch(currentText[tokenEnd])) {
        tokenEnd++;
      }

      final beforeToken = currentText.substring(0, metadataTokenStart);
      final afterToken = currentText.substring(tokenEnd);
      final beforeEndsWithWhitespace =
          beforeToken.isNotEmpty &&
          RegExp(r'\s').hasMatch(beforeToken[beforeToken.length - 1]);
      final afterStartsWithWhitespace =
          afterToken.isNotEmpty && RegExp(r'\s').hasMatch(afterToken[0]);
      final separator =
          beforeToken.isNotEmpty &&
              afterToken.isNotEmpty &&
              !beforeEndsWithWhitespace &&
              !afterStartsWithWhitespace
          ? ' '
          : '';

      metadataTokenStart = -1;
      taskName.value = TextEditingValue(
        text: '$beforeToken$separator$afterToken',
        selection: TextSelection.collapsed(
          offset: beforeToken.length + separator.length,
        ),
      );
    }

    Future<void> completeMention(
      String opt,
      StateSetter setModalState, {
      String? sourceText,
    }) async {
      final assignee = opt;
      final symbol = mentionSymbol;

      final currentText = sourceText ?? taskName.text;
      var endOfMention = assigneeMentionEnd;
      while (endOfMention < currentText.length &&
          !RegExp(r'\s').hasMatch(currentText[endOfMention])) {
        endOfMention++;
      }
      final beforeMention = currentText
          .substring(0, assigneeMentionStart)
          .trimRight();
      final afterMention = currentText.substring(endOfMention).trimLeft();

      setModalState(() {
        assigneeMentionQuery = null;
        assigneeMentionStart = -1;
        assigneeMentionEnd = -1;
      });
      _focusNode.requestFocus();

      final hasTextBefore = beforeMention.isNotEmpty;
      final hasTextAfter = afterMention.isNotEmpty;
      final updatedText = hasTextBefore && hasTextAfter
          ? '$beforeMention $afterMention'
          : hasTextBefore
          ? beforeMention
          : hasTextAfter
          ? afterMention
          : '';
      final cursorOffset = hasTextBefore
          ? beforeMention.length + (hasTextAfter ? 1 : 0)
          : 0;
      taskName.value = TextEditingValue(
        text: updatedText,
        selection: TextSelection.collapsed(offset: cursorOffset),
      );

      if (!mounted) return;
      setState(() {
        if (symbol == '-') {
          _setNewTaskMetadata(FloatingSheetType.priority, assignee);
        } else {
          final selectedAssignees = (_newTaskAssignee ?? '')
              .split(',')
              .map((name) => name.trim())
              .where((name) => name.isNotEmpty)
              .toList();
          if (!selectedAssignees.any(
            (name) => name.toLowerCase() == assignee.toLowerCase(),
          )) {
            selectedAssignees.add(assignee);
          }
          _setNewTaskMetadata(
            FloatingSheetType.assign,
            selectedAssignees.join(', '),
          );
        }
      });
      setModalState(() {});
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      isDismissible: true,
      enableDrag: true, // 🚀 NAYA: Enabled for all platforms
      showDragHandle: true, // 🚀 NAYA: Shows the handle for better UX
      backgroundColor: Colors.white,
      constraints: kIsWeb
          ? BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85)
          : null,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final viewInsets = MediaQuery.of(sheetContext).viewInsets;
          final screenWidth = MediaQuery.of(sheetContext).size.width;
          final mobileButtonOrder = [
            ..._buttonOrder.where(
              (type) => type != FloatingSheetType.refProject,
            ),
            FloatingSheetType.refProject,
          ];
          final availableButtonOrder = mobileButtonOrder.where((type) {
            final value = _newTaskMetadataValue(type);
            return value == null || value.isEmpty;
          }).toList();
          final systemNavBar = MediaQuery.of(sheetContext).padding.bottom;
          final bottomPadding = kIsWeb
              ? 16.0
              : (16.0 + viewInsets.bottom + systemNavBar);

          if (!initialComposerFocusScheduled) {
            initialComposerFocusScheduled = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted &&
                  sheetContext.mounted &&
                  _focusNode.canRequestFocus) {
                _focusNode.requestFocus();
              }
            });
          }

          return PopScope<Object?>(
            canPop: true,
            onPopInvokedWithResult: (didPop, result) {
              _hideFloatingSheet();
              _focusNode.unfocus();
              FocusScope.of(context).unfocus();
              if (!kIsWeb) {
                SystemChannels.textInput.invokeMethod('textInput.hide');
              }
            },
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(), // 🚀 NAYA: Better for bottom sheets
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: bottomPadding,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_newTaskMetadataOrder.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: _newTaskMetadataOrder
                                .map((type) {
                                  final value = _newTaskMetadataValue(type);
                                  if (value == null || value.isEmpty) {
                                    return null;
                                  }
                                  final displayValue =
                                      type == FloatingSheetType.remind ||
                                          type == FloatingSheetType.deadline
                                      ? _formatDateTime(value)
                                      : value;
                                  return InputChip(
                                    avatar: Icon(
                                      _newTaskMetadataIcon(type),
                                      size: 16,
                                      color: secondaryColor,
                                    ),
                                    label: Text(
                                      '${_newTaskMetadataLabel(type)}: $displayValue',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onDeleted: () {
                                      setState(
                                        () => _setNewTaskMetadata(type, null),
                                      );
                                      setModalState(() {});
                                    },
                                    backgroundColor: primaryColor.withValues(
                                      alpha: 0.2,
                                    ),
                                    side: BorderSide(
                                      color: secondaryColor.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                  );
                                })
                                .whereType<Widget>()
                                .toList(),
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: Builder(
                            builder: (textFieldCtx) => Focus(
                              onKeyEvent: (node, event) {
                                if (event is! KeyDownEvent ||
                                    event.logicalKey !=
                                        LogicalKeyboardKey.tab ||
                                    assigneeMentionQuery == null) {
                                  return KeyEventResult.ignored;
                                }

                                final query = assigneeMentionQuery!
                                    .toLowerCase();
                                final source = mentionSymbol == '-'
                                    ? priorityOptions
                                    : assigneeOptions;
                                if (source == null)
                                  return KeyEventResult.ignored;
                                final matches = source
                                    .where(
                                      (n) =>
                                          n.toLowerCase().startsWith(query) &&
                                          (mentionSymbol == '-' ||
                                              n.toLowerCase() != query),
                                    )
                                    .toList();
                                if (matches.isEmpty) {
                                  return KeyEventResult.ignored;
                                }

                                final index = highlightedAssigneeIndex
                                    .clamp(0, matches.length - 1)
                                    .toInt();
                                completeMention(
                                  matches[index],
                                  setModalState,
                                  sourceText: assigneeMentionSourceText,
                                );
                                return KeyEventResult.handled;
                              },
                              child: RawAutocomplete<String>(
                                textEditingController: taskName,
                                focusNode: _focusNode,
                                optionsViewOpenDirection:
                                    OptionsViewOpenDirection.up,
                                optionsBuilder: (value) async {
                                  final m = parseMention(
                                    value.text,
                                    value.selection.extentOffset,
                                  );
                                  if (m == null) {
                                    return const <String>[];
                                  }
                                  try {
                                    return await mentionOptions(
                                      m.symbol,
                                      m.query,
                                    );
                                  } catch (error) {
                                    if (sheetContext.mounted) {
                                      ScaffoldMessenger.of(
                                        sheetContext,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Could not load options: $error',
                                          ),
                                        ),
                                      );
                                    }
                                    return const <String>[];
                                  }
                                },
                                onSelected: (opt) => completeMention(
                                  opt,
                                  setModalState,
                                  sourceText: assigneeMentionSourceText,
                                ),
                                optionsViewBuilder: (context, onSelected, options) {
                                  final matches = options.toList();
                                  final highlightedIndex =
                                      AutocompleteHighlightedOption.of(context);
                                  highlightedAssigneeIndex = highlightedIndex;
                                  return LayoutBuilder(
                                    builder: (context, constraints) {
                                      final availableHeight =
                                          constraints.hasBoundedHeight
                                          ? constraints.maxHeight
                                          : 260.0;
                                      final popupHeight = availableHeight
                                          .clamp(0.0, 210.0)
                                          .toDouble();
                                      const doneAreaHeight = 56.0;
                                      final showDone =
                                          popupHeight >= doneAreaHeight;
                                      final listHeight =
                                          (popupHeight -
                                                  (showDone
                                                      ? doneAreaHeight
                                                      : 0))
                                              .clamp(0.0, 154.0)
                                              .toDouble();

                                      return Align(
                                        alignment: Alignment.bottomRight,
                                        child: Material(
                                          elevation: 8,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: SizedBox(
                                            width: 240,
                                            child: ConstrainedBox(
                                              constraints: BoxConstraints(
                                                maxHeight: popupHeight,
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  ConstrainedBox(
                                                    constraints: BoxConstraints(
                                                      maxHeight: listHeight,
                                                    ),
                                                    child: ListView.builder(
                                                      padding: EdgeInsets.zero,
                                                      shrinkWrap: true,
                                                      itemCount: matches.length,
                                                      itemBuilder: (context, index) {
                                                        final name =
                                                            matches[index];
                                                        return ListTile(
                                                          dense: true,
                                                          selected:
                                                              index ==
                                                              highlightedIndex,
                                                          selectedTileColor:
                                                              primaryColor
                                                                  .withValues(
                                                                    alpha: 0.45,
                                                                  ),
                                                          title: Text(
                                                            name,
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 13,
                                                                ),
                                                          ),
                                                          onTap: () =>
                                                              onSelected(name),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                  if (showDone)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            8,
                                                          ),
                                                      child: SizedBox(
                                                        width: double.infinity,
                                                        child: ElevatedButton(
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                primaryColor,
                                                            foregroundColor:
                                                                secondaryColor,
                                                          ),
                                                          onPressed: () {
                                                            final index =
                                                                highlightedIndex
                                                                    .clamp(
                                                                      0,
                                                                      matches.length -
                                                                          1,
                                                                    );
                                                            onSelected(
                                                              matches[index],
                                                            );
                                                          },
                                                          child: const Text(
                                                            'Done',
                                                          ),
                                                        ),
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
                                },
                                fieldViewBuilder:
                                    (
                                      context,
                                      controller,
                                      focusNode,
                                      onFieldSubmitted,
                                    ) => TextField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      autofocus: true,
                                      onTap: () {
                                        if (!focusNode.hasFocus) {
                                          focusNode.requestFocus();
                                        }
                                      },
                                      minLines: 1,
                                      maxLines: 4,

                                      textInputAction: TextInputAction.done,
                                      decoration: const InputDecoration(
                                        hintText: "Add a task",
                                        border: InputBorder.none,
                                      ),
                                      onChanged: (val) {
                                        final cursor =
                                            controller.selection.baseOffset;
                                        final safeCursor = cursor
                                            .clamp(0, val.length)
                                            .toInt();
                                        final m = parseMention(val, safeCursor);

                                        metadataTokenStart = -1;
                                        assigneeMentionSourceText = val;
                                        setModalState(() {
                                          if (m != null) {
                                            assigneeMentionStart = m.start;
                                            assigneeMentionEnd = safeCursor;
                                            assigneeMentionQuery = m.query;
                                            mentionSymbol = m.symbol;
                                          } else {
                                            assigneeMentionQuery = null;
                                            assigneeMentionStart = -1;
                                            assigneeMentionEnd = -1;
                                          }
                                        });

                                        if (val.isEmpty) return;
                                        if (cursor <= 0 ||
                                            cursor > val.length) {
                                          return;
                                        }
                                        final ch = val[cursor - 1];
                                        final prev = cursor >= 2
                                            ? val[cursor - 2]
                                            : ' ';

                                        FloatingSheetType? triggerType;
                                        if (ch == '#') {
                                          triggerType =
                                              FloatingSheetType.clientName;
                                        } else if (ch == '!') {
                                          triggerType =
                                              FloatingSheetType.deadline;
                                        } else if (ch == '+') {
                                          triggerType =
                                              FloatingSheetType.workType;
                                        } else if (ch == '*') {
                                          triggerType =
                                              FloatingSheetType.remind;
                                        } else if (ch == '^') {
                                          triggerType =
                                              FloatingSheetType.refProject;
                                        }

                                        if (triggerType != null && m == null) {
                                          if (prev != ' ' && prev != '\n') {
                                            return;
                                          }

                                          metadataTokenStart = safeCursor - 1;

                                          _showFloatingSheet(
                                            textFieldCtx,
                                            triggerType,
                                            onSelected: (sel) {
                                              setState(() {
                                                removeMetadataTokenFromTaskName();

                                                // Sync bottom buttons state
                                                if (triggerType ==
                                                    FloatingSheetType
                                                        .priority) {
                                                  _setNewTaskMetadata(
                                                    FloatingSheetType.priority,
                                                    sel,
                                                  );
                                                } else if (triggerType ==
                                                    FloatingSheetType.remind) {
                                                  _setNewTaskMetadata(
                                                    FloatingSheetType.remind,
                                                    sel,
                                                  );
                                                } else if (triggerType ==
                                                    FloatingSheetType.assign) {
                                                  final selectedAssignees =
                                                      (_newTaskAssignee ?? '')
                                                          .split(',')
                                                          .map(
                                                            (name) =>
                                                                name.trim(),
                                                          )
                                                          .where(
                                                            (name) =>
                                                                name.isNotEmpty,
                                                          )
                                                          .toList();
                                                  if (!selectedAssignees.any(
                                                    (name) =>
                                                        name.toLowerCase() ==
                                                        sel.toLowerCase(),
                                                  )) {
                                                    selectedAssignees.add(sel);
                                                  }
                                                  _setNewTaskMetadata(
                                                    FloatingSheetType.assign,
                                                    selectedAssignees.join(
                                                      ', ',
                                                    ),
                                                  );
                                                } else if (triggerType ==
                                                    FloatingSheetType
                                                        .deadline) {
                                                  _setNewTaskMetadata(
                                                    FloatingSheetType.deadline,
                                                    sel,
                                                  );
                                                } else if (triggerType ==
                                                    FloatingSheetType
                                                        .workType) {
                                                  _setNewTaskMetadata(
                                                    FloatingSheetType.workType,
                                                    sel,
                                                  );
                                                } else if (triggerType ==
                                                    FloatingSheetType.folder) {
                                                  _setNewTaskMetadata(
                                                    FloatingSheetType.folder,
                                                    sel,
                                                  );
                                                } else if (triggerType ==
                                                    FloatingSheetType
                                                        .clientName) {
                                                  _setNewTaskMetadata(
                                                    FloatingSheetType
                                                        .clientName,
                                                    sel,
                                                  );
                                                } else if (triggerType ==
                                                    FloatingSheetType
                                                        .refProject) {
                                                  _setNewTaskMetadata(
                                                    FloatingSheetType
                                                        .refProject,
                                                    sel,
                                                  );
                                                }
                                              });
                                              setModalState(() {});
                                            },
                                          );
                                        }
                                      },
                                      onSubmitted: (_) {
                                        final isMentionActive =
                                            assigneeMentionQuery != null;
                                        onFieldSubmitted();
                                        if (isMentionActive) return;
                                        _handleAddTaskFromSheet().then((added) {
                                          if (added && sheetContext.mounted) {
                                            Navigator.of(sheetContext).pop();
                                          }
                                        });
                                      },
                                    ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Task shortcuts',
                          onPressed: () => _showTaskSymbolHelp(sheetContext),
                          icon: const Icon(
                            Icons.info_outline,
                            color: secondaryColor,
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            final added = await _handleAddTaskFromSheet();
                            if (added && sheetContext.mounted) {
                              Navigator.of(sheetContext).pop();
                            }
                          },
                          icon: const Icon(Icons.send, color: secondaryColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: availableButtonOrder
                            .map(
                              (type) => Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: _buildBottomSheetButtonWithState(
                                  type,
                                  setModalState,
                                  compact: screenWidth < 600,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      _hideFloatingSheet();
      _focusNode.unfocus();
      FocusScope.of(context).unfocus();
      if (!kIsWeb) {
        SystemChannels.textInput.invokeMethod('textInput.hide');
      }
    });
  }

  Future<void> _openTaskDetail(Task task) async {
    _hideFloatingSheet();
    await context.push<void>('/task', extra: task);
    if (mounted) await updateTaskHomeWidget(tasks);
  }

  Future<void> _confirmDeleteSelected() async {
    if (_selected.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Delete ${_selected.length} task(s)?'),
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

    if (confirm == true) {
      final List<Task> toDelete = _selected.toList();

      for (final t in toDelete) {
        if (t.id != null) {
          try {
            await _deleteTaskFromFirebase(t);
          } catch (_) {}
        }
        tasks.remove(t);
      }

      setState(() {
        _selected.clear();
        _sortTasks();
      });
      await updateTaskHomeWidget(tasks);
    }
  }

  Future<void> _promptAddSubstep(Task task) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add substep'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Substep title'),
            onSubmitted: (v) => Navigator.of(ctx).pop(v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (result != null && result.trim().isNotEmpty) {
      setState(() {
        task.steps.add(TaskStep(title: result.trim()));
      });
      await _updateTaskInFirebase(task);
      setState(() {
        _sortTasks();
      });
    }
  }

  Widget _buildTaskTile(Task task, int index) {
    final isSelected = _selected.contains(task);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onLongPress: () {
          setState(() {
            if (_selected.contains(task)) {
              _selected.remove(task);
            } else {
              _selected.add(task);
            }
          });
        },
        onTap: () async {
          if (_selected.isNotEmpty) {
            setState(() {
              if (_selected.contains(task)) {
                _selected.remove(task);
              } else {
                _selected.add(task);
              }
            });
            return;
          }
          _openTaskDetail(task);
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? primaryColor.withValues(alpha: 0.1)
                : Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () async {
                  setState(() {
                    task.isDone = !task.isDone;
                  });
                  await _updateTaskInFirebase(task);
                  setState(() {
                    _sortTasks();
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 14.0),
                  child: isSelected
                      ? const Icon(
                          Icons.check_circle,
                          size: 28,
                          color: secondaryColor,
                        )
                      : Icon(
                          task.isDone
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 28,
                          color: task.isDone ? Colors.green : Colors.black54,
                        ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF26364A),
                        decoration: task.isDone
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: Colors.blueGrey.shade400,
                      ),
                    ),
                    if (task.note.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          task.note.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.25,
                            color: task.isDone
                                ? Colors.grey.shade500
                                : Colors.blueGrey.shade500,
                          ),
                        ),
                      ),
                    if (task.workType != null && task.workType!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3.0),
                        child: Text(
                          task.workType!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: task.isDone
                                ? Colors.grey.shade500
                                : Colors.blueGrey.shade500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Builder(
                        builder: (badgeContext) {
                          final p = task.priority;
                          if (p == null || p.isEmpty) {
                            return GestureDetector(
                              onTap: () {
                                _showFloatingSheet(
                                  badgeContext,
                                  FloatingSheetType.priority,
                                  onSelected: (value) async {
                                    setState(() {
                                      task.priority = value;
                                      task.priorityUpdatedAt =
                                          DateTime.now().millisecondsSinceEpoch;
                                    });
                                    _sortTasks();
                                    await _updateTaskInFirebase(task);
                                  },
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(
                                  'None',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            );
                          }

                          return GestureDetector(
                            onTap: () {
                              _showFloatingSheet(
                                badgeContext,
                                FloatingSheetType.priority,
                                onSelected: (value) async {
                                  setState(() {
                                    task.priority = value;
                                    task.priorityUpdatedAt =
                                        DateTime.now().millisecondsSinceEpoch;
                                  });
                                  _sortTasks();
                                  await _updateTaskInFirebase(task);
                                },
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: secondaryColor),
                              ),
                              child: Text(
                                p,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: secondaryColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _promptAddSubstep(task),
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.all(6.0),
                          child: Icon(
                            Icons.add_circle_outline,
                            size: 24,
                            color: secondaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isOverdue(Task task) {
    if (task.isDone) return false;
    final dStr = task.deadline ?? task.reminder;
    if (dStr == null || dStr.isEmpty) return false;
    try {
      final dt = DateTime.parse(dStr);
      return dt.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  List<Task> _getOverdueTasks() => tasks.where((t) => _isOverdue(t)).toList();
  List<Task> _getPendingTasks() =>
      tasks.where((t) => !t.isDone && !_isOverdue(t)).toList();
  List<Task> _getDoneTasks() => tasks.where((t) => t.isDone).toList();

  List<Task> _getMyTasks() {
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    final String myUid = authVM.userUid.trim().toLowerCase();
    final String myEmail = authVM.userEmail.trim().toLowerCase();
    final String myName = authVM.userName.trim().toLowerCase();

    return tasks.where((task) {
      final cb = task.createdBy;
      bool isCreator = false;
      if (cb != null) {
        final cbUid = (cb['uid'] ?? '').toString().trim().toLowerCase();
        final cbEmail = (cb['email'] ?? '').toString().trim().toLowerCase();
        final cbName = (cb['name'] ?? '').toString().trim().toLowerCase();
        if ((cbUid.isNotEmpty && (cbUid == myUid || myUid.contains(cbUid))) ||
            (cbEmail.isNotEmpty &&
                (cbEmail == myEmail || myEmail.contains(cbEmail))) ||
            (cbName.isNotEmpty &&
                (cbName == myName || myName.contains(cbName)))) {
          isCreator = true;
        }
      }

      final assignee = (task.assignee ?? '').toString().trim().toLowerCase();
      final isAssignee =
          assignee.isNotEmpty &&
          ((myName.isNotEmpty && assignee.contains(myName)) ||
              (myEmail.isNotEmpty && assignee.contains(myEmail)) ||
              (myUid.isNotEmpty && assignee.contains(myUid)));

      return isCreator || isAssignee;
    }).toList();
  }

  DateTime? _myWorkDeadline(Task task) =>
      DateTime.tryParse(task.deadline ?? '');

  bool _isTomorrow(DateTime date, DateTime now) {
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day;
  }

  Map<String, List<Task>> _myWorkSections(List<Task> myTasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final pendingTasks = myTasks.where((task) => !task.isDone);
    final doneTasks = myTasks.where((task) => task.isDone).toList();
    final scheduledTasks = pendingTasks
        .where((task) => task.priority?.trim().isEmpty ?? true)
        .map((task) => (task: task, date: _myWorkDeadline(task)))
        .where((entry) => entry.date != null)
        .toList();
    final todayWorks = <Task>{
      ...scheduledTasks
          .where(
            (entry) =>
                entry.date!.year == today.year &&
                entry.date!.month == today.month &&
                entry.date!.day == today.day,
          )
          .map((entry) => entry.task),
      ...pendingTasks.where(
        (task) => task.priority?.trim().toLowerCase() == 'today',
      ),
    }.toList();
    final tomorrowWorks = <Task>{
      ...scheduledTasks
          .where((entry) => _isTomorrow(entry.date!, now))
          .map((entry) => entry.task),
      ...pendingTasks.where(
        (task) => task.priority?.trim().toLowerCase() == 'tomorrow',
      ),
    }.toList();
    List<Task> tasksWithPriority(String priority) => pendingTasks
        .where((task) => task.priority?.trim().toLowerCase() == priority)
        .toList();

    return {
      'Urgent Works': pendingTasks
          .where(
            (task) => const {
              'u1',
              'u2',
              'u3',
              'urgent',
            }.contains(task.priority?.trim().toLowerCase()),
          )
          .toList(),
      'IMP Works': tasksWithPriority('imp'),
      'Today Works': todayWorks,
      'Tomorrow Works': tomorrowWorks,
      'Day Later Works': tasksWithPriority('day later'),
      'Later Works': tasksWithPriority('later'),
      'Process Works': tasksWithPriority('process'),
      'Hold Works': tasksWithPriority('hold'),
      'Done Works': doneTasks,
    };
  }

  Widget _buildTaskPriorityBadge(Task task, {bool compact = false}) {
    final priority = task.priority?.trim();
    final badgeColor = _taskPriorityColor(priority);
    return GestureDetector(
      onTap: () {
        _showFloatingSheet(
          context,
          FloatingSheetType.priority,
          onSelected: (value) async {
            setState(() {
              task.priority = value;
              task.priorityUpdatedAt = DateTime.now().millisecondsSinceEpoch;
            });
            _sortTasks();
            await _updateTaskInFirebase(task);
          },
        );
      },
      child: Container(
        constraints: compact ? const BoxConstraints(maxWidth: 76) : null,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: badgeColor.withValues(alpha: 0.42)),
        ),
        child: Text(
          priority != null && priority.isNotEmpty ? priority : 'None',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: compact ? 11 : 13,
            color: badgeColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Color _taskPriorityColor(String? priority) {
    switch (priority?.trim().toLowerCase()) {
      case 'u1':
      case 'u2':
      case 'u3':
      case 'urgent':
        return const Color(0xFF9B5965);
      case 'imp':
        return const Color(0xFF526D8A);
      case 'today':
      case 'tomorrow':
        return const Color(0xFF557E9B);
      case 'hold':
        return const Color(0xFF99765B);
      case 'process':
        return const Color(0xFF667F89);
      default:
        return const Color(0xFF71808D);
    }
  }

  Widget _buildMyWorkTaskResults(List<Task> visibleTasks) {
    if (_viewType == 'Calendar') {
      final selectedDay = DateTime(
        _calendarDate.year,
        _calendarDate.month,
        _calendarDate.day,
      );
      final dayTasks = visibleTasks.where((task) {
        final scheduled = _taskScheduledDate(task);
        return scheduled != null &&
            scheduled.year == selectedDay.year &&
            scheduled.month == selectedDay.month &&
            scheduled.day == selectedDay.day;
      }).toList();

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CalendarDatePicker(
            initialDate: _calendarDate,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            onDateChanged: (date) => setState(() => _calendarDate = date),
          ),
          const Divider(height: 1),
          if (dayTasks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No tasks scheduled for this day.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...dayTasks.asMap().entries.map(
              (entry) => Column(
                children: [
                  _buildTaskTile(entry.value, entry.key),
                  _thinHairline(indent: 15, endIndent: 15, opacity: 0.05),
                ],
              ),
            ),
        ],
      );
    }

    if (visibleTasks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(24, 8, 24, 20),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'No tasks in this section.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(_zoom)),
      child: _viewType == 'Grid'
          ? GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 260,
                mainAxisExtent: 150 + (80 * (_zoom - 1)),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: visibleTasks.length,
              itemBuilder: (context, index) =>
                  _buildGridTaskCard(visibleTasks[index]),
            )
          : Column(
              children: visibleTasks.asMap().entries.map((entry) {
                if (_viewType == 'List') {
                  return _buildCompactTaskTile(entry.value);
                }
                return Column(
                  children: [
                    _buildTaskTile(entry.value, entry.key),
                    _thinHairline(indent: 15, endIndent: 15, opacity: 0.05),
                  ],
                );
              }).toList(),
            ),
    );
  }

  Widget _buildMyWorkView() {
    final sections = _myWorkSections(_getMyTasks());
    const sectionNames = [
      'Urgent Works',
      'IMP Works',
      'Today Works',
      'Tomorrow Works',
      'Day Later Works',
      'Later Works',
      'Process Works',
      'Hold Works',
      'Done Works',
    ];
    final populatedSectionNames = sectionNames
        .where((name) => sections[name]?.isNotEmpty ?? false)
        .toList();
    return _refreshableScrollView(
      SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: populatedSectionNames.isEmpty
              ? const [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 20),
                    child: Text(
                      'No tasks in My Work.',
                      style: TextStyle(color: Colors.blueGrey),
                    ),
                  ),
                ]
              : [
                  for (final name in populatedSectionNames) ...[
                    Builder(
                      builder: (context) {
                        final count = sections[name]?.length ?? 0;
                        final isExpanded = _expandedMyWorkSections.contains(
                          name,
                        );
                        final countBadgeColor = _myWorkSectionColor(name);

                        return Column(
                          children: [
                            InkWell(
                              onTap: () => setState(() {
                                if (isExpanded) {
                                  _expandedMyWorkSections.remove(name);
                                } else {
                                  _expandedMyWorkSections
                                    ..clear()
                                    ..add(name);
                                }
                              }),
                              onDoubleTap: () => setState(() {
                                if (_expandedMyWorkSections.length ==
                                    populatedSectionNames.length) {
                                  _expandedMyWorkSections.clear();
                                } else {
                                  _expandedMyWorkSections
                                    ..clear()
                                    ..addAll(populatedSectionNames);
                                }
                              }),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      name
                                          .replaceFirst(RegExp(r' Works$'), '')
                                          .toUpperCase(),
                                      style: TextStyle(
                                        color: countBadgeColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      constraints: const BoxConstraints(
                                        minWidth: 28,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: countBadgeColor.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '$count',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: countBadgeColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      isExpanded
                                          ? Icons.keyboard_arrow_up
                                          : Icons.keyboard_arrow_down,
                                      color: countBadgeColor,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isExpanded)
                              Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                constraints: BoxConstraints(
                                  maxHeight:
                                      MediaQuery.of(context).size.height * 0.4,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: countBadgeColor.withValues(
                                      alpha: 0.25,
                                    ),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: SingleChildScrollView(
                                  child: _buildMyWorkTaskResults(
                                    _getVisibleTasks(
                                      sections[name] ?? const <Task>[],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
        ),
      ),
    );
  }

  List<Task> _getVisibleTasks(List<Task> source) {
    final query = _taskSearchQuery.trim().toLowerCase();
    final result = source
        .where(
          (task) =>
              query.isEmpty ||
              task.title.toLowerCase().contains(query) ||
              task.note.toLowerCase().contains(query) ||
              (task.assignee ?? '').toLowerCase().contains(query) ||
              (task.workType ?? '').toLowerCase().contains(query) ||
              (task.priority ?? '').toLowerCase().contains(query),
        )
        .toList();

    int compareDates(String? a, String? b) {
      final first = DateTime.tryParse(a ?? '');
      final second = DateTime.tryParse(b ?? '');
      if (first == null) return second == null ? 0 : 1;
      if (second == null) return -1;
      return first.compareTo(second);
    }

    switch (_sortBy) {
      case 'Title':
        result.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case 'Due date':
        result.sort(
          (a, b) =>
              compareDates(a.deadline ?? a.reminder, b.deadline ?? b.reminder),
        );
      case 'Status':
        result.sort(
          (a, b) => a.isDone == b.isDone
              ? a.title.toLowerCase().compareTo(b.title.toLowerCase())
              : (a.isDone ? 1 : -1),
        );
      default:
        result.sort(_taskComparator);
    }
    return result;
  }

  int _upcomingTaskNotificationCount() {
    final now = DateTime.now();
    return tasks.where((task) {
      final scheduled = _taskScheduledDate(task);
      return !task.isDone && scheduled != null && scheduled.isAfter(now);
    }).length;
  }

  String _groupValue(Task task) {
    switch (_groupBy) {
      case 'Priority':
        return task.priority?.trim().isNotEmpty == true
            ? task.priority!.trim()
            : 'No priority';
      case 'Work type':
        return task.workType?.trim().isNotEmpty == true
            ? task.workType!.trim()
            : 'No work type';
      case 'Status':
        return task.isDone ? 'Done' : 'Pending';
      default:
        return task.assignee?.trim().isNotEmpty == true
            ? task.assignee!.trim()
            : 'Unassigned';
    }
  }

  DateTime? _taskScheduledDate(Task task) =>
      DateTime.tryParse(task.deadline ?? task.reminder ?? '');

  Widget _buildCompactTaskTile(Task task) {
    final isSelected = _selected.contains(task);
    final description = task.note.trim();
    final workType = task.workType?.trim() ?? '';
    return ListTile(
      dense: true,
      selected: isSelected,
      leading: Checkbox(
        value: task.isDone,
        activeColor: secondaryColor,
        onChanged: (_) async {
          setState(() => task.isDone = !task.isDone);
          await _updateTaskInFirebase(task);
          if (mounted) _sortTasks();
        },
      ),
      title: Text(
        task.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF26364A),
          decoration: task.isDone ? TextDecoration.lineThrough : null,
          decorationColor: Colors.blueGrey.shade400,
        ),
      ),
      subtitle: description.isNotEmpty || workType.isNotEmpty
          ? Text(
              [
                if (description.isNotEmpty) description,
                if (workType.isNotEmpty) workType,
              ].join(' • '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Colors.blueGrey.shade500,
                height: 1.25,
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTaskPriorityBadge(task, compact: true),
          IconButton(
            tooltip: 'Add subtask',
            visualDensity: VisualDensity.compact,
            onPressed: () => _promptAddSubstep(task),
            icon: const Icon(
              Icons.add_circle_outline,
              color: Color(0xFF526D8A),
              size: 21,
            ),
          ),
        ],
      ),
      onLongPress: () => setState(() {
        if (isSelected) {
          _selected.remove(task);
        } else {
          _selected.add(task);
        }
      }),
      onTap: () {
        if (_selected.isNotEmpty) {
          setState(() {
            if (isSelected) {
              _selected.remove(task);
            } else {
              _selected.add(task);
            }
          });
        } else {
          _openTaskDetail(task);
        }
      },
    );
  }

  Widget _buildGridTaskCard(Task task) {
    final isSelected = _selected.contains(task);
    return Card(
      color: isSelected ? primaryColor.withValues(alpha: 0.15) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onLongPress: () => setState(() {
          if (isSelected) {
            _selected.remove(task);
          } else {
            _selected.add(task);
          }
        }),
        onTap: () {
          if (_selected.isNotEmpty) {
            setState(() {
              if (isSelected) {
                _selected.remove(task);
              } else {
                _selected.add(task);
              }
            });
          } else {
            _openTaskDetail(task);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    task.isDone
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: task.isDone ? Colors.green : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(height: 8),
                  if (task.priority?.isNotEmpty == true)
                    Text(
                      task.priority!,
                      style: const TextStyle(
                        color: secondaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                task.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  decoration: task.isDone ? TextDecoration.lineThrough : null,
                ),
              ),
              const Spacer(),
              if (task.assignee?.isNotEmpty == true)
                Text(
                  task.assignee!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskList(List<Task> list) {
    final visibleTasks = _getVisibleTasks(list);
    if (_viewType == 'Calendar') {
      return _buildCalendarView(visibleTasks);
    }
    if (visibleTasks.isEmpty) {
      return _refreshableScrollView(
        ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(
              height: 240,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No tasks found in this category.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return _refreshableScrollView(
      MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(_zoom)),
        child: _viewType == 'Grid'
            ? GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 260,
                  mainAxisExtent: 150 + (80 * (_zoom - 1)),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: visibleTasks.length,
                itemBuilder: (context, index) =>
                    _buildGridTaskCard(visibleTasks[index]),
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
                itemCount: visibleTasks.length,
                itemBuilder: (context, index) => _viewType == 'List'
                    ? _buildCompactTaskTile(visibleTasks[index])
                    : Column(
                        children: [
                          _buildTaskTile(visibleTasks[index], index),
                          _thinHairline(
                            indent: 15,
                            endIndent: 15,
                            opacity: 0.05,
                          ),
                        ],
                      ),
              ),
      ),
    );
  }

  Widget _buildCalendarView(List<Task> visibleTasks) {
    final selectedDay = DateTime(
      _calendarDate.year,
      _calendarDate.month,
      _calendarDate.day,
    );
    final dayTasks = visibleTasks.where((task) {
      final scheduled = _taskScheduledDate(task);
      return scheduled != null &&
          scheduled.year == selectedDay.year &&
          scheduled.month == selectedDay.month &&
          scheduled.day == selectedDay.day;
    }).toList();

    return _refreshableScrollView(
      SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CalendarDatePicker(
              initialDate: _calendarDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              onDateChanged: (date) => setState(() => _calendarDate = date),
            ),
            const Divider(height: 1),
            if (dayTasks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No tasks scheduled for this day.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ...dayTasks.asMap().entries.map(
                (entry) => Column(
                  children: [
                    _buildTaskTile(entry.value, entry.key),
                    _thinHairline(indent: 15, endIndent: 15, opacity: 0.05),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupByAssignView() {
    final Map<String, List<Task>> grouped = {};
    for (final task in _getVisibleTasks(tasks)) {
      grouped.putIfAbsent(_groupValue(task), () => []).add(task);
    }

    if (grouped.isEmpty) {
      return _refreshableScrollView(
        ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(
              height: 240,
              child: Center(
                child: Text(
                  'No tasks to group.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final groups = grouped.keys.toList()..sort();

    return _refreshableScrollView(
      ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final groupName = groups[index];
          final groupTasks = grouped[groupName]!;
          final completedCount = groupTasks.where((t) => t.isDone).length;
          final pendingCount = groupTasks.length - completedCount;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: primaryColor.withValues(alpha: 0.3),
                child: Text(
                  groupName.isNotEmpty ? groupName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: secondaryColor,
                  ),
                ),
              ),
              title: Text(
                groupName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
              subtitle: Text(
                'Total: ${groupTasks.length} • Pending: $pendingCount • Done: $completedCount',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              children: [
                if (_groupBy == 'Assignee')
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () =>
                          _showAssigneeTasksModal(groupName, groupTasks),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Open assignee task view'),
                    ),
                  ),
                ...groupTasks.map(
                  (task) => ListTile(
                    dense: true,
                    leading: Icon(
                      task.isDone
                          ? Icons.check_circle_outline
                          : Icons.radio_button_unchecked,
                      color: task.isDone ? Colors.green : Colors.grey,
                    ),
                    title: Text(task.title),
                    onTap: () => _openTaskDetail(task),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAssigneeTasksModal(String assigneeName, List<Task> assigneeTasks) {
    context.push(
      '/assignee-tasks',
      extra: {'assigneeName': assigneeName, 'tasks': assigneeTasks},
    );
  }

  Future<void> _showToolbarMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.sort),
              title: const Text('Sort by'),
              subtitle: Text(_sortBy),
              onTap: () => Navigator.pop(context, 'sort'),
            ),
            ListTile(
              leading: const Icon(Icons.group_work_outlined),
              title: const Text('Group by'),
              subtitle: Text(_groupBy),
              onTap: () => Navigator.pop(context, 'group'),
            ),
            ListTile(
              leading: const Icon(Icons.view_quilt_outlined),
              title: const Text('View type'),
              subtitle: Text(_viewType),
              onTap: () => Navigator.pop(context, 'view'),
            ),
            ListTile(
              leading: const Icon(Icons.zoom_in),
              title: const Text('Adjust zoom'),
              subtitle: Text('${(_zoom * 100).round()}%'),
              onTap: () => Navigator.pop(context, 'zoom'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add_to_home_screen),
              title: const Text('Add shortcut to home screen'),
              onTap: () => Navigator.pop(context, 'shortcut'),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share list'),
              onTap: () => Navigator.pop(context, 'share'),
            ),
            ListTile(
              leading: const Icon(Icons.print_outlined),
              title: const Text('Print list'),
              onTap: () => Navigator.pop(context, 'print'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;

    switch (action) {
      case 'sort':
        await _chooseToolbarOption(
          title: 'Sort by',
          options: const ['Priority', 'Title', 'Due date', 'Status'],
          selected: _sortBy,
          onSelected: (value) => setState(() => _sortBy = value),
        );
      case 'group':
        await _chooseToolbarOption(
          title: 'Group by',
          options: const ['Assignee', 'Priority', 'Work type', 'Status'],
          selected: _groupBy,
          onSelected: (value) {
            setState(() => _groupBy = value);
            _tabController.animateTo(5);
          },
        );
      case 'view':
        await _chooseToolbarOption(
          title: 'View type',
          options: const ['Grid', 'List', 'Detailed list', 'Calendar'],
          selected: _viewType,
          onSelected: (value) => setState(() => _viewType = value),
        );
      case 'zoom':
        await _showZoomDialog();
      case 'shortcut':
        final added = await installHomeScreenShortcut();
        if (mounted) {
          _showMessage(
            added
                ? 'Home screen shortcut added.'
                : kIsWeb
                ? 'Use the browser menu and choose "Add to Home screen" or "Install app".'
                : 'This platform does not allow the app to add a home screen shortcut automatically.',
          );
        }
      case 'share':
        await _shareTaskList();
      case 'print':
        await _printTaskList();
    }
  }

  Future<void> _chooseToolbarOption({
    required String title,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(title),
        children: options
            .map(
              (option) => RadioListTile<String>(
                value: option,
                groupValue: selected,
                title: Text(option),
                onChanged: (value) => Navigator.pop(context, value),
              ),
            )
            .toList(),
      ),
    );
    if (value != null && mounted) onSelected(value);
  }

  Future<void> _showZoomDialog() async {
    var zoom = _zoom;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Adjust zoom'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                min: 0.8,
                max: 1.4,
                divisions: 6,
                value: zoom,
                label: '${(zoom * 100).round()}%',
                onChanged: (value) {
                  setDialogState(() => zoom = value);
                  setState(() => _zoom = value);
                },
              ),
              Text('${(zoom * 100).round()}%'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  List<Task> _tasksForCurrentTab() {
    switch (_tabController.index) {
      case 0:
        return _getMyTasks();
      case 2:
        return _getDoneTasks();
      case 3:
        return _getOverdueTasks();
      case 4:
        return _getPendingTasks();
      default:
        return tasks;
    }
  }

  Future<void> _shareTaskList() async {
    final items = _getVisibleTasks(_tasksForCurrentTab());
    final contents = items.isEmpty
        ? 'No tasks in this list.'
        : items
              .map(
                (task) =>
                    '${task.isDone ? '[Done]' : '[Pending]'} ${task.title}'
                    '${task.assignee?.isNotEmpty == true ? ' — ${task.assignee}' : ''}'
                    '${task.deadline?.isNotEmpty == true ? ' (Due: ${task.deadline})' : ''}',
              )
              .join('\n');
    await SharePlus.instance.share(
      ShareParams(subject: 'Task list', text: '${widget.title}\n\n$contents'),
    );
  }

  Future<void> _printTaskList() async {
    final items = _getVisibleTasks(_tasksForCurrentTab());
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            '${widget.title} - Task list',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 16),
          if (items.isEmpty)
            pw.Text('No tasks in this list.')
          else
            ...items.map(
              (task) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Text(
                  '${task.isDone ? '[Done]' : '[Pending]'} ${task.title}'
                  '${task.assignee?.isNotEmpty == true ? ' - ${task.assignee}' : ''}'
                  '${task.deadline?.isNotEmpty == true ? ' (Due: ${task.deadline})' : ''}',
                ),
              ),
            ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (_) async => document.save());
  }

  Future<void> _showNotifications() async {
    final now = DateTime.now();
    final reminders =
        tasks.where((task) {
          if (task.isDone) return false;
          final scheduled = _taskScheduledDate(task);
          return scheduled != null &&
              scheduled.isAfter(now.subtract(const Duration(days: 1)));
        }).toList()..sort(
          (a, b) => (_taskScheduledDate(a) ?? DateTime(2100)).compareTo(
            _taskScheduledDate(b) ?? DateTime(2100),
          ),
        );

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notifications'),
        content: SizedBox(
          width: 360,
          child: reminders.isEmpty
              ? const Text('No upcoming task reminders.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: reminders.length,
                  itemBuilder: (context, index) {
                    final task = reminders[index];
                    final scheduled = _taskScheduledDate(task)!;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.notifications_outlined,
                        color: secondaryColor,
                      ),
                      title: Text(task.title),
                      subtitle: Text(
                        '${scheduled.day}/${scheduled.month}/${scheduled.year} '
                        '${scheduled.hour.toString().padLeft(2, '0')}:'
                        '${scheduled.minute.toString().padLeft(2, '0')}',
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bool selectionActive = _selected.isNotEmpty;
    final upcomingNotificationCount = _upcomingTaskNotificationCount();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: selectionActive
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              centerTitle: false,
              automaticallyImplyLeading: false,
              iconTheme: const IconThemeData(color: secondaryColor),
              leading: IconButton(
                icon: const Icon(Icons.close, color: secondaryColor),
                onPressed: () {
                  setState(() {
                    _selected.clear();
                  });
                },
              ),
              title: Text(
                '${_selected.length} selected',
                style: const TextStyle(
                  color: secondaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  onPressed: _confirmDeleteSelected,
                ),
                const SizedBox(width: 8),
              ],
            )
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.black),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              title: Text(
                widget.title,
                style: const TextStyle(
                  color: secondaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: 'Notifications',
                  icon: Badge(
                    isLabelVisible: upcomingNotificationCount > 0,
                    label: Text('$upcomingNotificationCount'),
                    child: const Icon(
                      Icons.notifications_none_outlined,
                      color: secondaryColor,
                    ),
                  ),
                  onPressed: _showNotifications,
                ),
                IconButton(
                  tooltip: _isSearchVisible ? 'Close search' : 'Search tasks',
                  icon: Icon(
                    _isSearchVisible ? Icons.close : Icons.search,
                    color: secondaryColor,
                  ),
                  onPressed: () {
                    setState(() {
                      _isSearchVisible = !_isSearchVisible;
                      if (!_isSearchVisible) {
                        _taskSearchController.clear();
                        _taskSearchQuery = '';
                      }
                    });
                  },
                ),
                IconButton(
                  tooltip: 'More options',
                  icon: const Icon(Icons.more_vert, color: secondaryColor),
                  onPressed: _showToolbarMenu,
                ),
                const SizedBox(width: 4),
              ],
            ),
      drawer: selectionActive ? null : const AppDrawer(),
      body: Column(
        children: [
          if (_isSearchVisible)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                controller: _taskSearchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search tasks',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Close search',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _taskSearchController.clear();
                      FocusScope.of(context).unfocus();
                      setState(() {
                        _taskSearchQuery = '';
                        _isSearchVisible = false;
                      });
                    },
                  ),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) => setState(() => _taskSearchQuery = value),
              ),
            ),
          Container(
            color: Colors.white,
            width: double.infinity,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: secondaryColor,
              indicatorWeight: 3.0,
              dividerColor: Colors.transparent,
              labelColor: Colors.black,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
              unselectedLabelColor: Colors.grey.shade500,
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              tabs: [
                const Tab(text: 'My Work'),
                Tab(text: 'All Work (${tasks.length})'),
                Tab(text: 'Done (${_getDoneTasks().length})'),
                Tab(text: 'Overdue (${_getOverdueTasks().length})'),
                Tab(text: 'Pending (${_getPendingTasks().length})'),
                Tab(text: 'Group by $_groupBy'),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMyWorkView(),
                _buildTaskList(tasks),
                _buildTaskList(_getDoneTasks()),
                _buildTaskList(_getOverdueTasks()),
                _buildTaskList(_getPendingTasks()),
                _buildGroupByAssignView(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: selectionActive
          ? null
          : FloatingActionButton(
              onPressed: _openAddTaskSheet,
              backgroundColor: primaryColor,
              child: const Icon(Icons.add, color: secondaryColor),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
