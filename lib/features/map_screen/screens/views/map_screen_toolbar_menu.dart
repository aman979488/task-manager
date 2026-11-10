import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../services/home_screen_shortcut.dart';
import '../../../../routes/app_routes.dart';
import '../../models/task.dart';
import '../../services/task_share_print_service.dart';
import '../../viewmodels/map_screen_viewmodel.dart';
import '../dialogs/task_options_dialog.dart';
import '../dialogs/task_zoom_dialog.dart';

enum _PrintGoalFilter { weekly, monthly, all }

enum _PrintStatusFilter { pending, done, all }

class _PrintSelection {
  const _PrintSelection({required this.goal, required this.status});

  final _PrintGoalFilter goal;
  final _PrintStatusFilter status;
}

class MapScreenToolbarMenu {
  static Future<void> show({
    required BuildContext context,
    required BuildContext anchorContext,
    required MapScreenViewModel viewModel,
    required TabController tabController,
    required String screenTitle,
    required List<Task> currentTabTasks,
    required void Function(String message) onShowMessage,
  }) async {
    final buttonBox = anchorContext.findRenderObject()! as RenderBox;
    final overlayBox =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final buttonTopLeft = buttonBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final buttonBottomRight = buttonBox.localToGlobal(
      buttonBox.size.bottomRight(Offset.zero),
      ancestor: overlayBox,
    );
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        buttonTopLeft.translate(0, buttonBox.size.height + 12),
        buttonBottomRight.translate(0, buttonBox.size.height + 12),
      ),
      Offset.zero & overlayBox.size,
    );

    final action = await showMenu<String>(
      context: context,
      position: position,
      constraints: const BoxConstraints(maxHeight: 196, maxWidth: 220),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      surfaceTintColor: Colors.transparent,
      color: Colors.white,
      items: [
        _PrintActions._menuItem(
          icon: Icons.sort,
          title: 'Sort by',
          subtitle: viewModel.sortBy,
          value: 'sort',
        ),
        _PrintActions._menuItem(
          icon: Icons.group_work_outlined,
          title: 'Group by',
          subtitle: viewModel.groupBy,
          value: 'group',
        ),
        _PrintActions._menuItem(
          icon: Icons.view_quilt_outlined,
          title: 'View type',
          subtitle: tabController.index == 0
              ? viewModel.myDayViewType
              : viewModel.viewType,
          value: 'view',
        ),
        _PrintActions._menuItem(
          icon: Icons.zoom_in,
          title: 'Adjust zoom',
          subtitle: '${(viewModel.zoom * 100).round()}%',
          value: 'zoom',
        ),
        const PopupMenuDivider(),
        _PrintActions._menuItem(
          icon: Icons.call,
          title: 'Call History',
          value: 'call-history',
        ),
        _PrintActions._menuItem(
          icon: Icons.add_to_home_screen,
          title: 'Add shortcut to home screen',
          value: 'shortcut',
        ),
        _PrintActions._menuItem(
          icon: Icons.share_outlined,
          title: 'Share list',
          value: 'share',
        ),
        _PrintActions._menuItem(
          icon: Icons.print_outlined,
          title: 'Print list',
          value: 'print',
        ),
      ],
    );

    if (!context.mounted || action == null) return;

    switch (action) {
      case 'sort':
        await chooseTaskOptionDialog(
          context: context,
          title: 'Sort by',
          options: const ['Priority', 'Title', 'Due date', 'Status'],
          selected: viewModel.sortBy,
          onSelected: viewModel.setSortBy,
        );
        break;
      case 'group':
        await chooseTaskOptionDialog(
          context: context,
          title: 'Group by',
          options: const ['Assignee', 'Priority', 'Work type', 'Status'],
          selected: viewModel.groupBy,
          onSelected: (value) {
            viewModel.setGroupBy(value);
            if (tabController.length > 5) {
              tabController.animateTo(tabController.length - 1);
            }
          },
        );
        break;
      case 'view':
        final isMyDay = tabController.index == 0;
        await chooseTaskOptionDialog(
          context: context,
          title: 'View type',
          options: isMyDay
              ? const [
                  'Grid',
                  'List',
                  'Detailed list',
                  'Calendar',
                  'Day',
                  '3 Day',
                  'Week',
                  'Month',
                ]
              : const ['Grid', 'List', 'Detailed list', 'Calendar'],
          selected: isMyDay ? viewModel.myDayViewType : viewModel.viewType,
          onSelected: isMyDay
              ? viewModel.setMyDayViewType
              : viewModel.setViewType,
        );
        break;
      case 'zoom':
        await showTaskZoomDialog(
          context,
          currentZoom: viewModel.zoom,
          onZoomChanged: viewModel.setZoom,
        );
        break;
      case 'call-history':
        await context.push<void>(AppRoutes.callHistory);
        break;
      case 'shortcut':
        final added = await installHomeScreenShortcut();
        if (context.mounted) {
          onShowMessage(
            added
                ? 'Home screen shortcut added.'
                : kIsWeb
                ? 'Use the browser menu and choose "Add to Home screen" or "Install app".'
                : 'This platform does not allow the app to add a home screen shortcut automatically.',
          );
        }
        break;
      case 'share':
        final service = TaskSharePrintService();
        await service.shareTasks(screenTitle, currentTabTasks);
        break;
      case 'print':
        await _PrintActions._showPrintOptions(
          context: context,
          tasks: viewModel.tasks,
          screenTitle: screenTitle,
        );
        break;
    }
  }
}

