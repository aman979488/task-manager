import 'package:flutter/material.dart';

import '../models/task.dart';
import '../models/floating_sheet_type.dart';
import '../utils/task_title_formatter.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';

import '../../../viewmodels/auth_viewmodel.dart';
import '../services/task_assignment_notification_service.dart';
import '../models/quick_date_time_option.dart';
import 'views/date_time_picker_dialog.dart';

class TaskDetailPage extends StatefulWidget {
  final Task task;
  final VoidCallback onChanged;
  final Future<void> Function() onSave;

  const TaskDetailPage({
    super.key,
    required this.task,
    required this.onSave,
    VoidCallback? onChanged,
  }) : onChanged = onChanged ?? _defaultCallback;

  static void _defaultCallback() {}

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  final TaskAssignmentNotificationService _assignmentNotificationService =
      TaskAssignmentNotificationService();
  OverlayEntry? _overlayEntry;
  late TextEditingController _noteController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showAdditionalDetails = false;
  Future<String?>? _createdByNameFuture;

  // for steps
  late TextEditingController _stepController;
  final FocusNode _stepFocusNode = FocusNode();
  bool _isAddingStep = false;
  int? _editingStepIndex;

  // for editing main title
  late TextEditingController _titleController;
  bool _isEditingTitle = false;

  Task get task => widget.task;

  // Caches for Firestore-loaded lists
  List<String>? _workTypesCache;
  List<String>? _assigneesCache;
  List<String>? _clientsCache;
  List<String>? _foldersCache;
  List<String>? _projectsCache; // 🚀 NAYA
  bool _isSaving = false;

