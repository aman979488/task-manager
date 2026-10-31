import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../utils/role_permissions.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../widgets/app_drawer.dart';
import '../models/floating_sheet_type.dart';
import '../models/task.dart';
import '../utils/task_constants.dart';
import '../viewmodels/map_screen_viewmodel.dart';
import 'dialogs/task_delete_confirmation_dialog.dart';
import 'dialogs/task_notifications_dialog.dart';
import 'dialogs/task_substep_dialog.dart';
import 'dialogs/task_time_dialog.dart';
import 'views/add_task_bottom_sheet.dart';
import 'views/floating_metadata_sheet.dart';
import 'views/map_screen_app_bar.dart';
import 'views/map_screen_tab_views.dart';
import 'views/map_screen_toolbar_menu.dart';
import 'views/task_completion_confirmation_dialog.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.title});

  final String title;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late final bool _hasAdminAccess;
  final TextEditingController _taskSearchController = TextEditingController();
  final Map<int, Offset> _activePointers = {};
  bool _hasBoundViewModel = false;
  bool _isNavigating = false;
  double _pinchStartDistance = 0;
  double _pinchStartZoom = 1.0;

  @override
  void initState() {
    super.initState();
    final role = Provider.of<AuthViewModel>(context, listen: false).appRole;
    _hasAdminAccess = role == AppRole.admin || role == AppRole.superAdmin;
    _tabController = TabController(
      length: _hasAdminAccess ? 8 : 6,
      vsync: this,
      initialIndex: 1,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasBoundViewModel) return;
    _hasBoundViewModel = true;

    final viewModel = Provider.of<MapScreenViewModel>(context, listen: false);
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);

    viewModel.addListener(_handleViewModelChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) viewModel.listenForTasks(authViewModel);
    });
  }

  @override
  void dispose() {
    final viewModel = Provider.of<MapScreenViewModel>(context, listen: false);
    viewModel.removeListener(_handleViewModelChanged);
    _tabController.dispose();
    _taskSearchController.dispose();
    FloatingMetadataSheet.hide();
    super.dispose();
  }

  void _handleViewModelChanged() {
    if (!mounted) return;
    final viewModel = Provider.of<MapScreenViewModel>(context, listen: false);
    final message = viewModel.takeErrorMessage();
    if (message != null) _showMessage(message);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  double _pointerDistance() {
    final points = _activePointers.values.toList();
    return (points[0] - points[1]).distance;
  }

  void _onPointerDown(PointerDownEvent event, MapScreenViewModel viewModel) {
    _activePointers[event.pointer] = event.position;
    if (_activePointers.length == 2) {
      _pinchStartDistance = _pointerDistance();
      _pinchStartZoom = viewModel.zoom;
    } else if (_activePointers.length > 2) {
      _pinchStartDistance = 0;
    }
  }

  void _onPointerMove(PointerMoveEvent event, MapScreenViewModel viewModel) {
    if (!_activePointers.containsKey(event.pointer)) return;
    _activePointers[event.pointer] = event.position;
    if (_activePointers.length != 2 || _pinchStartDistance <= 0) return;

    final newZoom = (_pinchStartZoom *
            (_pointerDistance() / _pinchStartDistance))
        .clamp(0.8, 1.4)
        .toDouble();
    if (newZoom != viewModel.zoom) viewModel.setZoom(newZoom);
  }

  void _onPointerEnd(PointerEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.length < 2) _pinchStartDistance = 0;
  }

  Future<void> _refreshTasks() async {
    final vm = Provider.of<MapScreenViewModel>(context, listen: false);
    final authVm = Provider.of<AuthViewModel>(context, listen: false);
    try {
      await vm.refreshTasks(authVm);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data refreshed successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) _showMessage('Could not refresh tasks: $e');
    }
  }

  Future<void> _openTaskDetail(Task task) async {
    if (_isNavigating) return;
    _isNavigating = true;
    FloatingMetadataSheet.hide();
    final vm = Provider.of<MapScreenViewModel>(context, listen: false);
    try {
      await context.push<void>(
        '/task',
        extra: {'task': task, 'onSave': () => vm.updateTask(task)},
      );
      if (!mounted) return;
      final authVm = Provider.of<AuthViewModel>(context, listen: false);
      await vm.refreshTasks(authVm);
    } finally {
      if (mounted) {
        _isNavigating = false;
      }
    }
  }

  Future<void> _promptAddSubstep(Task task) async {
    final vm = Provider.of<MapScreenViewModel>(context, listen: false);
    await promptAddSubstepDialog(
      context,
      onAdd: (title) => vm.addSubstep(task, title),
    );
  }

  Future<void> _promptSetTaskTime(Task task) async {
    final times = await showTaskTimeDialog(
      context,
      startTime: task.startTime,
      endTime: task.endTime,
    );
    if (times == null || !mounted) return;

    final originalStartTime = task.startTime;
    final originalEndTime = task.endTime;
    task
      ..startTime = times.$1
      ..endTime = times.$2;
    final vm = Provider.of<MapScreenViewModel>(context, listen: false);
    try {
      await vm.updateTask(task);
    } catch (error) {
      task
        ..startTime = originalStartTime
        ..endTime = originalEndTime;
      if (mounted) _showMessage('Could not update task time: $error');
    }
  }

  Future<void> _confirmDeleteSelected(MapScreenViewModel viewModel) async {
    final confirmed = await showTaskDeleteConfirmationDialog(
      context,
      viewModel.selectedCount,
    );
    if (!mounted) return;
    if (confirmed) {
      await viewModel.deleteSelectedTasks();
    }
  }

  Future<void> _toggleTaskDone(
    Task task, {
    bool confirmCompletion = false,
    bool keepInMyDay = false,
  }) async {
    if (confirmCompletion && !task.isDone) {
      final confirmed = await showTaskCompletionConfirmation(
        context,
        task.title,
      );
      if (!confirmed || !mounted) return;
    }
    if (!mounted) return;
    final vm = Provider.of<MapScreenViewModel>(context, listen: false);
    if (keepInMyDay) task.isInMyDay = true;
    await vm.toggleTaskDone(task);
  }

  void _onEditPriority(BuildContext badgeContext, Task task) {
    final vm = Provider.of<MapScreenViewModel>(context, listen: false);
    FloatingMetadataSheet.show(
      context: context,
      buttonContext: badgeContext,
      type: FloatingSheetType.priority,
      selectedValues: task.priority == null ? const [] : [task.priority!],
      onSelected: (val) => vm.updateTaskPriority(task, val),
      onDeselected: (_) => vm.updateTaskPriority(task, null),
    );
  }

  List<Task> _tasksForCurrentTab(
    MapScreenViewModel viewModel,
    AuthViewModel authViewModel,
  ) {
    final myTasks = viewModel.myTasks(authViewModel);
    return switch (_tabController.index) {
      0 => MapScreenViewModel.myDayTasks(myTasks),
      1 => myTasks,
      2 => viewModel.doneTasks(),
      6 when _hasAdminAccess => viewModel.overdueTasks(),
      4 when !_hasAdminAccess => viewModel.overdueTasks(),
      _ => viewModel.tasks,
    };
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<MapScreenViewModel>(context);
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: MapScreenAppBar(
        title: widget.title,
        isSelectionActive: viewModel.isSelectionMode,
        selectedCount: viewModel.selectedCount,
        upcomingNotificationCount: viewModel.upcomingNotificationCount(),
        isSearchVisible: viewModel.isSearchVisible,
        onClearSelection: viewModel.clearSelection,
        onDeleteSelected: () => _confirmDeleteSelected(viewModel),
        onToggleSearch: viewModel.toggleSearchVisibility,
        onOpenNotifications: () =>
            showTaskNotificationsDialog(context, viewModel.upcomingReminders()),
        onOpenMoreOptions: (buttonContext) {
          final currentTabTasks = viewModel.getVisibleTasks(
            source: _tasksForCurrentTab(viewModel, authViewModel),
          );
          MapScreenToolbarMenu.show(
            context: context,
            anchorContext: buttonContext,
            viewModel: viewModel,
            tabController: _tabController,
            screenTitle: widget.title,
            currentTabTasks: currentTabTasks,
            onShowMessage: _showMessage,
          );
        },
      ),
      drawer: viewModel.isSelectionMode ? null : const AppDrawer(),
      body: Column(
        children: [
          if (viewModel.isSearchVisible)
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
                      viewModel.toggleSearchVisibility();
                    },
                  ),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: viewModel.setTaskSearchQuery,
              ),
            ),
          Container(
            color: Colors.white,
            width: double.infinity,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: TaskConstants.secondaryColor,
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
                const Tab(text: 'Days'),
                const Tab(text: 'My Work'),
                const Tab(text: 'Done Work'),
                const Tab(text: 'Goals'),
                const Tab(text: 'Assign'),
                if (_hasAdminAccess) const Tab(text: 'All Work'),
                if (_hasAdminAccess) Tab(text: 'Group by ${viewModel.groupBy}'),
                const Tab(text: 'Overdue'),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (event) => _onPointerDown(event, viewModel),
              onPointerMove: (event) => _onPointerMove(event, viewModel),
              onPointerUp: _onPointerEnd,
              onPointerCancel: _onPointerEnd,
              child: MapScreenTabViews(
                tabController: _tabController,
                hasAdminAccess: _hasAdminAccess,
                viewModel: viewModel,
                authViewModel: authViewModel,
                onOpenTask: _openTaskDetail,
                onRefresh: _refreshTasks,
                onToggleTaskDone: _toggleTaskDone,
                onAddSubstep: _promptAddSubstep,
                onSetTaskTime: _promptSetTaskTime,
                onEditPriority: _onEditPriority,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: viewModel.isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: () => AddTaskBottomSheet.show(context),
              backgroundColor: TaskConstants.primaryColor,
              child: const Icon(Icons.add, color: TaskConstants.secondaryColor),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
