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
import '../models/quick_date_time_option.dart';
import 'views/date_time_picker_dialog.dart';
import 'views/task_completion_confirmation_dialog.dart';
import 'views/add_task_metadata_bar.dart';
import 'views/my_day_view.dart';
import 'views/my_work_task_results_view.dart';
import 'views/my_work_view.dart';
import 'views/calendar_view.dart';
import 'views/group_by_view.dart';
import 'views/add_task_sheet.dart';
import 'views/all_work_view.dart';
import 'views/done_tasks_view.dart';
import 'views/overdue_tasks_view.dart';
import 'views/pending_tasks_view.dart';
import 'views/group_by_assignee_view.dart';
import 'widgets/map_task_list_item.dart';
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

  bool _matchesSearchQuery(String option, String query) {
    final normalizedOption = option.toLowerCase();
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;
    if (normalizedOption.contains(normalizedQuery)) return true;

    var queryIndex = 0;
    for (
      var optionIndex = 0;
      optionIndex < normalizedOption.length;
      optionIndex++
    ) {
      if (normalizedOption[optionIndex] == normalizedQuery[queryIndex]) {
        queryIndex++;
        if (queryIndex == normalizedQuery.length) return true;
      }
    }
    return false;
  }

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
    _tabController = TabController(length: 8, vsync: this);
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
    final keepKeyboardOpen =
        type == FloatingSheetType.assign &&
        (_focusNode.hasFocus ||
            MediaQuery.viewInsetsOf(buttonContext).bottom > 0 ||
            MediaQuery.viewInsetsOf(context).bottom > 0);

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
          options = QuickDateTimeOptions.labels();
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
                .where((option) => _matchesSearchQuery(option, typedQuery))
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
                computed = await showDateTimePickerWithTabs(rootContext);
              } else {
                computed = QuickDateTimeOptions.resolve(opt, now: now);
              }
              if (computed != null) {
                finalVal = computed.toIso8601String();
              } else {
                return;
              }
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
    const double searchAreaHeight = 60;
    const double optionRowHeight = 48;
    const double doneAreaHeight = 56;
    final compactWeb = kIsWeb && MediaQuery.sizeOf(buttonContext).width < 600;
    final maxMenuHeight =
        (searchAreaHeight +
                optionRowHeight * 3 +
                (multiSelect ? doneAreaHeight : 0))
            .clamp(0.0, compactWeb ? 260.0 : 400.0)
            .toDouble();

    _hideFloatingSheet();
    final initialQuery = searchQuery?.call() ?? '';
    _searchQuery = initialQuery;
    _searchController.clear();
    double? fixedMenuTop;
    double? fixedMenuBottom;
    double? fixedMenuMaxHeight;
    _floatingSheetOverlay = OverlayEntry(
      builder: (_) => LayoutBuilder(
        builder: (context, constraints) {
          final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
          final usableHeight = (constraints.maxHeight - keyboardInset).clamp(
            0.0,
            constraints.maxHeight,
          );
          if ((fixedMenuTop == null && fixedMenuBottom == null) ||
              fixedMenuMaxHeight == null) {
            final currentButtonPosition = button.localToGlobal(
              Offset.zero,
              ancestor: overlay,
            );
            final desiredMenuHeight = (usableHeight - padding * 2)
                .clamp(0.0, maxMenuHeight)
                .toDouble();
            final spaceAbove = (currentButtonPosition.dy - padding).clamp(
              0.0,
              desiredMenuHeight,
            );
            final spaceBelow =
                (usableHeight -
                        currentButtonPosition.dy -
                        button.size.height -
                        padding)
                    .clamp(0.0, desiredMenuHeight);
            final openAbove = spaceAbove >= spaceBelow;
            fixedMenuMaxHeight = openAbove ? spaceAbove : spaceBelow;
            if (openAbove) {
              fixedMenuBottom =
                  constraints.maxHeight - (currentButtonPosition.dy - padding);
            } else {
              fixedMenuTop =
                  currentButtonPosition.dy + button.size.height + padding;
            }
          }
          final menuMaxHeight = fixedMenuMaxHeight!;
          final menuWidth = (constraints.maxWidth - padding * 2).clamp(
            0.0,
            220.0,
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
                top: fixedMenuTop,
                bottom: fixedMenuBottom,
                child: Material(
                  color: Colors.white,
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: menuWidth,
                    child: StatefulBuilder(
                      builder: (context, setOverlayState) {
                        const showSearch = true;
                        final allOptions = buildOptions(setOverlayState);
                        final filteredOptions =
                            showSearch && _searchQuery.isNotEmpty
                            ? allOptions.where((tile) {
                                final title =
                                    ((tile as ListTile).title as Text).data!;
                                return _matchesSearchQuery(title, _searchQuery);
                              }).toList()
                            : allOptions;
                        final maxOptionListHeight =
                            (menuMaxHeight -
                                    searchAreaHeight -
                                    (multiSelect ? doneAreaHeight : 0))
                                .clamp(0.0, optionRowHeight * 3)
                                .toDouble();
                        final visibleOptionCount = filteredOptions.isEmpty
                            ? 1
                            : filteredOptions.length.clamp(1, 3);
                        final optionListHeight =
                            (visibleOptionCount * optionRowHeight)
                                .clamp(0.0, maxOptionListHeight)
                                .toDouble();

                        return ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: menuMaxHeight),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (showSearch)
                                SizedBox(
                                  height: searchAreaHeight,
                                  child: Padding(
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
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                      onChanged: (val) {
                                        _searchQuery = val;
                                        setOverlayState(() {});
                                      },
                                    ),
                                  ),
                                ),
                              TextFieldTapRegion(
                                child: ExcludeFocus(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        height: optionListHeight,
                                        child: filteredOptions.isEmpty
                                            ? const Padding(
                                                padding: EdgeInsets.all(16),
                                                child: Center(
                                                  child: Text(
                                                    'No results',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.grey,
                                                    ),
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
                                        SizedBox(
                                          height: doneAreaHeight,
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      secondaryColor,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
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
                                        ),
                                    ],
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
    if (keepKeyboardOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_focusNode.canRequestFocus) return;
        if (!_focusNode.hasFocus) _focusNode.requestFocus();
        SystemChannels.textInput.invokeMethod<void>('TextInput.show');
      });
    }
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
            maxHeight: (MediaQuery.sizeOf(dialogContext).height * 0.42)
                .clamp(0.0, 180.0)
                .toDouble(),
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
    final dateOptions = QuickDateTimeOptions.labels();

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

    void refocusComposer() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _focusNode.canRequestFocus) {
          _focusNode.requestFocus();
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
          selectedDate = await showDateTimePickerWithTabs(context);
        } else if (selectedDate == null) {
          selectedDate = QuickDateTimeOptions.resolve(opt);
        }
        if (selectedDate == null) {
          refocusComposer();
          return;
        }
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
      refocusComposer();
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
        if (mounted && !_focusNode.hasFocus) _focusNode.requestFocus();
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
            .where((option) => _matchesSearchQuery(option, normalizedQuery))
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
          final screenWidth = MediaQuery.of(sheetContext).size.width;
          _metadataButtonScrollStep = screenWidth < 600 ? 118 : 156;
          final mobileButtonOrder = [
            ..._buttonOrder.where(
              (type) => type != FloatingSheetType.refProject,
            ),
            FloatingSheetType.refProject,
          ];
          final systemNavBar = MediaQuery.of(sheetContext).padding.bottom;
          final bottomPadding = 16.0 + (kIsWeb ? 0.0 : systemNavBar);

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
              bottomPadding:
                  bottomPadding + MediaQuery.viewInsetsOf(sheetContext).bottom,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AddTaskMetadataBar(
                    buttonOrder: mobileButtonOrder,
                    metadataOrder: _addTaskViewModel.metadataOrder,
                    scrollController: _metadataButtonsScrollController,
                    compact: screenWidth < 600,
                    buttonBuilder: (type, compact) =>
                        _buildBottomSheetButtonWithState(
                          type,
                          setModalState,
                          compact: compact,
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
                                        (option) =>
                                            _matchesSearchQuery(option, query),
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
                                            .clamp(0.0, 144.0)
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
                                                SizedBox(
                                                  height: listHeight,
                                                  child: ListView.builder(
                                                    padding: EdgeInsets.zero,
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
                                    onTap: () {
                                      if (!focusNode.hasFocus) {
                                        focusNode.requestFocus();
                                      }
                                    },
                                    onEditingComplete: () {},
                                    onTapOutside: (_) {},
                                    minLines: 1,
                                    maxLines: 4,

                                    textInputAction:
                                        assigneeMentionQuery == null
                                        ? TextInputAction.done
                                        : TextInputAction.search,
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
          scrollable: true,
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

  Widget _buildTaskTile(Task task) =>
      _buildMapTaskListItem(task, viewType: 'Detailed list', dense: true);

  List<Task> _getOverdueTasks() => _viewModel.overdueTasks();
  List<Task> _getPendingTasks() => _viewModel.pendingTasks();
  List<Task> _getDoneTasks() => _viewModel.doneTasks();

  List<Task> _getMyTasks() =>
      _viewModel.myTasks(Provider.of<AuthViewModel>(context, listen: false));

  List<Task> _getMyDayTasks() => MapScreenViewModel.myDayTasks(_getMyTasks());

  Widget _buildMyWorkTaskResults(List<Task> visibleTasks) =>
      MyWorkTaskResultsView(
        tasks: visibleTasks,
        viewType: _viewType,
        zoom: _zoom,
        selectedDate: _calendarDate,
        onDateChanged: (date) => setState(() => _calendarDate = date),
        scheduledDate: _taskScheduledDate,
        taskBuilder: (task, index) =>
            _buildTaskItem(task, index, dense: true, confirmCompletion: true),
        detailedTaskBuilder: (task) => Column(
          children: [
            _buildMapTaskListItem(
              task,
              viewType: 'Detailed list',
              dense: true,
              confirmCompletion: true,
            ),
            _thinHairline(indent: 15, endIndent: 15, opacity: 0.05),
          ],
        ),
      );

  Widget _buildMyWorkView() {
    return _refreshableScrollView(
      MyWorkView(
        sections: _viewModel.myWorkSections(_getMyTasks()),
        taskResultsBuilder: (tasks) =>
            _buildMyWorkTaskResults(_getVisibleTasks(tasks)),
      ),
    );
  }

  Widget _buildAssignTab() {
    final groups = MapScreenViewModel.assignedTasksByName(
      _getVisibleTasks(tasks),
    );
    return GroupByAssigneeView(
      groups: groups,
      pageStorageId: 'assign-tab',
      refreshable: _refreshableScrollView,
      openAssigneeOnTap: true,
      onOpenAssignee: _showAssigneeTasksModal,
      onOpenTask: _openTaskDetail,
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
      taskBuilder: _buildTaskItem,
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
      onTap: () => _openTaskDetail(task),
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
        style: const TextStyle(fontSize: 13),
      ),
      subtitle: Text(
        details.isEmpty ? 'Task' : details.join(' • '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11),
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

  DateTime? _taskScheduledDate(Task task) =>
      DateTime.tryParse(task.deadline ?? task.reminder ?? '');

  String? _taskListDescription(Task task) {
    final note = task.note.trim();
    return note.isEmpty ? null : note;
  }

  Widget _buildMapTaskListItem(
    Task task, {
    String? viewType,
    bool dense = false,
    bool confirmCompletion = false,
  }) {
    return MapTaskListItem(
      task: task,
      viewType: viewType ?? _viewType,
      dense: dense,
      taskName: task.title,
      description: _taskListDescription(task),
      isSelected: _selected.contains(task),
      onEditPriority: (badgeContext) => _showFloatingSheet(
        badgeContext,
        FloatingSheetType.priority,
        onSelected: (value) async {
          setState(() {
            task.priority = value;
            task.priorityUpdatedAt = DateTime.now().millisecondsSinceEpoch;
          });
          _viewModel.sortTasks();
          await _updateTaskInFirebase(task);
        },
      ),
      onToggleDone: () =>
          _toggleTaskDone(task, confirmCompletion: confirmCompletion),
      onAddSubtask: () => _promptAddSubstep(task),
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

  Widget _buildTaskItem(
    Task task,
    int index, {
    bool dense = true,
    bool confirmCompletion = false,
  }) => _viewType == 'Detailed list'
      ? Column(
          children: [
            _buildMapTaskListItem(
              task,
              dense: dense,
              confirmCompletion: confirmCompletion,
            ),
            _thinHairline(indent: 15, endIndent: 15, opacity: 0.05),
          ],
        )
      : _buildMapTaskListItem(
          task,
          dense: dense,
          confirmCompletion: confirmCompletion,
        );

  Future<void> _toggleTaskDone(
    Task task, {
    bool confirmCompletion = false,
  }) async {
    if (confirmCompletion && !task.isDone) {
      final confirmed = await showTaskCompletionConfirmation(
        context,
        task.title,
      );
      if (!confirmed || !mounted) return;
    }

    setState(() => task.isDone = !task.isDone);
    await _updateTaskInFirebase(task);
    if (mounted) _viewModel.sortTasks();
  }

  Widget _buildAllWorkTab() => AllWorkView(
    tasks: _getVisibleTasks(tasks),
    viewType: _viewType,
    zoom: _zoom,
    taskBuilder: (task, index) => _buildTaskItem(task, index, dense: true),
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
    final grouped = MapScreenViewModel.groupTasks(
      _getVisibleTasks(tasks),
      _groupBy,
    );
    if (_groupBy == 'Assignee') {
      return GroupByAssigneeView(
        groups: grouped,
        pageStorageId: 'group-by-$_groupBy-tab',
        refreshable: _refreshableScrollView,
        onOpenAssignee: _showAssigneeTasksModal,
        onOpenTask: _openTaskDetail,
      );
    }
    return GroupByView(
      groups: grouped,
      groupBy: _groupBy,
      pageStorageId: 'group-by-$_groupBy-tab',
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 168),
          child: ListView(
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
      builder: (context) => AlertDialog(
        title: Text(title),
        scrollable: true,
        content: SizedBox(
          height: options.length.clamp(1, 3).toDouble() * 56.0,
          width: 280,
          child: ListView.builder(
            itemCount: options.length,
            itemExtent: 56,
            itemBuilder: (context, index) {
              final option = options[index];
              return RadioListTile<String>(
                value: option,
                groupValue: selected,
                title: Text(option),
                onChanged: (value) => Navigator.pop(context, value),
              );
            },
          ),
        ),
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
          scrollable: true,
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
                fontSize: 11,
              ),
              unselectedLabelColor: Colors.grey.shade500,
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              tabs: [
                Tab(text: 'My Day (${_getMyDayTasks().length})'),
                const Tab(text: 'My Work'),
                const Tab(text: 'Assign'),
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
                  key: const PageStorageKey('assign-tab'),
                  builder: (_) => _buildAssignTab(),
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
