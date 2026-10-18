import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../../services/home_screen_shortcut.dart';
import '../../models/task.dart';
import '../../services/task_share_print_service.dart';
import '../../viewmodels/map_screen_viewmodel.dart';
import '../dialogs/task_options_dialog.dart';
import '../dialogs/task_zoom_dialog.dart';

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
      constraints: const BoxConstraints(maxHeight: 196, maxWidth: 190),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      surfaceTintColor: Colors.transparent,
      color: Colors.white,
      items: [
        _menuItem(
          icon: Icons.sort,
          title: 'Sort by',
          subtitle: viewModel.sortBy,
          value: 'sort',
        ),
        _menuItem(
          icon: Icons.group_work_outlined,
          title: 'Group by',
          subtitle: viewModel.groupBy,
          value: 'group',
        ),
        _menuItem(
          icon: Icons.view_quilt_outlined,
          title: 'View type',
          subtitle: tabController.index == 0
              ? viewModel.myDayViewType
              : viewModel.viewType,
          value: 'view',
        ),
        _menuItem(
          icon: Icons.zoom_in,
          title: 'Adjust zoom',
          subtitle: '${(viewModel.zoom * 100).round()}%',
          value: 'zoom',
        ),
        const PopupMenuDivider(),
        _menuItem(
          icon: Icons.add_to_home_screen,
          title: 'Add shortcut to home screen',
          value: 'shortcut',
        ),
        _menuItem(
          icon: Icons.share_outlined,
          title: 'Share list',
          value: 'share',
        ),
        _menuItem(
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
            tabController.animateTo(8);
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
        final service = TaskSharePrintService();
        await service.printTasks(screenTitle, currentTabTasks);
        break;
    }
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
