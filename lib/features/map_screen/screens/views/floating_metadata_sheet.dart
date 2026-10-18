import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/floating_sheet_type.dart';
import '../../models/quick_date_time_option.dart';
import '../../utils/task_constants.dart';
import '../../utils/task_mention_parser.dart';
import 'date_time_picker_dialog.dart';

class FloatingMetadataSheet {
  static OverlayEntry? _currentOverlay;
  static final TextEditingController _searchController =
      TextEditingController();
  static String _searchQuery = '';

  static bool get isShowing => _currentOverlay != null;

  static void hide() {
    if (_currentOverlay != null) {
      _currentOverlay!.remove();
      _currentOverlay = null;
    }
    _searchController.clear();
    _searchQuery = '';
  }

  static void update() {
    _currentOverlay?.markNeedsBuild();
  }

  static Future<void> show({
    required BuildContext context,
    required BuildContext buttonContext,
    required FloatingSheetType type,
    Future<List<String>> Function()? loadWorkTypes,
    Future<List<String>> Function()? loadClients,
    Future<List<String>> Function()? loadProjects,
    Future<List<String>> Function()? loadAssignees,
    void Function(String)? onSelected,
    VoidCallback? onDone,
    bool Function()? shouldShow,
    String Function()? searchQuery,
    bool closeOnSelect = false,
    bool multiSelect = false,
    List<String>? selectedValues,
    FocusNode? focusNodeToKeep,
  }) async {
    hide();

    final keepKeyboardOpen =
        type == FloatingSheetType.assign &&
        ((focusNodeToKeep?.hasFocus ?? false) ||
            MediaQuery.viewInsetsOf(buttonContext).bottom > 0 ||
            MediaQuery.viewInsetsOf(context).bottom > 0);

    List<String>? workTypes;
    if (type == FloatingSheetType.workType && loadWorkTypes != null) {
      workTypes = await loadWorkTypes();
    }
    List<String>? clients;
    if (type == FloatingSheetType.clientName && loadClients != null) {
      clients = await loadClients();
    }
    List<String>? projects;
    if (type == FloatingSheetType.refProject && loadProjects != null) {
      projects = await loadProjects();
    }
    List<String>? assignees;
    if (type == FloatingSheetType.assign && loadAssignees != null) {
      assignees = await loadAssignees();
    }

    if (!buttonContext.mounted || !context.mounted) return;
    if (shouldShow != null && !shouldShow()) return;

    final BuildContext rootContext = Navigator.of(
      buttonContext,
      rootNavigator: true,
    ).context;
    final RenderBox button = buttonContext.findRenderObject() as RenderBox;
    final overlayState = Overlay.of(buttonContext);
    if (!overlayState.mounted) return;
    final RenderBox overlay =
        overlayState.context.findRenderObject() as RenderBox;

    String currentQuery() {
      final searchText = _searchController.text.trim();
      final externalQuery = searchQuery?.call().trim() ?? '';
      return (searchText.isNotEmpty
              ? searchText
              : externalQuery.isNotEmpty
              ? externalQuery
              : _searchQuery)
          .trim()
          .toLowerCase();
    }

    List<Widget> buildOptions(StateSetter? setOverlayState) {
      final typedQuery = currentQuery();
      List<String> options = [];
      switch (type) {
        case FloatingSheetType.priority:
          options = TaskConstants.priorityOptions;
          break;
        case FloatingSheetType.remind:
        case FloatingSheetType.deadline:
          options = QuickDateTimeOptions.labels();
          break;
        case FloatingSheetType.assign:
          options = assignees ?? [];
          break;
        case FloatingSheetType.workType:
          options = workTypes ?? TaskConstants.defaultWorkTypes;
          break;
        case FloatingSheetType.folder:
          options = TaskConstants.folderOptions;
          break;
        case FloatingSheetType.clientName:
          options = clients ?? [];
          break;
        case FloatingSheetType.refProject:
          options = projects ?? [];
          break;
      }

      final matchingOptions = typedQuery.isEmpty
          ? const <String>[]
          : options
                .where(
                  (opt) =>
                      TaskMentionParser.matchesSearchQuery(opt, typedQuery),
                )
                .toList();
      final highlightedOption = matchingOptions.firstWhere(
        (opt) => opt.toLowerCase() == typedQuery,
        orElse: () => matchingOptions.isEmpty ? '' : matchingOptions.first,
      );

      return options.map((opt) {
        final bool isSelected = selectedValues?.contains(opt) ?? false;
        final bool isHighlighted =
            highlightedOption.isNotEmpty && opt == highlightedOption;
        return ListTile(
          dense: true,
          selected: isSelected || isHighlighted,
          selectedTileColor: TaskConstants.primaryColor.withValues(alpha: 0.22),
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
              fontSize: 13,
              fontWeight: isSelected || isHighlighted
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: isSelected || isHighlighted
                  ? TaskConstants.secondaryColor
                  : Colors.black87,
            ),
          ),
          trailing: isSelected
              ? const Icon(
                  Icons.check,
                  size: 16,
                  color: TaskConstants.secondaryColor,
                )
              : null,
          onTap: () async {
            final now = DateTime.now();
            final lower = opt.toLowerCase();
            String finalVal = opt;

            if (type == FloatingSheetType.remind ||
                type == FloatingSheetType.deadline) {
              DateTime? computed;
              if (lower.contains('custom')) {
                if (!multiSelect) hide();
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
              hide();
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

    hide();
    final initialQuery = searchQuery?.call() ?? '';
    _searchQuery = initialQuery;
    _searchController.clear();

    _currentOverlay = OverlayEntry(
      builder: (_) => LayoutBuilder(
        builder: (context, constraints) {
          final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
          final usableHeight = (constraints.maxHeight - keyboardInset).clamp(
            0.0,
            constraints.maxHeight,
          );
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
          final menuMaxHeight = openAbove ? spaceAbove : spaceBelow;
          final top = openAbove
              ? currentButtonPosition.dy - menuMaxHeight
              : currentButtonPosition.dy + button.size.height + padding;
          final menuWidth = (constraints.maxWidth - padding * 2).clamp(
            0.0,
            220.0,
          );
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: hide,
                  behavior: HitTestBehavior.translucent,
                ),
              ),
              Positioned(
                right: padding,
                top: openAbove ? null : top,
                bottom: openAbove
                    ? constraints.maxHeight - currentButtonPosition.dy + padding
                    : null,
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
                        final typedQuery = currentQuery();
                        final filteredOptions =
                            showSearch && typedQuery.isNotEmpty
                            ? allOptions.where((tile) {
                                final title =
                                    ((tile as ListTile).title as Text).data!;
                                return TaskMentionParser.matchesSearchQuery(
                                  title,
                                  typedQuery,
                                );
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
                                      autofocus: false,
                                      decoration: InputDecoration(
                                        hintText: 'Search...',
                                        hintStyle: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade400,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.search,
                                          size: 18,
                                          color: Colors.grey.shade400,
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
                                              TaskConstants.secondaryColor,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        onPressed: () {
                                          hide();
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

    Overlay.of(buttonContext).insert(_currentOverlay!);
    if (keepKeyboardOpen && focusNodeToKeep != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!buttonContext.mounted || !focusNodeToKeep.canRequestFocus) return;
        if (!focusNodeToKeep.hasFocus) focusNodeToKeep.requestFocus();
        SystemChannels.textInput.invokeMethod<void>('TextInput.show');
      });
    }
  }
}
