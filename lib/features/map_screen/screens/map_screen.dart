import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 🚀 NAYA: For SystemChannels keyboard show/hide
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';
import '../models/floating_sheet_type.dart';

import 'package:go_router/go_router.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';

import '../../../widgets/app_drawer.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../utils/role_permissions.dart';

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
  String _searchQuery = '';

  OverlayEntry? _floatingSheetOverlay;

  final List<Task> tasks = [];
  Timer? _reminderTimer;

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

  // Draggable button order
  final List<FloatingSheetType> _defaultOrder = [
    FloatingSheetType.priority,
    FloatingSheetType.remind,
    FloatingSheetType.assign,
    FloatingSheetType.deadline,
    FloatingSheetType.workType,
    FloatingSheetType.folder,
    FloatingSheetType.clientName,
    FloatingSheetType.refProject, // 🚀 NAYA
  ];

  late List<FloatingSheetType> _buttonOrder = List.from(_defaultOrder);

  // Firestore collection reference -> MAP collection as requested
  final CollectionReference tasksCollection = FirebaseFirestore.instance
      .collection('map');

  bool _isAddingTask = false; // 🚀 NAYA: To prevent double submission

  List<String>? _assigneesCache;
  List<String>? _clientsCache;
  List<String>? _projectsCache; // 🚀 NAYA

  static const Color primaryColor = Color(0xFFFBE64E);
  static const Color secondaryColor = Color(0xFF6B5800);

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadButtonOrder();
    _startReminderChecker();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTasksFromFirebase();
      _checkDueReminders();
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

  Future<void> _saveButtonOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'map_button_order',
      _buttonOrder.map((e) => e.name).toList(),
    );
  }

  Widget _buildBottomSheetButtonWithState(
    FloatingSheetType type,
    StateSetter setModalState,
  ) {
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
          setState(() {
            _newTaskPriority = v;
            taskName.text = '${taskName.text} -$v '.trim() + ' ';
          });
          setModalState(() {});
        };
        onClear = () {
          setState(() => _newTaskPriority = null);
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
          setState(() {
            _newTaskReminder = v;
            final date = _formatDateTime(v);
            taskName.text = '${taskName.text} *$date '.trim() + ' ';
          });
          setModalState(() {});
        };
        onClear = () {
          setState(() => _newTaskReminder = null);
          setModalState(() {});
        };
        break;
      case FloatingSheetType.assign:
        icon = Icons.assignment;
        label = "Assign";
        selectedValue = _newTaskAssignee;
        onSelected = (v) {
          setState(() {
            final symbol = '@';
            final currentText = taskName.text;
            if (_newTaskAssignee == null || _newTaskAssignee!.isEmpty) {
              _newTaskAssignee = v;
              taskName.text = '$currentText $symbol$v '.trim() + ' ';
            } else if (!_newTaskAssignee!.contains(v)) {
              _newTaskAssignee = '$_newTaskAssignee, $v';
              taskName.text = '$currentText $symbol$v '.trim() + ' ';
            }
          });
          setModalState(() {});
        };
        onClear = () {
          setState(() => _newTaskAssignee = null);
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
          setState(() {
            _newTaskDeadline = v;
            final date = _formatDateTime(v);
            taskName.text = '${taskName.text} !$date '.trim() + ' ';
          });
          setModalState(() {});
        };
        onClear = () {
          setState(() => _newTaskDeadline = null);
          setModalState(() {});
        };
        break;
      case FloatingSheetType.workType:
        icon = Icons.insert_drive_file;
        label = "Work Type";
        selectedValue = _newTaskWorkType;
        onSelected = (v) {
          setState(() {
            _newTaskWorkType = v;
            taskName.text = '${taskName.text} +$v '.trim() + ' ';
          });
          setModalState(() {});
        };
        onClear = () {
          setState(() => _newTaskWorkType = null);
          setModalState(() {});
        };
        break;
      case FloatingSheetType.folder:
        icon = Icons.folder_outlined;
        label = "Folder";
        selectedValue = _newTaskFolder;
        onSelected = (v) {
          setState(() => _newTaskFolder = v);
          setModalState(() {});
        };
        onClear = () {
          setState(() => _newTaskFolder = null);
          setModalState(() {});
        };
        break;
      case FloatingSheetType.clientName:
        icon = Icons.business_center_outlined;
        label = "Client Name";
        selectedValue = _newTaskClientName;
        onSelected = (v) {
          setState(() {
            _newTaskClientName = v;
            taskName.text = '${taskName.text} #$v '.trim() + ' ';
          });
          setModalState(() {});
        };
        onClear = () {
          setState(() => _newTaskClientName = null);
          setModalState(() {});
        };
        break;
      case FloatingSheetType.refProject:
        icon = Icons.apartment_outlined;
        label = "Ref Project";
        selectedValue = _newTaskRefProject;
        onSelected = (v) {
          setState(() {
            _newTaskRefProject = v;
            taskName.text = '${taskName.text} ^$v '.trim() + ' ';
          });
          setModalState(() {});
        };
        onClear = () {
          setState(() => _newTaskRefProject = null);
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 17,
                ),
                child: Row(
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
                    const SizedBox(width: 8),
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

  @override
  void dispose() {
    _reminderTimer?.cancel();
    _tabController.dispose();
    _hideFloatingSheet();
    _focusNode.dispose();
    taskName.dispose();
    _searchController.dispose();
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

    loaded.sort(_taskComparator);

    setState(() {
      tasks
        ..clear()
        ..addAll(loaded);
    });

    await _checkDueReminders();
  }

  void _startReminderChecker() {
    _reminderTimer?.cancel();
    _reminderTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      _checkDueReminders();
    });
  }

  Future<void> _checkDueReminders() async {
    try {
      final snapshot = await tasksCollection.get();
      final now = DateTime.now();

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final task = Task.fromMap(doc.id, data);

        if (!task.isReminderDueAt(now)) continue;

        await _sendReminderNotification(task);
        await tasksCollection.doc(doc.id).update({'reminderSent': true});
        task.reminderSent = true;
      }
    } catch (e) {
      debugPrint('Error checking reminder notifications: $e');
    }
  }

  Future<void> _addTaskToFirebase(Task task) async {
    final docRef = await tasksCollection.add(task.toMap());
    task.id = docRef.id;
  }

  Future<void> _updateTaskInFirebase(Task task) async {
    if (task.id == null) return;
    await tasksCollection.doc(task.id).update(task.toMap());
  }

  Future<void> _deleteTaskFromFirebase(Task task) async {
    if (task.id == null) return;
    await tasksCollection.doc(task.id).delete();
  }

  Future<void> _handleAddTaskFromSheet() async {
    if (_isAddingTask) return; // 🚀 NAYA: Prevent multiple triggers

    final text = taskName.text.trim();
    if (text.isEmpty) return;

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
    });

    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final newTask = Task(
      text,
      priority: priority,
      reminder: reminder,
      reminderSent: false,
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

    try {
      await _addTaskToFirebase(newTask);

      if (assignee != null && assignee.trim().isNotEmpty) {
        _sendTaskAssignmentNotification(assignee, text, authVM);
      }

      if (_isTaskVisibleToUser(newTask, authVM)) {
        setState(() {
          tasks.add(newTask);
          _sortTasks();
        });
      }
    } catch (e) {
      debugPrint('Error adding task: $e');
    } finally {
      setState(() {
        _isAddingTask = false;
      });
      await Future.delayed(const Duration(milliseconds: 80));
      _focusNode.requestFocus();
    }
  }

  Future<void> _sendReminderNotification(Task task) async {
    final assignee = task.assignee;
    if (assignee == null || assignee.trim().isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'recipientName': assignee.trim(),
        'title': 'Reminder',
        'body': 'Reminder for task: "${task.title}"',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': 'task_reminder',
      });
    } catch (e) {
      debugPrint('Error sending reminder notification: $e');
    }
  }

  Future<void> _sendTaskAssignmentNotification(
    String? assignee,
    String taskTitle,
    AuthViewModel authVM,
  ) async {
    if (assignee == null ||
        assignee.trim().isEmpty ||
        !authVM.allowNotifications)
      return;
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
    if (_assigneesCache != null) return _assigneesCache!;
    final snap = await FirebaseFirestore.instance.collection('users').get();
    final values = snap.docs
        .map((d) {
          final data = d.data();
          final name = (data['name'] ?? data['fullName'] ?? data['email'] ?? '')
              .toString()
              .trim();
          return name;
        })
        .where((e) => e.isNotEmpty)
        .toList();
    _assigneesCache = values;
    return values;
  }

  void _hideFloatingSheet() {
    _floatingSheetOverlay?.remove();
    _floatingSheetOverlay = null;
    _searchController.clear();
    _searchQuery = '';
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
    if (type == FloatingSheetType.clientName)
      clients = await _loadClientsFromFirestore();

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
    if (type == FloatingSheetType.assign)
      assignees = await _loadAssigneesFromFirestore();

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
              if (computed != null)
                finalVal = computed.toIso8601String();
              else if (lower.contains('custom'))
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

    const double menuWidth = 240;
    const double padding = 8;
    const double menuHeightEstimate = 320;

    double left = buttonPosition.dx;
    if (left + menuWidth > overlaySize.width - padding)
      left = overlaySize.width - menuWidth - padding;
    if (left < padding) left = padding;

    double top = buttonPosition.dy - menuHeightEstimate;
    if (top < padding) top = buttonPosition.dy + button.size.height + padding;

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
            left: left,
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

                    return Column(
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
                          constraints: const BoxConstraints(maxHeight: 250),
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
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                      ],
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

  void _openAddTaskSheet() {
    // 🚀 NAYA: Automatically request focus and show keyboard when sheet opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_focusNode.canRequestFocus) {
        _focusNode.requestFocus();
        if (!kIsWeb) {
          SystemChannels.textInput.invokeMethod('textInput.show');
        }
      }
    });

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
          final isMobileWeb = kIsWeb && screenWidth < 600;

          final systemNavBar = MediaQuery.of(sheetContext).padding.bottom;
          final bottomPadding = isMobileWeb
              ? 350.0
              : (kIsWeb ? 16.0 : (16.0 + viewInsets.bottom + systemNavBar));

          return PopScope<Object?>(
            canPop: true,
            onPopInvokedWithResult: (didPop, result) {
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
                    Row(
                      children: [
                        Expanded(
                          child: Builder(
                            builder: (textFieldCtx) => TextField(
                              controller: taskName,
                              focusNode: _focusNode,
                              autofocus: true, // 🚀 NAYA: Always autofocus when sheet opens
                              decoration: const InputDecoration(
                                hintText: "Add a task",
                                border: InputBorder.none,
                              ),
                              onChanged: (val) {
                                if (val.isEmpty) return;
                                final lastChar = val.substring(val.length - 1);

                                FloatingSheetType? triggerType;
                                String symbol = '';
                                if (lastChar == '@') {
                                  triggerType = FloatingSheetType.assign;
                                  symbol = '@';
                                } else if (lastChar == '#') {
                                  triggerType = FloatingSheetType.clientName;
                                  symbol = '#';
                                } else if (lastChar == '-') {
                                  triggerType = FloatingSheetType.priority;
                                  symbol = '-';
                                } else if (lastChar == '!') {
                                  triggerType = FloatingSheetType.deadline;
                                  symbol = '!';
                                } else if (lastChar == '+') {
                                  triggerType = FloatingSheetType.workType;
                                  symbol = '+';
                                } else if (lastChar == '*') {
                                  triggerType = FloatingSheetType.remind;
                                  symbol = '*';
                                } else if (lastChar == '^') {
                                  triggerType = FloatingSheetType.refProject;
                                  symbol = '^';
                                }

                                if (triggerType != null) {
                                  final bool isMulti =
                                      triggerType == FloatingSheetType.assign;

                                  // Get currently selected values from the text to show checks in menu
                                  List<String> currentSelections = [];
                                  if (isMulti) {
                                    final parts = val.split(' ');
                                    for (var p in parts) {
                                      if (p.startsWith('@')) {
                                        currentSelections.add(p.substring(1));
                                      }
                                    }
                                  }

                                  _showFloatingSheet(
                                    textFieldCtx,
                                    triggerType,
                                    multiSelect: isMulti,
                                    selectedValues: currentSelections,
                                    onSelected: (sel) {
                                      setState(() {
                                        String insertVal = sel;
                                        if (triggerType ==
                                                FloatingSheetType.deadline ||
                                            triggerType ==
                                                FloatingSheetType.remind) {
                                          insertVal = _formatDateTime(sel);
                                        }

                                        final currentText = taskName.text;

                                        if (isMulti) {
                                          final fullToken = '$symbol$insertVal';
                                          if (!currentText.contains(
                                            fullToken,
                                          )) {
                                            if (currentText.endsWith(symbol)) {
                                              taskName.text =
                                                  '$currentText$insertVal ';
                                            } else {
                                              taskName.text =
                                                  '$currentText $fullToken ';
                                            }
                                          } else {
                                            taskName.text =
                                                currentText
                                                    .replaceFirst(
                                                      '$fullToken ',
                                                      '',
                                                    )
                                                    .replaceFirst(fullToken, '')
                                                    .trim() +
                                                ' ';
                                          }
                                        } else {
                                          taskName.text =
                                              '$currentText$insertVal ';
                                        }

                                        taskName.selection =
                                            TextSelection.collapsed(
                                              offset: taskName.text.length,
                                            );

                                        // Sync bottom buttons state
                                        if (triggerType ==
                                            FloatingSheetType.priority) {
                                          _newTaskPriority = sel;
                                        } else if (triggerType ==
                                            FloatingSheetType.remind) {
                                          _newTaskReminder = sel;
                                        } else if (triggerType ==
                                            FloatingSheetType.assign) {
                                          if (_newTaskAssignee == null ||
                                              _newTaskAssignee!.isEmpty)
                                            _newTaskAssignee = sel;
                                          else if (!_newTaskAssignee!.contains(
                                            sel,
                                          ))
                                            _newTaskAssignee =
                                                '$_newTaskAssignee, $sel';
                                        } else if (triggerType ==
                                            FloatingSheetType.deadline) {
                                          _newTaskDeadline = sel;
                                        } else if (triggerType ==
                                            FloatingSheetType.workType) {
                                          _newTaskWorkType = sel;
                                        } else if (triggerType ==
                                            FloatingSheetType.folder) {
                                          _newTaskFolder = sel;
                                        } else if (triggerType ==
                                            FloatingSheetType.clientName) {
                                          _newTaskClientName = sel;
                                        } else if (triggerType ==
                                            FloatingSheetType.refProject) {
                                          _newTaskRefProject = sel;
                                        }
                                      });
                                      setModalState(() {});
                                    },
                                  );
                                }
                              },
                              onSubmitted: (_) async {
                                await _handleAddTaskFromSheet();
                                setModalState(() {});
                              },
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            await _handleAddTaskFromSheet();
                            setModalState(() {});
                          },
                          icon: const Icon(Icons.send, color: secondaryColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 56,
                      child: (kIsWeb && screenWidth >= 600)
                          ? Center(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: _buttonOrder.map((type) {
                                  return _buildBottomSheetButtonWithState(
                                    type,
                                    setModalState,
                                  );
                                }).toList(),
                              ),
                            )
                          : ScrollConfiguration(
                              behavior: ScrollConfiguration.of(sheetContext)
                                  .copyWith(
                                    dragDevices: {
                                      PointerDeviceKind.touch,
                                      PointerDeviceKind.mouse,
                                      PointerDeviceKind.trackpad,
                                    },
                                  ),
                              child: ReorderableListView.builder(
                                scrollDirection: Axis.horizontal,
                                physics: const ClampingScrollPhysics(),
                                buildDefaultDragHandles: false,
                                itemCount: _buttonOrder.length,
                                onReorder: (oldIndex, newIndex) {
                                  setState(() {
                                    if (newIndex > oldIndex) newIndex -= 1;
                                    final item = _buttonOrder.removeAt(
                                      oldIndex,
                                    );
                                    _buttonOrder.insert(newIndex, item);
                                  });
                                  _saveButtonOrder();
                                  setModalState(() {});
                                },
                                itemBuilder: (context, index) {
                                  final type = _buttonOrder[index];
                                  return Padding(
                                    key: ValueKey(type),
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ReorderableDelayedDragStartListener(
                                      index: index,
                                      child: _buildBottomSheetButtonWithState(
                                        type,
                                        setModalState,
                                      ),
                                    ),
                                  );
                                },
                              ),
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
      _focusNode.unfocus();
      FocusScope.of(context).unfocus();
      if (!kIsWeb) {
        SystemChannels.textInput.invokeMethod('textInput.hide');
      }
    });
  }

  void _openTaskDetail(Task task) {
    context.push('/task', extra: task);
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
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        decoration: task.isDone
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    if (task.workType != null && task.workType!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(
                          task.workType!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: task.isDone
                                ? Colors.grey.shade500
                                : Colors.grey.shade700,
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
      bool isAssignee =
          assignee.isNotEmpty &&
          ((myName.isNotEmpty && assignee.contains(myName)) ||
              (myEmail.isNotEmpty && assignee.contains(myEmail)) ||
              (myUid.isNotEmpty && assignee.contains(myUid)));

      return isCreator || isAssignee;
    }).toList();
  }

  Widget _buildTaskList(List<Task> list) {
    if (list.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            "No tasks found in this category.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
      itemCount: list.length,
      itemBuilder: (context, index) {
        return Column(
          children: [
            _buildTaskTile(list[index], index),
            _thinHairline(indent: 15, endIndent: 15, opacity: 0.05),
          ],
        );
      },
    );
  }

  Widget _buildGroupByAssignView() {
    final Map<String, List<Task>> grouped = {};
    for (var t in tasks) {
      final assignee = (t.assignee == null || t.assignee!.trim().isEmpty)
          ? 'Unassigned'
          : t.assignee!.trim();
      grouped.putIfAbsent(assignee, () => []).add(t);
    }

    if (grouped.isEmpty) {
      return const Center(
        child: Text(
          'No assignee data available.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final assignees = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: assignees.length,
      itemBuilder: (context, index) {
        final assigneeName = assignees[index];
        final assigneeTasks = grouped[assigneeName]!;
        final completedCount = assigneeTasks.where((t) => t.isDone).length;
        final pendingCount = assigneeTasks.length - completedCount;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            leading: CircleAvatar(
              backgroundColor: primaryColor.withOpacity(0.3),
              child: Text(
                assigneeName.isNotEmpty ? assigneeName[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: secondaryColor,
                ),
              ),
            ),
            title: Text(
              assigneeName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Total: ${assigneeTasks.length} • Pending: $pendingCount • Done: $completedCount',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: secondaryColor,
            ),
            onTap: () => _showAssigneeTasksModal(assigneeName, assigneeTasks),
          ),
        );
      },
    );
  }

  void _showAssigneeTasksModal(String assigneeName, List<Task> assigneeTasks) {
    context.push(
      '/assignee-tasks',
      extra: {'assigneeName': assigneeName, 'tasks': assigneeTasks},
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool selectionActive = _selected.isNotEmpty;

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
            ),
      drawer: selectionActive ? null : const AppDrawer(),
      body: tasks.isEmpty && !selectionActive
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  "Tasks show up here if they aren't part of any lists you've created.",
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: [
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
                      fontSize: 14,
                    ),
                    unselectedLabelColor: Colors.grey.shade500,
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                    tabs: [
                      Tab(text: 'My Work (${_getMyTasks().length})'),
                      Tab(text: 'All Work (${tasks.length})'),
                      Tab(text: 'Done (${_getDoneTasks().length})'),
                      Tab(text: 'Overdue (${_getOverdueTasks().length})'),
                      Tab(text: 'Pending (${_getPendingTasks().length})'),
                      const Tab(text: 'Group By Assign'),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTaskList(_getMyTasks()),
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
