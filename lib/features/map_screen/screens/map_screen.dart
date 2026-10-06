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
  String _priorityFilter = 'All';
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
  List<String>? _clientsCache;
  List<String>? _projectsCache; // 🚀 NAYA

  static const Color primaryColor = Color(0xFFFBE64E);
  static const Color secondaryColor = Color(0xFF6B5800);

  late TabController _tabController;
  String? _expandedMyWorkSection;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadButtonOrder();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTasksFromFirebase();
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

    if (!mounted) return;
    setState(() {
      tasks
        ..clear()
        ..addAll(loaded);
      if (_priorityFilter != 'All' && !loaded.any(_matchesPriorityFilter)) {
        _priorityFilter = 'All';
      }
    });
    await updateTaskHomeWidget(tasks);
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
    final docRef = await tasksCollection.add(_taskData(task));
    task.id = docRef.id;
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

    var added = false;
    try {
      await _addTaskToFirebase(newTask);
      added = true;

      if (assignee != null && assignee.trim().isNotEmpty) {
        _sendTaskAssignmentNotification(assignee, text, authVM);
      }

      if (_isTaskVisibleToUser(newTask, authVM)) {
        setState(() {
          tasks.add(newTask);
          _sortTasks();
        });
        await updateTaskHomeWidget(tasks);
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
    return added;
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
                                final cursor = taskName.selection.baseOffset;
                                if (cursor <= 0 || cursor > val.length) return;
                                final ch = val[cursor - 1];
                                final prev = cursor >= 2
                                    ? val[cursor - 2]
                                    : ' ';

                                FloatingSheetType? triggerType;
                                String symbol = '';
                                if (ch == '@') {
                                  triggerType = FloatingSheetType.assign;
                                  symbol = '@';
                                } else if (ch == '#') {
                                  triggerType = FloatingSheetType.clientName;
                                  symbol = '#';
                                } else if (ch == '-') {
                                  triggerType = FloatingSheetType.priority;
                                  symbol = '-';
                                } else if (ch == '!') {
                                  triggerType = FloatingSheetType.deadline;
                                  symbol = '!';
                                } else if (ch == '+') {
                                  triggerType = FloatingSheetType.workType;
                                  symbol = '+';
                                } else if (ch == '*') {
                                  triggerType = FloatingSheetType.remind;
                                  symbol = '*';
                                } else if (ch == '^') {
                                  triggerType = FloatingSheetType.refProject;
                                  symbol = '^';
                                }

                                if (triggerType != null) {
                                  final bool isMulti =
                                      triggerType == FloatingSheetType.assign;
                                  if (triggerType != FloatingSheetType.assign &&
                                      prev != ' ' &&
                                      prev != '\n') {
                                    return;
                                  }

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
                                          final cursor = taskName
                                              .selection
                                              .baseOffset
                                              .clamp(0, currentText.length)
                                              .toInt();
                                          final mentionStart = cursor > 0
                                              ? currentText.lastIndexOf(
                                                  symbol,
                                                  cursor - 1,
                                                )
                                              : -1;
                                          if (mentionStart >= 0) {
                                            final beforeMention = currentText
                                                .substring(0, mentionStart);
                                            var afterMention = currentText
                                                .substring(cursor);
                                            final beforeEndsWithWhitespace =
                                                beforeMention.endsWith(' ') ||
                                                beforeMention.endsWith('\n');
                                            final afterStartsWithWhitespace =
                                                afterMention.startsWith(' ') ||
                                                afterMention.startsWith('\n');

                                            if (beforeEndsWithWhitespace &&
                                                afterStartsWithWhitespace) {
                                              afterMention = afterMention
                                                  .substring(1);
                                            }

                                            final separator =
                                                beforeMention.isNotEmpty &&
                                                    afterMention.isNotEmpty &&
                                                    !beforeEndsWithWhitespace &&
                                                    !afterStartsWithWhitespace
                                                ? ' '
                                                : '';
                                            taskName.text =
                                                '$beforeMention$separator$afterMention';
                                            taskName.selection =
                                                TextSelection.collapsed(
                                                  offset:
                                                      beforeMention.length +
                                                      separator.length,
                                                );
                                          }
                                        } else {
                                          taskName.text =
                                              '$currentText$insertVal ';
                                        }

                                        if (!isMulti) {
                                          taskName.selection =
                                              TextSelection.collapsed(
                                                offset: taskName.text.length,
                                              );
                                        }

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
                                final added = await _handleAddTaskFromSheet();
                                if (added && sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                              },
                            ),
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
    final pendingTasks = myTasks.where((task) => !task.isDone);
    final scheduledTasks = pendingTasks
        .map((task) => (task: task, date: _myWorkDeadline(task)))
        .where((entry) => entry.date != null)
        .toList();

    return {
      'Urgent Works': pendingTasks
          .where((task) => task.priority?.trim().toLowerCase() == 'urgent')
          .toList(),
      'Overdue Works': scheduledTasks
          .where((entry) => entry.date!.isBefore(now))
          .map((entry) => entry.task)
          .toList(),
      'Tomorrow Works': scheduledTasks
          .where((entry) => _isTomorrow(entry.date!, now))
          .map((entry) => entry.task)
          .toList(),
      'IMP Works': pendingTasks
          .where((task) => task.priority?.trim().toLowerCase() == 'imp')
          .toList(),
      'Upcoming Works': scheduledTasks
          .where(
            (entry) =>
                !entry.date!.isBefore(now) &&
                (entry.task.priority?.trim().isEmpty ?? true),
          )
          .map((entry) => entry.task)
          .toList(),
      'Upcoming Reminders': pendingTasks.where((task) {
        final reminder = DateTime.tryParse(task.reminder ?? '');
        return !task.reminderSent && reminder != null && reminder.isAfter(now);
      }).toList(),
    };
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
      'Overdue Works',
      'Tomorrow Works',
      'IMP Works',
      'Upcoming Works',
      'Upcoming Reminders',
    ];
    final expandedName = _expandedMyWorkSection;
    final expandedTasks = expandedName == null
        ? const <Task>[]
        : _getVisibleTasks(sections[expandedName] ?? const <Task>[]);
    final sectionColors = <String, Color>{
      'Urgent Works': Colors.deepOrange,
      'Overdue Works': Colors.redAccent,
      'Tomorrow Works': Colors.blue,
      'IMP Works': Colors.purple,
      'Upcoming Works': Colors.teal,
      'Upcoming Reminders': Colors.indigo,
    };

    return _refreshableScrollView(
      SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final name in sectionNames) ...[
              Builder(
                builder: (context) {
                  final color = sectionColors[name]!;
                  final count = sections[name]?.length ?? 0;
                  final isExpanded = expandedName == name;

                  return Column(
                    children: [
                      InkWell(
                        onTap: () => setState(() {
                          _expandedMyWorkSection = isExpanded ? null : name;
                        }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Text(
                                name.toUpperCase(),
                                style: TextStyle(
                                  color: color,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                constraints: const BoxConstraints(minWidth: 36),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$count',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: color,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isExpanded) _buildMyWorkTaskResults(expandedTasks),
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
              _matchesPriorityFilter(task) &&
              (query.isEmpty ||
                  task.title.toLowerCase().contains(query) ||
                  (task.assignee ?? '').toLowerCase().contains(query) ||
                  (task.workType ?? '').toLowerCase().contains(query) ||
                  (task.priority ?? '').toLowerCase().contains(query)),
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

  bool _matchesPriorityFilter(Task task) =>
      _priorityFilter == 'All' ||
      task.priority?.trim().toLowerCase() == _priorityFilter.toLowerCase();

  List<String> _availablePriorityFilters(List<Task> source) {
    final priorities =
        source
            .map((task) => task.priority?.trim() ?? '')
            .where((priority) => priority.isNotEmpty)
            .toSet()
            .toList()
          ..sort(
            (first, second) =>
                _priorityOrder(first).compareTo(_priorityOrder(second)),
          );
    return ['All', ...priorities];
  }

  Widget _buildPriorityFilters() {
    final options = _availablePriorityFilters(tasks);
    if (options.length <= 1) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: options
            .map(
              (priority) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(priority == 'All' ? 'All priorities' : priority),
                  selected: _priorityFilter == priority,
                  onSelected: (_) => setState(() => _priorityFilter = priority),
                ),
              ),
            )
            .toList(),
      ),
    );
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
    return ListTile(
      dense: true,
      selected: isSelected,
      leading: Checkbox(
        value: task.isDone,
        activeColor: secondaryColor,
        onChanged: (_) async {
          setState(() => task.isDone = !task.isDone);
          await _updateTaskInFirebase(task);
        },
      ),
      title: Text(
        task.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          decoration: task.isDone ? TextDecoration.lineThrough : null,
          color: task.isDone ? Colors.grey : Colors.black87,
        ),
      ),
      subtitle: Text(
        [
          if (task.priority?.isNotEmpty == true) task.priority!,
          if (task.assignee?.isNotEmpty == true) task.assignee!,
        ].join(' • '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: primaryColor.withOpacity(0.3),
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
                fontSize: 14,
              ),
              unselectedLabelColor: Colors.grey.shade500,
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              labelPadding: const EdgeInsets.symmetric(horizontal: 16),
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
          if (!selectionActive && _selectedTabIndex != 5)
            _buildPriorityFilters(),
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
