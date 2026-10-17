import 'package:flutter/material.dart';

import '../../utils/task_constants.dart';

class MapScreenAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MapScreenAppBar({
    super.key,
    required this.title,
    required this.isSelectionActive,
    required this.selectedCount,
    required this.upcomingNotificationCount,
    required this.isSearchVisible,
    required this.onClearSelection,
    required this.onDeleteSelected,
    required this.onToggleSearch,
    required this.onOpenNotifications,
    required this.onOpenMoreOptions,
  });

  final String title;
  final bool isSelectionActive;
  final int selectedCount;
  final int upcomingNotificationCount;
  final bool isSearchVisible;
  final VoidCallback onClearSelection;
  final VoidCallback onDeleteSelected;
  final VoidCallback onToggleSearch;
  final VoidCallback onOpenNotifications;
  final ValueChanged<BuildContext> onOpenMoreOptions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    if (isSelectionActive) {
      return AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: TaskConstants.secondaryColor),
        leading: IconButton(
          icon: const Icon(Icons.close, color: TaskConstants.secondaryColor),
          onPressed: onClearSelection,
        ),
        title: Text(
          '$selectedCount selected',
          style: const TextStyle(
            color: TaskConstants.secondaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: onDeleteSelected,
          ),
          const SizedBox(width: 8),
        ],
      );
    }

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu, color: Colors.black),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: TaskConstants.secondaryColor,
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
              color: TaskConstants.secondaryColor,
            ),
          ),
          onPressed: onOpenNotifications,
        ),
        IconButton(
          tooltip: isSearchVisible ? 'Close search' : 'Search tasks',
          icon: Icon(
            isSearchVisible ? Icons.close : Icons.search,
            color: TaskConstants.secondaryColor,
          ),
          onPressed: onToggleSearch,
        ),
        Builder(
          builder: (buttonContext) => IconButton(
            tooltip: 'More options',
            icon: const Icon(
              Icons.more_vert,
              color: TaskConstants.secondaryColor,
            ),
            onPressed: () => onOpenMoreOptions(buttonContext),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