class _PrintSelectionDialog extends StatefulWidget {
  const _PrintSelectionDialog({required this.tasks});

  final List<Task> tasks;

  @override
  State<_PrintSelectionDialog> createState() => _PrintSelectionDialogState();
}

class _PrintSelectionDialogState extends State<_PrintSelectionDialog> {
  _PrintGoalFilter _goal = _PrintGoalFilter.weekly;
  _PrintStatusFilter _status = _PrintStatusFilter.pending;

  List<Task> get _filteredTasks => widget.tasks.where((task) {
    final matchesGoal = switch (_goal) {
      _PrintGoalFilter.weekly => !task.isMonthlyGoal,
      _PrintGoalFilter.monthly => task.isMonthlyGoal,
      _PrintGoalFilter.all => true,
    };
    final matchesStatus = switch (_status) {
      _PrintStatusFilter.pending => !task.isDone,
      _PrintStatusFilter.done => task.isDone,
      _PrintStatusFilter.all => true,
    };
    return matchesGoal && matchesStatus;
  }).toList();

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 4),
    contentPadding: const EdgeInsets.fromLTRB(22, 10, 22, 8),
    actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
    title: const Text(
      'Print task list',
      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
    ),
    content: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose a goal type and status. You can combine them, '
            'for example Weekly + Pending.',
            style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade600),
          ),
          const SizedBox(height: 20),
          _filterLabel('GOAL TYPE'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _goalChip('Weekly', _PrintGoalFilter.weekly),
              _goalChip('Monthly', _PrintGoalFilter.monthly),
              _goalChip('All', _PrintGoalFilter.all),
            ],
          ),
          const SizedBox(height: 18),
          _filterLabel('TASK STATUS'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusChip('Pending', _PrintStatusFilter.pending),
              _statusChip('Done', _PrintStatusFilter.done),
              _statusChip('All', _PrintStatusFilter.all),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8DC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.list_alt_rounded,
                  size: 20,
                  color: Color(0xFF6B5800),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${_filteredTasks.length} '
                    '${_filteredTasks.length == 1 ? 'task' : 'tasks'} selected',
                    style: const TextStyle(
                      color: Color(0xFF514400),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed: () =>
            Navigator.of(context)
                .pop(_PrintSelection(goal: _goal, status: _status)),
        icon: const Icon(Icons.print_outlined, size: 18),
        label: const Text('Print'),
      ),
    ],
  );

  Widget _filterLabel(String label) => Text(
    label,
    style: TextStyle(
      color: Colors.blueGrey.shade700,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    ),
  );

  Widget _goalChip(String label, _PrintGoalFilter value) => ChoiceChip(
    label: Text(label),
    selected: _goal == value,
    onSelected: (_) => setState(() => _goal = value),
    selectedColor: const Color(0xFFFFEBA0),
    labelStyle: TextStyle(
      color: _goal == value
          ? const Color(0xFF514400)
          : Colors.blueGrey.shade800,
      fontWeight: _goal == value ? FontWeight.w600 : FontWeight.normal,
    ),
    side: BorderSide(
      color: _goal == value
          ? const Color(0xFFE2C34D)
          : Colors.blueGrey.shade100,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  );

  Widget _statusChip(String label, _PrintStatusFilter value) => ChoiceChip(
    label: Text(label),
    selected: _status == value,
    onSelected: (_) => setState(() => _status = value),
    selectedColor: const Color(0xFFDCEFE3),
    labelStyle: TextStyle(
      color: _status == value
          ? const Color(0xFF205A34)
          : Colors.blueGrey.shade800,
      fontWeight: _status == value ? FontWeight.w600 : FontWeight.normal,
    ),
    side: BorderSide(
      color: _status == value
          ? const Color(0xFF9AC9A7)
          : Colors.blueGrey.shade100,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  );
}

class _PrintActions {
  static Future<void> _showPrintOptions({
    required BuildContext context,
    required List<Task> tasks,
    required String screenTitle,
  }) async {
    final selection = await showDialog<_PrintSelection>(
      context: context,
      builder: (_) => _PrintSelectionDialog(tasks: tasks),
    );
    if (!context.mounted || selection == null) return;

    final filteredTasks = tasks.where((task) {
      final matchesGoal = switch (selection.goal) {
        _PrintGoalFilter.weekly => !task.isMonthlyGoal,
        _PrintGoalFilter.monthly => task.isMonthlyGoal,
        _PrintGoalFilter.all => true,
      };
      final matchesStatus = switch (selection.status) {
        _PrintStatusFilter.pending => !task.isDone,
        _PrintStatusFilter.done => task.isDone,
        _PrintStatusFilter.all => true,
      };
      return matchesGoal && matchesStatus;
    }).toList();
    final goalLabel = switch (selection.goal) {
      _PrintGoalFilter.weekly => 'Weekly',
      _PrintGoalFilter.monthly => 'Monthly',
      _PrintGoalFilter.all => 'All goals',
    };
    final statusLabel = switch (selection.status) {
      _PrintStatusFilter.pending => 'Pending',
      _PrintStatusFilter.done => 'Done',
      _PrintStatusFilter.all => 'All statuses',
    };
    await TaskSharePrintService().printTasks(
      '$screenTitle - $goalLabel - $statusLabel',
      filteredTasks,
    );
  }

  static PopupMenuItem<String> _menuItem({
    required IconData icon,
    required String title,
    required String value,
    String? subtitle,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: subtitle == null ? 48 : 60,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subtitle != null)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