  static const Color primaryColor = Color(0xFFFBE64E);
  static const Color secondaryColor = Color(0xFF6B5800);

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: task.note);
    _stepController = TextEditingController();
    _titleController = TextEditingController(text: task.title);
  }

  @override
  void dispose() {
    _hideOverlay();
    task.note = _noteController.text;
    task.title = _titleController.text;
    _noteController.dispose();
    _stepController.dispose();
    _stepFocusNode.dispose();
    _searchController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<List<String>> _loadWorkTypesFromFirestore() async {
    if (_workTypesCache != null) return _workTypesCache!;
    final snap = await FirebaseFirestore.instance.collection('WorkType').get();
    final values = snap.docs
        .map((d) => (d.data()['workType'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toList();
    _workTypesCache = values;
    return values;
  }

  Future<List<String>> _loadAssigneesFromFirestore() async {
    if (_assigneesCache != null) return _assigneesCache!;
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
      addName(data['name'] ?? data['fullName'] ?? data['email'] ?? doc.id);
    }
    for (final doc in snapshots[1].docs) {
      final data = doc.data();
      addName(
        data['cpName'] ??
            data['name'] ??
            data['fullName'] ??
            data['email'] ??
            doc.id,
      );
    }

    final values = valuesByName.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    _assigneesCache = values;
    return values;
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

  Future<List<String>> _loadFoldersFromFirestore() async {
    if (_foldersCache != null) return _foldersCache!;
    _foldersCache = ['Personal', 'Office', 'Freelance'];
    return _foldersCache!;
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _searchController.clear();
    _searchQuery = '';
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

  Future<void> _showOverlay(
    BuildContext buttonContext,
    FloatingSheetType type, {
    String? fieldKey,
  }) async {
    if (_overlayEntry != null) _hideOverlay();

    String resolvedKey;
    if (fieldKey != null) {
      resolvedKey = fieldKey;
    } else {
      switch (type) {
        case FloatingSheetType.priority:
          resolvedKey = 'priority';
          break;
        case FloatingSheetType.remind:
          resolvedKey = 'reminder';
          break;
        case FloatingSheetType.assign:
          resolvedKey = 'assignee';
          break;
        case FloatingSheetType.deadline:
          resolvedKey = 'deadline';
          break;
        case FloatingSheetType.workType:
          resolvedKey = 'workType';
          break;
        case FloatingSheetType.folder:
          resolvedKey = 'folder';
          break;
        case FloatingSheetType.clientName:
          resolvedKey = 'clientName';
          break;
        case FloatingSheetType.refProject:
          resolvedKey = 'refProject';
          break;
      }
    }

    List<String>? workTypes;
    List<String>? assignees;
    List<String>? clients;
    List<String>? folders;
    List<String>? projects; // 🚀 NAYA

    if (resolvedKey == 'workType') {
      workTypes = await _loadWorkTypesFromFirestore();
    } else if (resolvedKey == 'assignee') {
      assignees = await _loadAssigneesFromFirestore();
    } else if (resolvedKey == 'clientName') {
      clients = await _loadClientsFromFirestore();
    } else if (resolvedKey == 'folder') {
      folders = await _loadFoldersFromFirestore();
    } else if (resolvedKey == 'refProject') {
      if (_projectsCache == null) {
        final snap = await FirebaseFirestore.instance
            .collection('projects')
            .get();
        _projectsCache = snap.docs
            .map((d) => d['projectName']?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList();
      }
      projects = _projectsCache;
    }

    if (!mounted || !buttonContext.mounted) return;
    final OverlayState overlayState = Overlay.of(buttonContext);
    final RenderBox button = buttonContext.findRenderObject() as RenderBox;
    final RenderBox overlayBox =
        overlayState.context.findRenderObject() as RenderBox;
    final Offset buttonPosition = button.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final Size buttonSize = button.size;

    List<Widget> tilesFor(String key) {
      switch (key) {
        case 'priority':
          return const [
            ListTile(title: Text("U1")),
            ListTile(title: Text("U2")),
            ListTile(title: Text("U3")),
            ListTile(title: Text("IMP")),
            ListTile(title: Text("Today")),
            ListTile(title: Text("Tomorrow")),
            ListTile(title: Text("Day Later")),
            ListTile(title: Text("Later")),
            ListTile(title: Text("Process")),
            ListTile(title: Text("Hold")),
            ListTile(title: Text("Free")),
          ];
        case 'reminder':
        case 'deadline':
          return [
            ...QuickDateTimeOptions.options().map(
              (option) => ListTile(
                leading: const Icon(Icons.access_time),
                title: Text(option.label),
              ),
            ),
            const ListTile(
              leading: Icon(Icons.calendar_month),
              title: Text("Custom"),
            ),
          ];
        case 'assignee':
          if (assignees == null || assignees.isEmpty) {
            return const [
              ListTile(
                leading: Icon(Icons.person),
                title: Text("Assign to me"),
              ),
              ListTile(
                leading: Icon(Icons.group),
                title: Text("Assign to someone else"),
              ),
            ];
          }
          return assignees.map((v) => ListTile(title: Text(v))).toList();
        case 'workType':
          return (workTypes ?? [])
              .map((v) => ListTile(title: Text(v)))
              .toList();
        case 'clientName':
          if (clients == null || clients.isEmpty) {
            return const [ListTile(title: Text("No clients found"))];
          }
          return clients.map((v) => ListTile(title: Text(v))).toList();
        case 'refProject':
          return (projects ?? []).map((v) => ListTile(title: Text(v))).toList();
        case 'folder':
          return (folders ?? []).map((v) => ListTile(title: Text(v))).toList();
        default:
          return [];
      }
    }

    final tileWidgets = tilesFor(resolvedKey);

    final bool hasSearchBar =
        resolvedKey == 'assignee' ||
        resolvedKey == 'workType' ||
        resolvedKey == 'clientName' ||
        resolvedKey == 'refProject';

    const double menuWidth = 260;
    const double padding = 8;

    double left = buttonPosition.dx + buttonSize.width - menuWidth;
    if (left < padding) left = padding;

    double top = buttonPosition.dy + buttonSize.height + padding;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _hideOverlay,
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.shrink(),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              child: Material(
                color: Colors.white,
                elevation: 6,
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: menuWidth,
                  child: StatefulBuilder(
                    builder: (context, setOverlayState) {
                      final allTiles = tileWidgets;
                      final filteredTiles =
                          hasSearchBar && _searchQuery.isNotEmpty
                          ? allTiles.where((tile) {
                              if (tile is! ListTile) return true;
                              final text = (tile.title as Text).data ?? '';
                              return text.toLowerCase().contains(
                                _searchQuery.toLowerCase(),
                              );
                            }).toList()
                          : allTiles;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasSearchBar)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
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
                                    color: Colors.grey.shade500,
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
                            constraints: const BoxConstraints(maxHeight: 220),
                            child: filteredTiles.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      'No results found',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  )
                                : ListView(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    children: filteredTiles.map((tile) {
                                      return InkWell(
                                        onTap: () async {
                                          if (tile is ListTile) {
                                            final label =
                                                (tile.title as Text).data ?? '';

                                            if (resolvedKey == 'reminder' ||
                                                resolvedKey == 'deadline') {
                                              DateTime? computed;

                                              if (label.toLowerCase().contains(
                                                'custom',
                                              )) {
                                                _hideOverlay();
                                                computed =
                                                    await showDateTimePickerWithTabs(
                                                      context,
                                                    );
                                              } else {
                                                computed =
                                                    QuickDateTimeOptions.resolve(
                                                      label,
                                                    );
                                              }

                                              if (computed != null) {
                                                final iso = computed
                                                    .toIso8601String();
                                                setState(() {
                                                  if (resolvedKey ==
                                                      'reminder') {
                                                    task.reminder = iso;
                                                  } else {
                                                    task.deadline = iso;
                                                  }
                                                });
                                                widget.onChanged();
                                              }
                                            } else {
                                              setState(() {
                                                switch (resolvedKey) {
                                                  case 'priority':
                                                    task.priority = label;
                                                    task.priorityUpdatedAt =
                                                        DateTime.now()
                                                            .millisecondsSinceEpoch;
                                                    break;
                                                  case 'assignee':
                                                    task.assignee = label;
                                                    _sendTaskAssignmentNotification(
                                                      label,
                                                      task.title,
                                                      context,
                                                    );
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
                                                  default:
                                                    break;
                                                }
                                              });
                                              widget.onChanged();
                                            }

                                            _searchController.clear();
                                            _searchQuery = '';
                                            _hideOverlay();
                                          } else {
                                            _hideOverlay();
                                          }
                                        },
                                        child: tile,
                                      );
                                    }).toList(),
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
        );
      },
    );

    overlayState.insert(_overlayEntry!);
  }

  void _saveTitle(String value) {
    final text = value.trim();
    if (text.isEmpty) return;
    setState(() {
      task.title = text;
      _titleController.text = text;
      _isEditingTitle = false;
    });
    widget.onChanged();
  }

  void _saveStep(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      _stepFocusNode.requestFocus();
      return;
    }
    setState(() {
      task.steps.add(TaskStep(title: text));
      _stepController.clear();
    });
    widget.onChanged();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isAddingStep) _stepFocusNode.requestFocus();
    });
  }

  void _startEditStep(int index) {
    setState(() {
      _editingStepIndex = index;
      _isAddingStep = false;
      _stepController.text = task.steps[index].title;
    });
  }

  void _saveEditedStep(int index, String value) {
    final text = value.trim();
    if (text.isEmpty) return;
    setState(() {
      task.steps[index].title = text;
      _editingStepIndex = null;
      _stepController.clear();
    });
    widget.onChanged();
  }

  Future<void> _confirmDeleteStep(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete step'),
          scrollable: true,
          content: const Text('Are you sure you want to delete this sub-step?'),
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
      setState(() {
        if (index >= 0 && index < task.steps.length) {
          task.steps.removeAt(index);
        }
      });
      widget.onChanged();
    }
  }

  Widget _buildStepTile(TaskStep step, int index) {
    final isEditing = _editingStepIndex == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              setState(() => step.isDone = !step.isDone);
              widget.onChanged();
            },
            child: Icon(
              step.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 22,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: isEditing
                ? TextField(
                    controller: _stepController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                    ),
                    onSubmitted: (val) => _saveEditedStep(index, val),
                  )
                : GestureDetector(
                    onTap: () => _startEditStep(index),
                    child: Text(
                      step.title,
                      style: TextStyle(
                        fontSize: 15,
                        decoration: step.isDone
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                  ),
          ),
          if (isEditing)
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.close, size: 18),
              onPressed: () {
                setState(() {
                  _editingStepIndex = null;
                  _stepController.clear();
                });
              },
            )
          else
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(
                Icons.delete_outline,
                size: 20,
                color: Colors.redAccent,
              ),
              onPressed: () => _confirmDeleteStep(index),
              tooltip: 'Delete sub-step',
            ),
        ],
      ),
    );
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
      child: child,
    );
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
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final date = DateTime(dt.year, dt.month, dt.day);

      final timeStr =
          '${dt.hour % 12 == 0 ? 12 : dt.hour % 12}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}';

      String display;
      if (date == today) {
        display = 'Today $timeStr';
      } else if (date == tomorrow) {
        display = 'Tomorrow $timeStr';
      } else {
        display = '${dt.day}/${dt.month} $timeStr';
      }

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

  Future<void> _saveTask() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    task
      ..title = _titleController.text
      ..note = _noteController.text;
    try {
      await widget.onSave();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Task saved')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Could not save task: $error')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _priorityBadgeHeader() {
    final p = task.priority;
    if (p == null || p.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: secondaryColor),
      ),
      child: Text(
        p,
        style: const TextStyle(
          fontSize: 13,
          color: secondaryColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _openFile(TaskFile file) async {
    if (kIsWeb) {
      if (file.path != null && file.path!.isNotEmpty) {
        final uri = Uri.parse(file.path!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File cannot be opened on web.')),
          );
        }
      }
    } else {
      if (file.path != null && file.path!.isNotEmpty) {
        final uri = Uri.file(file.path!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Cannot open file: ${file.name}')),
            );
          }
        }
      }
    }
  }

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
            onPressed: _isSaving ? null : _saveTask,
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
                child: ListView(
                  children: [
                    // ── Title row ───────────────────────────────────
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() => task.isDone = !task.isDone);
                            widget.onChanged();
                          },
                          child: Icon(
                            task.isDone
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            size: 26,
                            color: secondaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _isEditingTitle
                              ? TextField(
                                  controller: _titleController,
                                  autofocus: true,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  onSubmitted: _saveTitle,
                                )
                              : GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isEditingTitle = true;
                                      _titleController.text = task.title;
                                    });
                                  },
                                  child: Text(
                                    capitalizeFirstCharacter(task.title),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      decoration: task.isDone
                                          ? TextDecoration.lineThrough
                                          : TextDecoration.none,
                                    ),
                                  ),
                                ),
                        ),
                        _priorityBadgeHeader(),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // ── Steps ────────────────────────────────────────
                    if (task.steps.isNotEmpty)
                      ...task.steps.asMap().entries.map(
                        (e) => _buildStepTile(e.value, e.key),
                      ),

                    if (_isAddingStep)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            const Icon(Icons.radio_button_unchecked, size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _stepController,
                                focusNode: _stepFocusNode,
                                autofocus: true,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  hintText: "Add step",
                                  border: InputBorder.none,
                                ),
                                onSubmitted: _saveStep,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _stepFocusNode.unfocus();
                                setState(() {
                                  _isAddingStep = false;
                                  _stepController.clear();
                                });
                              },
                            ),
                          ],
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _editingStepIndex = null;
                            _isAddingStep = true;
                            _stepController.clear();
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: const [
                              Icon(Icons.add, color: secondaryColor, size: 20),
                              SizedBox(width: 8),
                              Text(
                                "Add step",
                                style: TextStyle(
                                  color: secondaryColor,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 8),

                    // ── Fields ───────────────────────────────────────
                    Builder(
                      builder: (buttonContext) => _animatedBorderedTile(
                        isSelected: _isSelected(task.priority),
                        child: ListTile(
                          leading: const Icon(
                            Icons.flag_sharp,
                            color: secondaryColor,
                          ),
                          title: const Text("Priority"),
                          trailing: _infoTrailing(task.priority),
                          onTap: () => _showOverlay(
                            buttonContext,
                            FloatingSheetType.priority,
                          ),
                        ),
                      ),
                    ),
                    Builder(
                      builder: (buttonContext) => _animatedBorderedTile(
                        isSelected: _isSelected(task.workType),
                        child: ListTile(
                          leading: const Icon(
                            Icons.insert_drive_file,
                            color: secondaryColor,
                          ),
                          title: const Text("Work Type"),
                          trailing: _infoTrailing(task.workType),
                          onTap: () => _showOverlay(
                            buttonContext,
                            FloatingSheetType.workType,
                            fieldKey: 'workType',
                          ),
                        ),
                      ),
                    ),
                    Builder(
                      builder: (buttonContext) => _animatedBorderedTile(
                        isSelected: _isSelected(task.reminder),
                        child: ListTile(
                          leading: const Icon(
                            Icons.notifications_active,
                            color: secondaryColor,
                          ),
                          title: const Text("Remind Me"),
                          trailing: _infoTrailing(task.reminder),
                          onTap: () => _showOverlay(
                            buttonContext,
                            FloatingSheetType.remind,
                          ),
                        ),
                      ),
                    ),
                    Builder(
                      builder: (buttonContext) => _animatedBorderedTile(
                        isSelected: _isSelected(task.assignee),
                        child: ListTile(
                          leading: const Icon(
                            Icons.checklist,
                            color: secondaryColor,
                          ),
                          title: const Text("Assign"),
                          trailing: _infoTrailing(task.assignee),
                          onTap: () => _showOverlay(
                            buttonContext,
                            FloatingSheetType.assign,
                          ),
                        ),
                      ),
                    ),
                    Builder(
                      builder: (buttonContext) => _animatedBorderedTile(
                        isSelected: _isSelected(task.clientName),
                        child: ListTile(
                          leading: const Icon(
                            Icons.business_center_outlined,
                            color: secondaryColor,
                          ),
                          title: const Text("Client Name"),
                          trailing: _infoTrailing(task.clientName),
                          onTap: () => _showOverlay(
                            buttonContext,
                            FloatingSheetType.clientName,
                            fieldKey: 'clientName',
                          ),
                        ),
                      ),
                    ),
                    Builder(
                      builder: (buttonContext) => _animatedBorderedTile(
                        isSelected: _isSelected(task.deadline),
                        child: ListTile(
                          leading: const Icon(
                            Icons.alarm,
                            color: secondaryColor,
                          ),
                          title: const Text("Deadline"),
                          trailing: _infoTrailing(task.deadline),
                          onTap: () => _showOverlay(
                            buttonContext,
                            FloatingSheetType.deadline,
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => setState(
                          () =>
                              _showAdditionalDetails = !_showAdditionalDetails,
                        ),
                        icon: Icon(
                          _showAdditionalDetails
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: secondaryColor,
                        ),
                        label: Text(
                          _showAdditionalDetails ? 'View less' : 'View more',
                          style: const TextStyle(color: secondaryColor),
                        ),
                      ),
                    ),
                    if (_showAdditionalDetails) ...[
                      Builder(
                        builder: (buttonContext) => _animatedBorderedTile(
                          isSelected: _isSelected(task.refProject),
                          child: ListTile(
                            leading: const Icon(
                              Icons.apartment_outlined,
                              color: secondaryColor,
                            ),
                            title: const Text("Ref Project"),
                            trailing: _infoTrailing(task.refProject),
                            onTap: () => _showOverlay(
                              buttonContext,
                              FloatingSheetType.refProject,
                              fieldKey: 'refProject',
                            ),
                          ),
                        ),
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
                        onTap: (buttonContext) => _editExtraField(
                          buttonContext,
                          'Accompanied By',
                          task.accompaniedBy,
                          (value) => task.accompaniedBy = value,
                        ),
                      ),
                      _buildExtraFieldTile(
                        label: 'Monitor',
                        value: task.monitor,
                        icon: Icons.desktop_windows_outlined,
                        onTap: (buttonContext) => _editExtraField(
                          buttonContext,
                          'Monitor',
                          task.monitor,
                          (value) => task.monitor = value,
                        ),
                      ),
                      Builder(
                        builder: (buttonContext) => _animatedBorderedTile(
                          isSelected: _isSelected(task.folder),
                          child: ListTile(
                            leading: const Icon(
                              Icons.folder_outlined,
                              color: secondaryColor,
                            ),
                            title: const Text("Folder"),
                            trailing: _infoTrailing(task.folder),
                            onTap: () => _showOverlay(
                              buttonContext,
                              FloatingSheetType.folder,
                              fieldKey: 'folder',
                            ),
                          ),
                        ),
                      ),
                      _buildExtraFieldTile(
                        label: 'Remark',
                        value: task.remark,
                        icon: Icons.notes,
                        onTap: (buttonContext) => _editExtraField(
                          buttonContext,
                          'Remark',
                          task.remark,
                          (value) => task.remark = value,
                        ),
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        "Add note",
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
                          widget.onChanged();
                        },
                        decoration: const InputDecoration(
                          hintText: "Add note",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // ── Uploaded files ───────────────────────────────
                    if (task.files.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Uploaded Files",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...task.files.asMap().entries.map((entry) {
                            final index = entry.key;
                            final file = entry.value;
                            return InkWell(
                              onTap: () => _openFile(file),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.insert_drive_file,
                                      color: secondaryColor,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            file.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "${(file.size / 1024).toStringAsFixed(1)} KB",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 20),
                                      onPressed: () {
                                        setState(() {
                                          task.files.removeAt(index);
                                        });
                                        widget.onChanged();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                        ],
                      ),

                    const SizedBox(height: 15),

                    // ── Creator & Editor ───────────────────────────────
                    if (task.createdBy != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: FutureBuilder<String?>(
                          future: _createdByNameFuture ??= _loadCreatorName(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              debugPrint(
                                'Could not load task creator name: ${snapshot.error}',
                              );
                            }
                            final metadataName = _metadataCreatorName();
                            final emailName = _creatorEmailName();
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
                ),
              ),
            ),
          );
        },
      ),
    );
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

  String? _metadataCreatorName() {
    final metadata = task.createdBy;
    if (metadata == null) return null;
    for (final key in [
      'name',
      'displayName',
      'fullName',
      'userName',
      'cpName',
    ]) {
      final value = metadata[key]?.toString().trim();
      if (value != null &&
          value.isNotEmpty &&
          value.toLowerCase() != 'user' &&
          value.toLowerCase() != 'unknown') {
        return value;
      }
    }
    return null;
  }

  String? _creatorEmailName() {
    final email = task.createdBy?['email']?.toString().trim() ?? '';
    if (email.isEmpty) return null;
    return email.contains('@') ? email.split('@').first : email;
  }

  Future<String?> _loadCreatorName() async {
    if (_metadataCreatorName() != null) return _metadataCreatorName();

    final metadata = task.createdBy;
    if (metadata == null) return null;
    final uid = metadata['uid']?.toString().trim() ?? '';
    final email = metadata['email']?.toString().trim() ?? '';
    final users = FirebaseFirestore.instance.collection('users');

    if (uid.isNotEmpty) {
      final profile = await users.where('uid', isEqualTo: uid).limit(1).get();
      if (profile.docs.isNotEmpty) {
        final profileName = _profileName(profile.docs.first.data());
        if (profileName != null) return profileName;
      }

      final profileById = await users.doc(uid).get();
      final profileName = _profileName(profileById.data());
      if (profileName != null) return profileName;
    }

    if (email.isNotEmpty) {
      final profile = await users
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (profile.docs.isNotEmpty) {
        return _profileName(profile.docs.first.data());
      }
    }
    return null;
  }

  String? _profileName(Map<String, dynamic>? profile) {
    if (profile == null) return null;
    for (final key in [
      'name',
      'displayName',
      'fullName',
      'userName',
      'cpName',
    ]) {
      final value = profile[key]?.toString().trim();
      if (value != null &&
          value.isNotEmpty &&
          value.toLowerCase() != 'user' &&
          value.toLowerCase() != 'unknown') {
        return value;
      }
    }
    return null;
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

  Future<void> _editExtraField(
    BuildContext buttonContext,
    String label,
    String? value,
    void Function(String) onChanged,
  ) async {
    final controller = TextEditingController(text: value);
    final updatedValue = await showDialog<String>(
      context: buttonContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: label == 'Remark' ? 3 : 1,
          decoration: InputDecoration(hintText: 'Enter $label'),
          textInputAction: label == 'Remark'
              ? TextInputAction.newline
              : TextInputAction.done,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (updatedValue == null || !mounted) return;
    setState(() => onChanged(updatedValue));
    widget.onChanged();
  }
}
