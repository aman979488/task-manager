import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 🚀 NAYA: For SystemChannels keyboard show/hide
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';
import '../models/floating_sheet_type.dart';

import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';

import '../../../widgets/app_drawer.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../services/home_screen_shortcut.dart';
import '../viewmodels/map_screen_viewmodel.dart';
import '../viewmodels/add_task_viewmodel.dart';
import '../services/task_share_print_service.dart';
import 'views/my_day_view.dart';
import 'views/my_work_view.dart';
import 'views/calendar_view.dart';
import 'views/group_by_view.dart';
import 'views/add_task_sheet.dart';
import 'views/all_work_view.dart';
import 'views/done_tasks_view.dart';
import 'views/overdue_tasks_view.dart';
import 'views/pending_tasks_view.dart';
import 'views/group_by_assignee_view.dart';
import 'widgets/task_tile.dart';
import 'widgets/compact_task_tile.dart';
import 'widgets/task_grid_card.dart';
import 'widgets/sheet_option_button.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.title});

  final String title;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final TaskSharePrintService _sharePrintService = TaskSharePrintService();
  late MapScreenViewModel _viewModel;
  late AddTaskViewModel _addTaskViewModel;
  bool _hasBoundViewModel = false;
  final FocusNode _focusNode = FocusNode();
  final TextEditingController taskName = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _taskSearchController = TextEditingController();
  final ScrollController _metadataButtonsScrollController = ScrollController();
  double _metadataButtonScrollStep = 118;
  final Map<FloatingSheetType, GlobalKey> _metadataButtonKeys = {
    for (final type in FloatingSheetType.values) type: GlobalKey(),
  };
  String _searchQuery = '';
  String _taskSearchQuery = '';
  bool _isSearchVisible = false;
  String _sortBy = 'Priority';
  String _groupBy = 'Assignee';
  String _viewType = 'Detailed list';
  double _zoom = 1;
  DateTime _calendarDate = DateTime.now();

  OverlayEntry? _floatingSheetOverlay;

  List<Task> get tasks => _viewModel.tasks;

  // selected tasks for multi-select
  final Set<Task> _selected = {};

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

  static const Color primaryColor = Color(0xFFFBE64E);
  static const Color secondaryColor = Color(0xFF6B5800);

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadButtonOrder();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasBoundViewModel) return;
    _hasBoundViewModel = true;
    _viewModel = Provider.of<MapScreenViewModel>(context, listen: false);
    _addTaskViewModel = Provider.of<AddTaskViewModel>(context, listen: false);
    _viewModel.addListener(_handleViewModelChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _listenForTaskUpdates();
    });
  }

  String _formatDateTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final date = DateTime(dt.year, dt.month, dt.day);

      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final time = dt.minute == 0
          ? '$hour${dt.hour >= 12 ? 'p' : 'a'}'
          : '$hour:${dt.minute.toString().padLeft(2, '0')}${dt.hour >= 12 ? 'p' : 'a'}';

      if (date == today) return 'Today $time';
      if (date == tomorrow) return 'Tmrw $time';
      return '${dt.day}/${dt.month} $time';
    } catch (_) {
      return 'Set';
    }
  }

  void _setNewTaskMetadata(FloatingSheetType type, String? value) {
    final shouldScroll = _addTaskViewModel.setValue(type, value);
    if (shouldScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_metadataButtonsScrollController.hasClients) return;
        final controller = _metadataButtonsScrollController;
        final nextOffset = (controller.offset + _metadataButtonScrollStep)
            .clamp(0.0, controller.position.maxScrollExtent)
            .toDouble();
        controller.animateTo(
          nextOffset,
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOutCubic,
        );
      });
    }
  }

  String? get _newTaskPriority =>
      _addTaskViewModel.valueFor(FloatingSheetType.priority);
  String? get _newTaskReminder =>
      _addTaskViewModel.valueFor(FloatingSheetType.remind);
  String? get _newTaskAssignee =>
      _addTaskViewModel.valueFor(FloatingSheetType.assign);
  String? get _newTaskDeadline =>
      _addTaskViewModel.valueFor(FloatingSheetType.deadline);
  String? get _newTaskWorkType =>
      _addTaskViewModel.valueFor(FloatingSheetType.workType);
  String? get _newTaskFolder =>
      _addTaskViewModel.valueFor(FloatingSheetType.folder);
  String? get _newTaskClientName =>
      _addTaskViewModel.valueFor(FloatingSheetType.clientName);
  String? get _newTaskRefProject =>
      _addTaskViewModel.valueFor(FloatingSheetType.refProject);
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

    return SheetOptionButton(
      key: _metadataButtonKeys[type],
      icon: icon,
      label: label,
      displayText: displayText,
      selected: isSelected,
      compact: compact,
      onClear: onClear,
      onTap: () {
        final isMulti = type == FloatingSheetType.assign;
        final currentSelections = isMulti && _newTaskAssignee != null
            ? _newTaskAssignee!.split(',').map((value) => value.trim()).toList()
            : <String>[];
        _showFloatingSheet(
          _metadataButtonKeys[type]?.currentContext ?? context,
          type,
          onSelected: onSelected,
          multiSelect: isMulti,
          selectedValues: currentSelections,
        );
      },
    );
  }

  @override
  void dispose() {
    _viewModel.removeListener(_handleViewModelChanged);
    _tabController.dispose();
    _hideFloatingSheet();
    _focusNode.dispose();
    taskName.dispose();
    _searchController.dispose();
    _taskSearchController.dispose();
    _metadataButtonsScrollController.dispose();
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

  Future<void> _loadTasksFromFirebase() async {
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    await _viewModel.refreshTasks(authVM);
  }

  void _listenForTaskUpdates() {
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    _viewModel.listenForTasks(authVM);
  }

  void _handleViewModelChanged() {
    if (!mounted) return;
    setState(() {});
    final message = _viewModel.takeErrorMessage();
    if (message != null) _showMessage(message);
  }

  Future<void> _refreshTasks() async {
    try {
      await _loadTasksFromFirebase();
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not refresh tasks: $error');
    }
  }

  Widget _refreshableScrollView(Widget child) => RefreshIndicator(
    onRefresh: _refreshTasks,
    child: Scrollbar(thumbVisibility: kIsWeb, child: child),
  );

  Future<void> _updateTaskInFirebase(Task task) async {
    await _viewModel.updateTask(task);
  }

  Future<void> _deleteTaskFromFirebase(Task task) =>
      _viewModel.deleteTask(task);

  Future<bool> _handleAddTaskFromSheet() async {
    final text = taskName.text.trim();
    if (text.isEmpty) return false;

    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    final added = await _viewModel.addTask(
      title: text,
      authViewModel: authVM,
      priority: _newTaskPriority,
      reminder: _newTaskReminder,
      assignee: _newTaskAssignee,
      deadline: _newTaskDeadline,
      workType: _newTaskWorkType,
      folder: _newTaskFolder,
      clientName: _newTaskClientName,
      refProject: _newTaskRefProject,
    );
    if (!added) return false;

    taskName.clear();
    _addTaskViewModel.clear();
    _focusNode.requestFocus();
    return added;
  }

  Future<List<String>> _loadClientsFromFirestore() => _viewModel.loadClients();

  Future<List<String>> _loadAssigneesFromFirestore() =>
      _viewModel.loadAssignees();

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
    VoidCallback? onDone,
    bool Function()? shouldShow,
    String Function()? searchQuery,
    bool closeOnSelect = false,
    bool multiSelect = false,
    List<String>? selectedValues,
  }) async {
    if (_floatingSheetOverlay != null) _hideFloatingSheet();

    List<String>? workTypes;
    if (type == FloatingSheetType.workType) {
      workTypes = await _viewModel.loadWorkTypes();
    }
    List<String>? clients;
    if (type == FloatingSheetType.clientName) {
      clients = await _loadClientsFromFirestore();
    }

    List<String>? projects;
    if (type == FloatingSheetType.refProject) {
      projects = await _viewModel.loadProjects();
    }

    List<String>? assignees;
    if (type == FloatingSheetType.assign) {
      assignees = await _loadAssigneesFromFirestore();
    }

    if (!mounted || !buttonContext.mounted) return;
    if (shouldShow != null && !shouldShow()) return;

    final BuildContext rootContext = Navigator.of(
      buttonContext,
      rootNavigator: true,
    ).context;
    final RenderBox button = buttonContext.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(buttonContext).context.findRenderObject() as RenderBox;

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

      final typedQuery = searchQuery?.call().trim().toLowerCase() ?? '';
      final matchingOptions = typedQuery.isEmpty
          ? const <String>[]
          : options
                .where((option) => option.toLowerCase().startsWith(typedQuery))
                .toList();
      final highlightedOption = matchingOptions.firstWhere(
        (option) => option.toLowerCase() == typedQuery,
        orElse: () => matchingOptions.isEmpty ? '' : matchingOptions.first,
      );

      return options.map((opt) {
        final bool isSelected = selectedValues?.contains(opt) ?? false;
        final bool isHighlighted =
            highlightedOption.isNotEmpty && opt == highlightedOption;
        return ListTile(
          dense: true,
          selected: isSelected || isHighlighted,
          selectedTileColor: primaryColor.withValues(alpha: 0.22),
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
              fontWeight: isSelected || isHighlighted
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: isSelected || isHighlighted
                  ? secondaryColor
                  : Colors.black87,
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

            if (!multiSelect || closeOnSelect) {
              _searchController.clear();
              _searchQuery = '';
              _hideFloatingSheet();
              if (closeOnSelect) onDone?.call();
            } else {
              if (setOverlayState != null) setOverlayState(() {});
            }
          },
        );
      }).toList();
    }

    const double padding = 8;
    final compactWeb = kIsWeb && MediaQuery.sizeOf(buttonContext).width < 600;
    final maxMenuHeight = compactWeb ? 260.0 : 400.0;

    _hideFloatingSheet();
    final initialQuery = searchQuery?.call() ?? '';
    _searchQuery = initialQuery;
    _searchController.clear();
    _floatingSheetOverlay = OverlayEntry(
      builder: (_) => LayoutBuilder(
        builder: (context, constraints) {
          final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
          final usableHeight = (constraints.maxHeight - keyboardInset)
              .clamp(0.0, constraints.maxHeight);
          final currentButtonPosition = button.localToGlobal(
            Offset.zero,
            ancestor: overlay,
          );
          final desiredMenuHeight = (usableHeight - padding * 2)
              .clamp(0.0, maxMenuHeight)
              .toDouble();
          final spaceAbove = (currentButtonPosition.dy - padding)
              .clamp(0.0, desiredMenuHeight);
          final spaceBelow =
              (usableHeight -
                      currentButtonPosition.dy -
                      button.size.height -
                      padding)
                  .clamp(0.0, desiredMenuHeight);
          final openAbove = spaceAbove >= spaceBelow;
          final menuMaxHeight = openAbove ? spaceAbove : spaceBelow;
          final top = openAbove
              ? currentButtonPosition.dy - menuMaxHeight
              : currentButtonPosition.dy + button.size.height + padding;
          final menuWidth = (constraints.maxWidth - padding * 2).clamp(
            0.0,
            240.0,
          );

          return Stack(
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
                        const showSearch = true;
                        final optionListHeight =
                            (menuMaxHeight - 68 - (multiSelect ? 64 : 0))
                                .clamp(0.0, 250.0)
                                .toDouble();
                        final allOptions = buildOptions(setOverlayState);
                        final filteredOptions =
                            showSearch && _searchQuery.isNotEmpty
                            ? allOptions.where((tile) {
                                final title =
                                    ((tile as ListTile).title as Text).data!
                                        .toLowerCase();
                                final query = _searchQuery.toLowerCase();
                                return searchQuery != null
                                    ? title.startsWith(query)
                                    : title.contains(query);
                              }).toList()
                            : allOptions;

                        return ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: menuMaxHeight,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (showSearch)
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: TextField(
                                    controller: _searchController,
                                    autofocus:
                                        compactWeb &&
                                        type == FloatingSheetType.assign,
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
                                      contentPadding:
                                          const EdgeInsets.symmetric(
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
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onPressed: () {
                                        _hideFloatingSheet();
                                        onDone?.call();
                                      },
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
          );
        },
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
      ('@', 'Assign', 'Type @ to search and assign a person.'),
      (
        '-',
        'Priority',
        'Type - and a letter, such as -u, to filter priorities.',
      ),
      (
        '!',
        'Deadline',
        'Type ! and a word, such as !tom, to filter deadlines.',
      ),
      ('*', 'Remind Me', 'Type * and a word to filter reminder options.'),
      ('+', 'Work Type', 'Type + and a word to filter work types.'),
      ('#', 'Client Name', 'Type # and a name to filter clients.'),
      ('^', 'Ref Project', 'Type ^ and a name to filter projects.'),
    ];

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        title: const Text('Task shortcuts'),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 360,
            maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.42,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (symbol, title, description) in shortcuts)
                  ListTile(
                    dense: true,
                    visualDensity: const VisualDensity(vertical: -2),
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
                    title: Text(title, style: const TextStyle(fontSize: 13)),
                    subtitle: Text(
                      description,
                      style: const TextStyle(fontSize: 11, height: 1.1),
                    ),
                  ),
                const ListTile(
                  dense: true,
                  visualDensity: VisualDensity(vertical: -2),
                  contentPadding: EdgeInsets.zero,
                  leading: SizedBox(
                    width: 28,
                    child: Icon(Icons.folder_outlined, size: 20),
                  ),
                  title: Text('Folder', style: TextStyle(fontSize: 13)),
                  subtitle: Text(
                    'Folder does not have a text shortcut symbol.',
                    style: TextStyle(fontSize: 11, height: 1.1),
                  ),
                ),
              ],
            ),
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
    String? activeMentionPickerSymbol;
    String assigneeMentionSourceText = '';
    int assigneeMentionStart = -1;
    int assigneeMentionEnd = -1;
    int highlightedAssigneeIndex = 0;

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
    final shortcutOptionsFutures = <String, Future<List<String>>>{};
    const dateOptions = [
      'Today (1 hour)',
      'Today (3 hour)',
      'Today (6 hour)',
      'Tomorrow (12 pm)',
      'Custom',
    ];

    ({int start, String symbol, String query})? parseMention(
      String text,
      int cursor,
    ) {
      final c = cursor.clamp(0, text.length);
      for (var i = c - 1; i >= 0; i--) {
        final ch = text[i];
        if (RegExp(r'\s').hasMatch(ch)) return null;
        if ('@-!*+#^'.contains(ch)) {
          if (i == 0 || RegExp(r'\s').hasMatch(text[i - 1])) {
            return (start: i, symbol: ch, query: text.substring(i + 1, c));
          }
          return null;
        }
      }
      return null;
    }

    Future<List<String>> loadMentionSource(String symbol) {
      return shortcutOptionsFutures.putIfAbsent(symbol, () async {
        switch (symbol) {
          case '-':
            return priorityOptions;
          case '@':
            assigneeOptions ??= await (assigneeOptionsFuture ??=
                _loadAssigneesFromFirestore());
            return assigneeOptions!;
          case '!':
          case '*':
            return dateOptions;
          case '+':
            return _viewModel.loadWorkTypes();
          case '#':
            return _loadClientsFromFirestore();
          case '^':
            return _viewModel.loadProjects();
          default:
            return const <String>[];
        }
      });
    }

    Future<void> completeMention(
      String opt,
      StateSetter setModalState, {
      String? sourceText,
    }) async {
      final symbol = mentionSymbol;
      final type = switch (symbol) {
        '-' => FloatingSheetType.priority,
        '@' => FloatingSheetType.assign,
        '!' => FloatingSheetType.deadline,
        '*' => FloatingSheetType.remind,
        '+' => FloatingSheetType.workType,
        '#' => FloatingSheetType.clientName,
        '^' => FloatingSheetType.refProject,
        _ => null,
      };
      if (type == null) return;

      var selectedValue = opt;
      if (type == FloatingSheetType.deadline ||
          type == FloatingSheetType.remind) {
        final lower = opt.toLowerCase();
        DateTime? selectedDate = DateTime.tryParse(opt);
        if (selectedDate == null && lower.contains('custom')) {
          selectedDate = await pickDateTimeWithTabs(context);
        } else if (selectedDate == null) {
          final now = DateTime.now();
          if (lower.contains('1 hour')) {
            selectedDate = now.add(const Duration(hours: 1));
          } else if (lower.contains('3 hour')) {
            selectedDate = now.add(const Duration(hours: 3));
          } else if (lower.contains('6 hour')) {
            selectedDate = now.add(const Duration(hours: 6));
          } else if (lower.contains('tomorrow')) {
            final tomorrow = DateTime(
              now.year,
              now.month,
              now.day,
            ).add(const Duration(days: 1));
            selectedDate = DateTime(
              tomorrow.year,
              tomorrow.month,
              tomorrow.day,
              12,
            );
          }
        }
        if (selectedDate == null) return;
        selectedValue = selectedDate.toIso8601String();
      }

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
        if (type == FloatingSheetType.assign) {
          final selectedAssignees = (_newTaskAssignee ?? '')
              .split(',')
              .map((name) => name.trim())
              .where((name) => name.isNotEmpty)
              .toList();
          if (!selectedAssignees.any(
            (name) => name.toLowerCase() == selectedValue.toLowerCase(),
          )) {
            selectedAssignees.add(selectedValue);
          }
          _setNewTaskMetadata(
            FloatingSheetType.assign,
            selectedAssignees.join(', '),
          );
        } else {
          _setNewTaskMetadata(type, selectedValue);
        }
      });
      setModalState(() {});
    }

    List<String> currentNewTaskAssignees() => (_newTaskAssignee ?? '')
        .split(',')
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();

    void addNewTaskAssignee(String name, StateSetter setModalState) {
      setState(() {
        final selectedAssignees = currentNewTaskAssignees();
        if (!selectedAssignees.any(
          (selected) => selected.toLowerCase() == name.toLowerCase(),
        )) {
          selectedAssignees.add(name);
        }
        _setNewTaskMetadata(
          FloatingSheetType.assign,
          selectedAssignees.join(', '),
        );
      });
      setModalState(() {});
    }

    void removeAssigneeMention(StateSetter setModalState) {
      final currentText = taskName.text;
      final start = assigneeMentionStart;
      if (start < 0 || start >= currentText.length) return;

      var end = start;
      while (end < currentText.length &&
          !RegExp(r'\s').hasMatch(currentText[end])) {
        end++;
      }

      final beforeMention = currentText.substring(0, start).trimRight();
      final afterMention = currentText.substring(end).trimLeft();
      final hasTextBefore = beforeMention.isNotEmpty;
      final hasTextAfter = afterMention.isNotEmpty;
      final updatedText = hasTextBefore && hasTextAfter
          ? '$beforeMention $afterMention'
          : hasTextBefore
          ? beforeMention
          : afterMention;
      final cursorOffset = hasTextBefore
          ? beforeMention.length + (hasTextAfter ? 1 : 0)
          : 0;

      taskName.value = TextEditingValue(
        text: updatedText,
        selection: TextSelection.collapsed(offset: cursorOffset),
      );
      setModalState(() {
        assigneeMentionQuery = null;
        assigneeMentionStart = -1;
        assigneeMentionEnd = -1;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }

    Future<void> selectMentionOnEnter(StateSetter setModalState) async {
      final query = assigneeMentionQuery?.trim() ?? '';
      if (query.isEmpty) return;
      final symbol = mentionSymbol;
      final sourceText = assigneeMentionSourceText;

      try {
        final options = await loadMentionSource(symbol);
        if (assigneeMentionQuery?.trim() != query || mentionSymbol != symbol) {
          return;
        }
        final normalizedQuery = query.toLowerCase();
        final matches = options
            .where((option) => option.toLowerCase().startsWith(normalizedQuery))
            .toList();
        if (matches.isEmpty) return;

        final selected = matches.firstWhere(
          (option) => option.toLowerCase() == normalizedQuery,
          orElse: () => matches.first,
        );
        activeMentionPickerSymbol = null;
        _hideFloatingSheet();
        await completeMention(selected, setModalState, sourceText: sourceText);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not load options: $error')),
          );
        }
      }
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
          _metadataButtonScrollStep = screenWidth < 600 ? 118 : 156;
          final mobileButtonOrder = [
            ..._buttonOrder.where(
              (type) => type != FloatingSheetType.refProject,
            ),
            FloatingSheetType.refProject,
          ];
          final selectedButtonOrder = _addTaskViewModel.metadataOrder
              .where(
                (type) =>
                    mobileButtonOrder.contains(type) &&
                    (_addTaskViewModel.valueFor(type)?.trim().isNotEmpty ??
                        false),
              )
              .toList();
          final availableButtonOrder = [
            ...selectedButtonOrder,
            ...mobileButtonOrder.where(
              (type) => !selectedButtonOrder.contains(type),
            ),
          ];
          final systemNavBar = MediaQuery.of(sheetContext).padding.bottom;
          final isCompactWeb = kIsWeb && screenWidth < 600;
          final bottomPadding = kIsWeb && !isCompactWeb
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
            child: AddTaskSheet(
              bottomPadding: bottomPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SingleChildScrollView(
                    controller: _metadataButtonsScrollController,
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
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Builder(
                          builder: (textFieldCtx) => Focus(
                            onKeyEvent: (node, event) {
                              if (event is KeyDownEvent &&
                                  (event.logicalKey ==
                                          LogicalKeyboardKey.enter ||
                                      event.logicalKey ==
                                          LogicalKeyboardKey.numpadEnter) &&
                                  assigneeMentionQuery != null) {
                                if (assigneeMentionQuery!.trim().isEmpty) {
                                  return KeyEventResult.ignored;
                                }
                                unawaited(selectMentionOnEnter(setModalState));
                                return KeyEventResult.handled;
                              }

                              if (event is! KeyDownEvent ||
                                  event.logicalKey != LogicalKeyboardKey.tab ||
                                  assigneeMentionQuery == null) {
                                return KeyEventResult.ignored;
                              }

                              final query = assigneeMentionQuery!;
                              final symbol = mentionSymbol;
                              unawaited(() async {
                                try {
                                  final source = await loadMentionSource(
                                    symbol,
                                  );
                                  final matches = source
                                      .where(
                                        (option) => option
                                            .toLowerCase()
                                            .startsWith(query.toLowerCase()),
                                      )
                                      .toList();
                                  if (matches.isEmpty) return;
                                  final index = highlightedAssigneeIndex
                                      .clamp(0, matches.length - 1)
                                      .toInt();
                                  await completeMention(
                                    matches[index],
                                    setModalState,
                                    sourceText: assigneeMentionSourceText,
                                  );
                                } catch (error) {
                                  if (sheetContext.mounted) {
                                    ScaffoldMessenger.of(sheetContext)
                                        .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Could not load options: $error',
                                            ),
                                          ),
                                        );
                                  }
                                }
                              }());
                              return KeyEventResult.handled;
                            },
                            child: RawAutocomplete<String>(
                              textEditingController: taskName,
                              focusNode: _focusNode,
                              optionsViewOpenDirection:
                                  OptionsViewOpenDirection.up,
                              optionsBuilder: (value) => const <String>[],
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
                                                (showDone ? doneAreaHeight : 0))
                                            .clamp(0.0, 154.0)
                                            .toDouble();

                                    return Align(
                                      alignment: Alignment.bottomRight,
                                      child: Material(
                                        elevation: 8,
                                        borderRadius: BorderRadius.circular(12),
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
                                                        const EdgeInsets.all(8),
                                                    child: SizedBox(
                                                      width: double.infinity,
                                                      child: ElevatedButton(
                                                        style:
                                                            ElevatedButton.styleFrom(
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

                                      if (m == null) {
                                        activeMentionPickerSymbol = null;
                                        if (_floatingSheetOverlay != null) {
                                          _hideFloatingSheet();
                                        }
                                        return;
                                      }

                                      final pickerType = switch (m.symbol) {
                                        '-' => FloatingSheetType.priority,
                                        '@' => FloatingSheetType.assign,
                                        '!' => FloatingSheetType.deadline,
                                        '*' => FloatingSheetType.remind,
                                        '+' => FloatingSheetType.workType,
                                        '#' => FloatingSheetType.clientName,
                                        '^' => FloatingSheetType.refProject,
                                        _ => null,
                                      };
                                      if (pickerType == null) return;

                                      if (activeMentionPickerSymbol !=
                                          m.symbol) {
                                        activeMentionPickerSymbol = m.symbol;
                                        _showFloatingSheet(
                                          _metadataButtonKeys[pickerType]
                                                  ?.currentContext ??
                                              textFieldCtx,
                                          pickerType,
                                          shouldShow: () =>
                                              activeMentionPickerSymbol ==
                                              m.symbol,
                                          searchQuery: () =>
                                              assigneeMentionQuery ?? '',
                                          closeOnSelect: true,
                                          multiSelect:
                                              pickerType ==
                                              FloatingSheetType.assign,
                                          selectedValues:
                                              pickerType ==
                                                  FloatingSheetType.assign
                                              ? currentNewTaskAssignees()
                                              : null,
                                          onSelected: (option) {
                                            if (pickerType ==
                                                FloatingSheetType.assign) {
                                              addNewTaskAssignee(
                                                option,
                                                setModalState,
                                              );
                                            } else {
                                              unawaited(
                                                completeMention(
                                                  option,
                                                  setModalState,
                                                  sourceText:
                                                      assigneeMentionSourceText,
                                                ),
                                              );
                                            }
                                          },
                                          onDone: () {
                                            activeMentionPickerSymbol = null;
                                            if (pickerType ==
                                                FloatingSheetType.assign) {
                                              removeAssigneeMention(
                                                setModalState,
                                              );
                                            }
                                          },
                                        );
                                      } else {
                                        _searchQuery = m.query;
                                        _floatingSheetOverlay?.markNeedsBuild();
                                      }
                                    },
                                    onSubmitted: (_) {
                                      final isMentionActive =
                                          assigneeMentionQuery != null;
                                      if (isMentionActive) {
                                        if (assigneeMentionQuery!
                                            .trim()
                                            .isNotEmpty) {
                                          unawaited(
                                            selectMentionOnEnter(setModalState),
                                          );
                                        }
                                        return;
                                      }
                                      onFieldSubmitted();
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
                ],
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
    if (!mounted) return;
    await _viewModel.refreshTasks(
      Provider.of<AuthViewModel>(context, listen: false),
    );
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
        try {
          await _deleteTaskFromFirebase(t);
        } catch (error) {
          if (mounted) _showMessage('Could not delete "${t.title}": $error');
        }
      }

      setState(() {
        _selected.clear();
      });
      _viewModel.sortTasks();
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
      _viewModel.sortTasks();
    }
  }

  Widget _buildTaskTile(Task task) {
    final isSelected = _selected.contains(task);
    return TaskTile(
      task: task,
      isSelected: isSelected,
      taskName: _taskListName(task),
      description: _taskListDescription(task),
      priorityWidget: Builder(
        builder: (badgeContext) {
          final priority = task.priority;
          return GestureDetector(
            onTap: () => _showFloatingSheet(
              badgeContext,
              FloatingSheetType.priority,
              onSelected: (value) async {
                setState(() {
                  task.priority = value;
                  task.priorityUpdatedAt =
                      DateTime.now().millisecondsSinceEpoch;
                });
                _viewModel.sortTasks();
                await _updateTaskInFirebase(task);
              },
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: priority == null || priority.isEmpty
                      ? Colors.grey.shade300
                      : secondaryColor,
                ),
              ),
              child: Text(
                priority == null || priority.isEmpty ? 'None' : priority,
                style: TextStyle(
                  fontSize: 13,
                  color: priority == null || priority.isEmpty
                      ? Colors.grey.shade600
                      : secondaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
      onToggleDone: () async {
        setState(() => task.isDone = !task.isDone);
        await _updateTaskInFirebase(task);
        _viewModel.sortTasks();
      },
      onToggleSelection: () => setState(() {
        if (!_selected.add(task)) _selected.remove(task);
      }),
      onOpen: () {
        if (_selected.isEmpty) {
          _openTaskDetail(task);
          return;
        }
        setState(() {
          if (!_selected.add(task)) _selected.remove(task);
        });
      },
      onAddSubtask: () => _promptAddSubstep(task),
    );
  }

  List<Task> _getOverdueTasks() => _viewModel.overdueTasks();
  List<Task> _getPendingTasks() => _viewModel.pendingTasks();
  List<Task> _getDoneTasks() => _viewModel.doneTasks();

  List<Task> _getMyTasks() =>
      _viewModel.myTasks(Provider.of<AuthViewModel>(context, listen: false));

  List<Task> _getMyDayTasks() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _getMyTasks().where((task) {
      if (task.isDone) return false;
      if (task.priority?.trim().toLowerCase() == 'today') return true;

      final scheduled = _taskScheduledDate(task);
      return scheduled != null &&
          scheduled.year == today.year &&
          scheduled.month == today.month &&
          scheduled.day == today.day;
    }).toList();
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
            _viewModel.sortTasks();
            await _updateTaskInFirebase(task);
          },
        );
      },
      child: Container(
        constraints: compact
            ? const BoxConstraints(maxWidth: 60, maxHeight: 22)
            : null,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 10,
          vertical: compact ? 2 : 6,
        ),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(compact ? 10 : 14),
          border: Border.all(color: badgeColor.withValues(alpha: 0.42)),
        ),
        child: Text(
          priority != null && priority.isNotEmpty ? priority : 'None',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: compact ? 10 : 13,
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
                  _buildTaskTile(entry.value),
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
                    _buildTaskTile(entry.value),
                    _thinHairline(indent: 15, endIndent: 15, opacity: 0.05),
                  ],
                );
              }).toList(),
            ),
    );
  }

  Widget _buildMyWorkView() {
    final sections = _viewModel.myWorkSections(_getMyTasks());
    return _refreshableScrollView(
      MyWorkView(
        sections: sections,
        taskResultsBuilder: (tasks) =>
            _buildMyWorkTaskResults(_getVisibleTasks(tasks)),
      ),
    );
  }

  Widget _buildMyDayView() {
    final myTasks = _getMyTasks();
    final dayTasks = _getVisibleTasks(_getMyDayTasks());
    final suggestions = _getVisibleTasks(
      myTasks.where((task) => !task.isDone).toList(),
    );

    return MyDayView(
      tasks: dayTasks,
      suggestions: suggestions,
      taskBuilder: (task, index) => _buildTaskItem(task, index),
      suggestionBuilder: _buildMyDaySuggestion,
      onRefresh: _refreshTasks,
    );
  }

  Widget _buildMyDaySuggestion(Task task, VoidCallback onAdd) {
    final scheduled = _taskScheduledDate(task);
    final details = [
      if (task.priority?.trim().isNotEmpty == true) task.priority!.trim(),
      if (scheduled != null)
        MaterialLocalizations.of(context).formatShortDate(scheduled),
    ];

    return ListTile(
      leading: Checkbox(
        value: task.isDone,
        onChanged: (_) async {
          setState(() => task.isDone = true);
          await _updateTaskInFirebase(task);
          _viewModel.sortTasks();
        },
      ),
      title: Text(
        task.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        details.isEmpty ? 'Task' : details.join(' • '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        tooltip: 'Add to My Day',
        onPressed: onAdd,
        icon: const Icon(Icons.add, color: Color(0xFF526D8A)),
      ),
    );
  }

  List<Task> _getVisibleTasks(List<Task> source) {
    return _viewModel.visibleTasks(
      source: source,
      query: _taskSearchQuery,
      sortBy: _sortBy,
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

  String _taskListName(Task task) {
    final assignee = task.assignee?.trim();
    return assignee != null && assignee.isNotEmpty ? assignee : task.title;
  }

  String? _taskListDescription(Task task) {
    final assignee = task.assignee?.trim();
    if (assignee == null || assignee.isEmpty) {
      final note = task.note.trim();
      return note.isEmpty ? null : note;
    }
    final title = task.title.trim();
    return title.isEmpty ? null : title;
  }

  Widget _buildCompactTaskTile(Task task) {
    final isSelected = _selected.contains(task);
    return CompactTaskTile(
      task: task,
      taskName: _taskListName(task),
      description: _taskListDescription(task),
      isSelected: isSelected,
      priorityBadge: _buildTaskPriorityBadge(task, compact: true),
      onToggleDone: () async {
        setState(() => task.isDone = !task.isDone);
        await _updateTaskInFirebase(task);
        if (mounted) _viewModel.sortTasks();
      },
      onAddSubtask: () => _promptAddSubstep(task),
      onToggleSelection: () => _toggleTaskSelection(task),
      onOpen: () => _openOrToggleTask(task),
    );
  }

  Widget _buildGridTaskCard(Task task) {
    return TaskGridCard(
      task: task,
      taskName: _taskListName(task),
      description: _taskListDescription(task),
      isSelected: _selected.contains(task),
      onToggleSelection: () => _toggleTaskSelection(task),
      onOpen: () => _openOrToggleTask(task),
    );
  }

  void _toggleTaskSelection(Task task) {
    setState(() {
      if (!_selected.add(task)) _selected.remove(task);
    });
  }

  void _openOrToggleTask(Task task) {
    if (_selected.isEmpty) {
      _openTaskDetail(task);
    } else {
      _toggleTaskSelection(task);
    }
  }

  Widget _buildTaskItem(Task task, int index) => _viewType == 'Grid'
      ? _buildGridTaskCard(task)
      : _viewType == 'List'
      ? _buildCompactTaskTile(task)
      : Column(
          children: [
            _buildTaskTile(task),
            _thinHairline(indent: 15, endIndent: 15, opacity: 0.05),
          ],
        );

  Widget _buildAllWorkTab() => AllWorkView(
    tasks: _getVisibleTasks(tasks),
    viewType: _viewType,
    zoom: _zoom,
    taskBuilder: _buildTaskItem,
    calendarBuilder: _buildCalendarView,
    refreshable: _refreshableScrollView,
  );

  Widget _buildDoneTasksTab() => DoneTasksView(
    tasks: _getVisibleTasks(_getDoneTasks()),
    viewType: _viewType,
    zoom: _zoom,
    taskBuilder: _buildTaskItem,
    calendarBuilder: _buildCalendarView,
    refreshable: _refreshableScrollView,
  );

  Widget _buildOverdueTasksTab() => OverdueTasksView(
    tasks: _getVisibleTasks(_getOverdueTasks()),
    viewType: _viewType,
    zoom: _zoom,
    taskBuilder: _buildTaskItem,
    calendarBuilder: _buildCalendarView,
    refreshable: _refreshableScrollView,
  );

  Widget _buildPendingTasksTab() => PendingTasksView(
    tasks: _getVisibleTasks(_getPendingTasks()),
    viewType: _viewType,
    zoom: _zoom,
    taskBuilder: _buildTaskItem,
    calendarBuilder: _buildCalendarView,
    refreshable: _refreshableScrollView,
  );

  Widget _buildCalendarView(List<Task> visibleTasks) {
    return CalendarView(
      tasks: visibleTasks,
      selectedDate: _calendarDate,
      onDateChanged: (date) => setState(() => _calendarDate = date),
      scheduledDate: _taskScheduledDate,
      refreshable: _refreshableScrollView,
      taskBuilder: (task, index) => Column(
        children: [
          _buildTaskTile(task),
          _thinHairline(indent: 15, endIndent: 15, opacity: 0.05),
        ],
      ),
    );
  }

  Widget _buildGroupByAssignView() {
    final Map<String, List<Task>> grouped = {};
    for (final task in _getVisibleTasks(tasks)) {
      grouped.putIfAbsent(_groupValue(task), () => []).add(task);
    }
    if (_groupBy == 'Assignee') {
      return GroupByAssigneeView(
        groups: grouped,
        refreshable: _refreshableScrollView,
        onOpenAssignee: _showAssigneeTasksModal,
        onOpenTask: _openTaskDetail,
      );
    }
    return GroupByView(
      groups: grouped,
      groupBy: _groupBy,
      refreshable: _refreshableScrollView,
      onOpenAssignee: _showAssigneeTasksModal,
      onOpenTask: _openTaskDetail,
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
            _tabController.animateTo(6);
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
        return _getMyDayTasks();
      case 1:
        return _getMyTasks();
      case 3:
        return _getDoneTasks();
      case 4:
        return _getOverdueTasks();
      case 5:
        return _getPendingTasks();
      default:
        return tasks;
    }
  }

  Future<void> _shareTaskList() async {
    final items = _getVisibleTasks(_tasksForCurrentTab());
    await _sharePrintService.shareTasks(widget.title, items);
  }

  Future<void> _printTaskList() async {
    final items = _getVisibleTasks(_tasksForCurrentTab());
    await _sharePrintService.printTasks(widget.title, items);
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
      builder: (dialogContext) {
        final screenHeight = MediaQuery.sizeOf(dialogContext).height;
        final visibleReminderCount = reminders.length.clamp(1, 3);
        final maxListHeight = (screenHeight * 0.75 - 140).clamp(72.0, 216.0);
        final listHeight = (visibleReminderCount * 72.0)
            .clamp(72.0, maxListHeight)
            .toDouble();

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
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
                          fontSize: 20,
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
                            final scheduled = _taskScheduledDate(task)!;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.notifications_outlined,
                                color: secondaryColor,
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
                Tab(text: 'My Day (${_getMyDayTasks().length})'),
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
                Builder(
                  key: const PageStorageKey('my-day-tab'),
                  builder: (_) => _buildMyDayView(),
                ),
                Builder(
                  key: const PageStorageKey('my-work-tab'),
                  builder: (_) => _buildMyWorkView(),
                ),
                Builder(
                  key: const PageStorageKey('all-work-tab'),
                  builder: (_) => _buildAllWorkTab(),
                ),
                Builder(
                  key: const PageStorageKey('done-tasks-tab'),
                  builder: (_) => _buildDoneTasksTab(),
                ),
                Builder(
                  key: const PageStorageKey('overdue-tasks-tab'),
                  builder: (_) => _buildOverdueTasksTab(),
                ),
                Builder(
                  key: const PageStorageKey('pending-tasks-tab'),
                  builder: (_) => _buildPendingTasksTab(),
                ),
                Builder(
                  key: const PageStorageKey('group-by-tab'),
                  builder: (_) => _buildGroupByAssignView(),
                ),
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
