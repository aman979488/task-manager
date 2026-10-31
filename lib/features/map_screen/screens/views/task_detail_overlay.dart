import 'package:flutter/material.dart';

import '../../models/floating_sheet_type.dart';
import '../../models/quick_date_time_option.dart';
import '../../utils/task_constants.dart';
import '../../utils/task_week_helpers.dart';
import 'date_time_picker_dialog.dart';

class TaskDetailOverlay {
  OverlayEntry? _overlayEntry;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool get isShowing => _overlayEntry != null;

  void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _searchController.clear();
    _searchQuery = '';
  }

  void dispose() {
    hide();
    _searchController.dispose();
  }

  Future<void> show({
    required BuildContext buttonContext,
    required FloatingSheetType type,
    String? fieldKey,
    required Future<List<String>> Function() loadWorkTypes,
    required Future<List<String>> Function() loadAssignees,
    required Future<List<String>> Function() loadClients,
    required Future<List<String>> Function() loadFolders,
    required Future<List<String>> Function() loadProjects,
    required void Function(String key, String value) onSelectOption,
    required void Function(String key) onDeselectOption,
    required void Function(String key, DateTime value) onSelectDateTime,
    String? selectedValue,
    List<String> goalWeekKeys = const [],
  }) async {
    if (_overlayEntry != null) hide();

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
        case FloatingSheetType.goal:
          resolvedKey = 'goal';
          break;
      }
    }

    List<String>? workTypes;
    List<String>? assignees;
    List<String>? clients;
    List<String>? folders;
    List<String>? projects;

    if (resolvedKey == 'workType') {
      workTypes = await loadWorkTypes();
    } else if (resolvedKey == 'assignee') {
      assignees = await loadAssignees();
    } else if (resolvedKey == 'clientName') {
      clients = await loadClients();
    } else if (resolvedKey == 'folder') {
      folders = await loadFolders();
    } else if (resolvedKey == 'refProject') {
      projects = await loadProjects();
    }

    if (!buttonContext.mounted) return;
    final OverlayState overlayState = Overlay.of(buttonContext);
    if (!overlayState.mounted || !overlayState.context.mounted) return;
    final RenderBox button = buttonContext.findRenderObject() as RenderBox;
    final RenderBox overlayBox =
        overlayState.context.findRenderObject() as RenderBox;

    List<Widget> tilesFor(String key) {
      switch (key) {
        case 'goal':
          return goalWeekKeys
              .map(
                (weekKey) => ListTile(
                  title: Text(weekLabelForKey(weekKey)),
                ),
              )
              .toList();
        case 'priority':
          return TaskConstants.priorityOptions
              .map((priority) => ListTile(title: Text(priority)))
              .toList();
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
        case 'monitor':
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
    String? selectedOptionLabel;
    if (resolvedKey == 'goal' && selectedValue != null) {
      selectedOptionLabel = weekLabelForKey(selectedValue);
    } else if (resolvedKey == 'reminder' || resolvedKey == 'deadline') {
      final selectedDate = DateTime.tryParse(selectedValue ?? '');
      if (selectedDate != null) {
        selectedOptionLabel = 'Custom';
        final now = DateTime.now();
        for (final option in QuickDateTimeOptions.options(now: now)) {
          final optionDate = option.resolve(now);
          if (selectedDate.year == optionDate.year &&
              selectedDate.month == optionDate.month &&
              selectedDate.day == optionDate.day &&
              selectedDate.hour == optionDate.hour &&
              selectedDate.minute == optionDate.minute) {
            selectedOptionLabel = option.label;
            break;
          }
        }
      }
    } else {
      selectedOptionLabel = selectedValue;
    }

    final markedTiles = tileWidgets.map((tile) {
      if (tile is! ListTile) return tile;
      final label = (tile.title as Text).data ?? '';
      final isSelected = label == selectedOptionLabel;
      return ListTile(
        leading: tile.leading,
        title: tile.title,
        trailing: isSelected
            ? const Icon(Icons.check, color: TaskConstants.secondaryColor)
            : tile.trailing,
        selected: isSelected,
        selectedTileColor: TaskConstants.primaryColor.withValues(alpha: 0.22),
      );
    }).toList();

    final bool hasSearchBar =
        resolvedKey == 'assignee' ||
        resolvedKey == 'monitor' ||
        resolvedKey == 'workType' ||
        resolvedKey == 'clientName' ||
        resolvedKey == 'refProject';

    const double maxMenuWidth = 260;
    const double horizontalPadding = 4;
    const double verticalPadding = 8;
    const double optionRowHeight = 56;
    final visibleOptionCount = resolvedKey == 'priority' ? 5 : 3;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
            final usableHeight = (constraints.maxHeight - keyboardInset)
                .clamp(0.0, constraints.maxHeight)
                .toDouble();
            final currentButtonPosition = button.localToGlobal(
              Offset.zero,
              ancestor: overlayBox,
            );
            final menuWidth = (constraints.maxWidth - horizontalPadding * 2)
                .clamp(0.0, maxMenuWidth)
                .toDouble();
            final buttonTop = currentButtonPosition.dy;
            final buttonBottom = buttonTop + button.size.height;
            final spaceBelow =
                (usableHeight - buttonBottom - verticalPadding * 2)
                    .clamp(0.0, usableHeight)
                    .toDouble();
            final spaceAbove = (buttonTop - verticalPadding * 2)
                .clamp(0.0, usableHeight)
                .toDouble();
            final desiredMenuHeight =
                (hasSearchBar ? 72.0 : 0.0) +
                (markedTiles.length.clamp(0, visibleOptionCount) *
                    optionRowHeight);
            final openAbove =
                buttonTop >= usableHeight * 0.6 ||
                (spaceBelow < desiredMenuHeight && spaceAbove > spaceBelow);
            final availableHeight = openAbove ? spaceAbove : spaceBelow;
            final menuMaxHeight = desiredMenuHeight
                .clamp(0.0, availableHeight)
                .toDouble();
            final menuTop = openAbove
                ? buttonTop - menuMaxHeight - verticalPadding
                : buttonBottom + verticalPadding;
            final maxOptionListHeight =
                (menuMaxHeight - (hasSearchBar ? 72 : 0))
                    .clamp(0.0, optionRowHeight * visibleOptionCount)
                    .toDouble();

            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: hide,
                    onPanStart: (_) => hide(),
                    child: const SizedBox.expand(),
                  ),
                ),
                Positioned(
                  right: horizontalPadding,
                  top: menuTop,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: menuMaxHeight),
                    child: Material(
                      color: Colors.white,
                      elevation: 6,
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: menuWidth,
                        child: StatefulBuilder(
                          builder: (context, setOverlayState) {
                            final allTiles = markedTiles;
                            final filteredTiles =
                                hasSearchBar && _searchQuery.isNotEmpty
                                ? allTiles.where((tile) {
                                    if (tile is! ListTile) return true;
                                    final text =
                                        (tile.title as Text).data ?? '';
                                    return text.toLowerCase().contains(
                                      _searchQuery.toLowerCase(),
                                    );
                                  }).toList()
                                : allTiles;
                            final optionListHeight =
                                (filteredTiles.length * optionRowHeight)
                                    .clamp(0.0, maxOptionListHeight)
                                    .toDouble();

                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (hasSearchBar)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      10,
                                      10,
                                      10,
                                      6,
                                    ),
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
                                if (filteredTiles.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      'No results found',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  )
                                else
                                  SizedBox(
                                    height: optionListHeight,
                                    child: ListView(
                                      padding: EdgeInsets.zero,
                                      children: filteredTiles.map((tile) {
                                        return InkWell(
                                          onTap: () async {
                                            if (tile is ListTile) {
                                              final label =
                                                  (tile.title as Text).data ??
                                                  '';

                                              if (label ==
                                                  selectedOptionLabel) {
                                                onDeselectOption(resolvedKey);
                                                hide();
                                                return;
                                              }

                                              if (resolvedKey == 'reminder' ||
                                                  resolvedKey == 'deadline') {
                                                DateTime? computed;

                                                if (label
                                                    .toLowerCase()
                                                    .contains('custom')) {
                                                  hide();
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
                                                  onSelectDateTime(
                                                    resolvedKey,
                                                    computed,
                                                  );
                                                }
                                              } else {
                                                final selectedValue =
                                                    resolvedKey == 'goal'
                                                    ? goalWeekKeys.firstWhere(
                                                        (weekKey) =>
                                                            weekLabelForKey(
                                                              weekKey,
                                                            ) ==
                                                            label,
                                                      )
                                                    : label;
                                                onSelectOption(
                                                  resolvedKey,
                                                  selectedValue,
                                                );
                                              }

                                              _searchController.clear();
                                              _searchQuery = '';
                                              hide();
                                            } else {
                                              hide();
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
                ),
              ],
            );
          },
        );
      },
    );

    overlayState.insert(_overlayEntry!);
  }
}
