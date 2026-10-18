import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../viewmodels/auth_viewmodel.dart';
import '../../models/floating_sheet_type.dart';
import '../../models/quick_date_time_option.dart';
import '../../utils/task_constants.dart';
import '../../utils/task_date_formatter.dart';
import '../../utils/task_mention_parser.dart';
import '../../viewmodels/add_task_viewmodel.dart';
import '../../viewmodels/map_screen_viewmodel.dart';
import '../dialogs/task_symbol_help_dialog.dart';
import '../widgets/sheet_option_button.dart';
import 'add_task_metadata_bar.dart';
import 'add_task_sheet.dart';
import 'date_time_picker_dialog.dart';
import 'floating_metadata_sheet.dart';

class AddTaskBottomSheet extends StatefulWidget {
  const AddTaskBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    final addTaskViewModel = context.read<AddTaskViewModel>();
    final mapScreenViewModel = context.read<MapScreenViewModel>();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      isDismissible: true,
      enableDrag: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      constraints: kIsWeb
          ? BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85)
          : null,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider<AddTaskViewModel>.value(
            value: addTaskViewModel,
          ),
          ChangeNotifierProvider<MapScreenViewModel>.value(
            value: mapScreenViewModel,
          ),
        ],
        child: const AddTaskBottomSheet(),
      ),
    ).whenComplete(() {
      FloatingMetadataSheet.hide();
      if (!kIsWeb) {
        SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      }
    });
  }

  @override
  State<AddTaskBottomSheet> createState() => _AddTaskBottomSheetState();
}

class _AddTaskBottomSheetState extends State<AddTaskBottomSheet> {
  final TextEditingController _taskNameController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final Map<FloatingSheetType, GlobalKey> _buttonKeys = {
    for (final type in FloatingSheetType.values) type: GlobalKey(),
  };

  bool _initialFocusScheduled = false;
  String? _mentionQuery;
  String _mentionSymbol = '@';
  int _mentionStart = -1;
  int _mentionEnd = -1;
  String? _activePickerSymbol;
  String _mentionSourceText = '';
  int _highlightedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final addVm = Provider.of<AddTaskViewModel>(context, listen: false);
      addVm.loadButtonOrder();
    });
  }

  @override
  void dispose() {
    FloatingMetadataSheet.hide();
    _focusNode.dispose();
    _taskNameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onMetadataChanged(FloatingSheetType type, String? value) {
    final addVm = Provider.of<AddTaskViewModel>(context, listen: false);
    final shouldScroll = addVm.setValue(type, value);
    if (shouldScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final step = MediaQuery.of(context).size.width < 600 ? 118.0 : 156.0;
        final nextOffset = (_scrollController.offset + step)
            .clamp(0.0, _scrollController.position.maxScrollExtent)
            .toDouble();
        _scrollController.animateTo(
          nextOffset,
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOutCubic,
        );
      });
    }
  }

  Future<List<String>> _loadMentionSource(String symbol) async {
    final mapVm = Provider.of<MapScreenViewModel>(context, listen: false);
    switch (symbol) {
      case '-':
        return TaskConstants.priorityOptions;
      case '@':
        return mapVm.loadAssignees();
      case '!':
      case '*':
        return QuickDateTimeOptions.labels();
      case '+':
        return mapVm.loadWorkTypes();
      case '#':
        return mapVm.loadClients();
      case '^':
        return mapVm.loadProjects();
      default:
        return const <String>[];
    }
  }

  Future<void> _completeMention(String selectedOption) async {
    final symbol = _mentionSymbol;
    final type = TaskMentionParser.typeForSymbol(symbol);
    if (type == null) return;

    var finalValue = selectedOption;
    if (type == FloatingSheetType.deadline ||
        type == FloatingSheetType.remind) {
      final lower = selectedOption.toLowerCase();
      DateTime? selectedDate = DateTime.tryParse(selectedOption);
      if (selectedDate == null && lower.contains('custom')) {
        selectedDate = await showDateTimePickerWithTabs(context);
        if (!mounted) return;
      } else {
        selectedDate ??= QuickDateTimeOptions.resolve(selectedOption);
      }
      if (selectedDate == null) return;
      finalValue = selectedDate.toIso8601String();
    }

    final currentText = _mentionSourceText.isNotEmpty
        ? _mentionSourceText
        : _taskNameController.text;
    final tokenResult = TaskMentionParser.removeMentionToken(
      text: currentText,
      start: _mentionStart,
      end: _mentionEnd,
    );

    setState(() {
      _mentionQuery = null;
      _mentionStart = -1;
      _mentionEnd = -1;
      _activePickerSymbol = null;
    });

    _taskNameController.value = TextEditingValue(
      text: tokenResult.newText,
      selection: TextSelection.collapsed(offset: tokenResult.newCursor),
    );

    if (!_focusNode.hasFocus) _focusNode.requestFocus();

    final addVm = Provider.of<AddTaskViewModel>(context, listen: false);
    if (type == FloatingSheetType.assign) {
      addVm.addAssignee(finalValue);
    } else {
      _onMetadataChanged(type, finalValue);
    }
  }

  Future<void> _selectMentionOnEnter() async {
    final query = _mentionQuery?.trim() ?? '';
    if (query.isEmpty) return;
    final symbol = _mentionSymbol;

    try {
      final options = await _loadMentionSource(symbol);
      if (_mentionQuery?.trim() != query || _mentionSymbol != symbol) return;

      final normalizedQuery = query.toLowerCase();
      final matches = options
          .where(
            (opt) => TaskMentionParser.matchesSearchQuery(opt, normalizedQuery),
          )
          .toList();
      if (matches.isEmpty) return;

      final selected = matches.firstWhere(
        (opt) => opt.toLowerCase() == normalizedQuery,
        orElse: () => matches.first,
      );

      _activePickerSymbol = null;
      FloatingMetadataSheet.hide();
      await _completeMention(selected);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load options: $error')),
        );
      }
    }
  }

  void _openMetadataFloatingSheet(
    BuildContext buttonContext,
    FloatingSheetType type,
  ) {
    final mapVm = Provider.of<MapScreenViewModel>(context, listen: false);
    final addVm = Provider.of<AddTaskViewModel>(context, listen: false);

    final isMulti = type == FloatingSheetType.assign;
    final currentSelections = isMulti ? addVm.selectedAssignees : <String>[];

    FloatingMetadataSheet.show(
      context: context,
      buttonContext: buttonContext,
      type: type,
      loadWorkTypes: mapVm.loadWorkTypes,
      loadClients: mapVm.loadClients,
      loadProjects: mapVm.loadProjects,
      loadAssignees: mapVm.loadAssignees,
      multiSelect: isMulti,
      closeOnSelect: isMulti,
      selectedValues: currentSelections,
      focusNodeToKeep: _focusNode,
      onSelected: (val) {
        if (type == FloatingSheetType.assign) {
          addVm.addAssignee(val);
        } else {
          _onMetadataChanged(type, val);
        }
      },
    );
  }

  Widget _buildMetadataButton(
    FloatingSheetType type,
    bool compact,
    AddTaskViewModel addVm,
  ) {
    IconData icon = Icons.help_outline;
    String label = '';
    String? selectedValue;
    VoidCallback onClear = () {};

    switch (type) {
      case FloatingSheetType.priority:
        icon = Icons.flag_outlined;
        label = 'Priority';
        selectedValue = addVm.priority;
        onClear = () => _onMetadataChanged(type, null);
        break;
      case FloatingSheetType.remind:
        icon = Icons.notifications_active;
        label = 'Remind Me';
        selectedValue = addVm.reminder != null
            ? TaskDateFormatter.formatDateTime(addVm.reminder!)
            : null;
        onClear = () => _onMetadataChanged(type, null);
        break;
      case FloatingSheetType.assign:
        icon = Icons.assignment;
        label = 'Assign';
        selectedValue = addVm.assignee;
        onClear = () => _onMetadataChanged(type, null);
        break;
      case FloatingSheetType.deadline:
        icon = Icons.alarm;
        label = 'Deadline';
        selectedValue = addVm.deadline != null
            ? TaskDateFormatter.formatDateTime(addVm.deadline!)
            : null;
        onClear = () => _onMetadataChanged(type, null);
        break;
      case FloatingSheetType.workType:
        icon = Icons.insert_drive_file;
        label = 'Work Type';
        selectedValue = addVm.workType;
        onClear = () => _onMetadataChanged(type, null);
        break;
      case FloatingSheetType.folder:
        icon = Icons.folder_outlined;
        label = 'Folder';
        selectedValue = addVm.folder;
        onClear = () => _onMetadataChanged(type, null);
        break;
      case FloatingSheetType.clientName:
        icon = Icons.business_center_outlined;
        label = 'Client Name';
        selectedValue = addVm.clientName;
        onClear = () => _onMetadataChanged(type, null);
        break;
      case FloatingSheetType.refProject:
        icon = Icons.apartment_outlined;
        label = 'Ref Project';
        selectedValue = addVm.refProject;
        onClear = () => _onMetadataChanged(type, null);
        break;
    }

    final bool isSelected = selectedValue != null && selectedValue.isNotEmpty;
    final String displayText = isSelected ? selectedValue : label;

    return SheetOptionButton(
      key: _buttonKeys[type],
      icon: icon,
      label: label,
      displayText: displayText,
      selected: isSelected,
      compact: compact,
      onClear: onClear,
      onTap: () {
        final btnContext = _buttonKeys[type]?.currentContext ?? context;
        _openMetadataFloatingSheet(btnContext, type);
      },
    );
  }
  String _capitalizeFirst(String text) {
  final t = text.trim();
  if (t.isEmpty) return t;
  return t[0].toUpperCase() + t.substring(1);
}

  Future<void> _handleSubmit() async {
    final title = _capitalizeFirst(_taskNameController.text);
    if (title.isEmpty) return;

    final authVm = Provider.of<AuthViewModel>(context, listen: false);
    final mapVm = Provider.of<MapScreenViewModel>(context, listen: false);
    final addVm = Provider.of<AddTaskViewModel>(context, listen: false);

    final success = await addVm.submitTask(
      title: title,
      authViewModel: authVm,
      mapViewModel: mapVm,
    );

    if (success && mounted) {
      _taskNameController.clear();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final addVm = Provider.of<AddTaskViewModel>(context);
    final mapVm = Provider.of<MapScreenViewModel>(context, listen: false);
    final screenWidth = MediaQuery.of(context).size.width;
    final systemNavBar = MediaQuery.of(context).padding.bottom;
    final bottomPadding = 16.0 + (kIsWeb ? 0.0 : systemNavBar);

    final isIosWeb = kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    if (!_initialFocusScheduled && !isIosWeb) {
      _initialFocusScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _focusNode.canRequestFocus) {
          _focusNode.requestFocus();
        }
      });
    }

    final mobileButtonOrder = [
      ...addVm.buttonOrder.where((t) => t != FloatingSheetType.refProject),
      FloatingSheetType.refProject,
    ];

    return PopScope<Object?>(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        FloatingMetadataSheet.hide();
        _focusNode.unfocus();
        FocusScope.of(context).unfocus();
        if (!kIsWeb) {
          SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        }
      },
      child: AddTaskSheet(
        bottomPadding: bottomPadding + MediaQuery.viewInsetsOf(context).bottom,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AddTaskMetadataBar(
              buttonOrder: mobileButtonOrder,
              metadataOrder: addVm.metadataOrder,
              scrollController: _scrollController,
              compact: screenWidth < 600,
              buttonBuilder: (type, compact) =>
                  _buildMetadataButton(type, compact, addVm),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Builder(
                    builder: (textFieldCtx) => Focus(
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent &&
                            (event.logicalKey == LogicalKeyboardKey.enter ||
                                event.logicalKey ==
                                    LogicalKeyboardKey.numpadEnter) &&
                            _mentionQuery != null) {
                          if (_mentionQuery!.trim().isEmpty) {
                            return KeyEventResult.ignored;
                          }
                          unawaited(_selectMentionOnEnter());
                          return KeyEventResult.handled;
                        }

                        if (event is! KeyDownEvent ||
                            event.logicalKey != LogicalKeyboardKey.tab ||
                            _mentionQuery == null) {
                          return KeyEventResult.ignored;
                        }

                        final query = _mentionQuery!;
                        final symbol = _mentionSymbol;
                        unawaited(() async {
                          try {
                            final source = await _loadMentionSource(symbol);
                            final matches = source
                                .where(
                                  (opt) => TaskMentionParser.matchesSearchQuery(
                                    opt,
                                    query,
                                  ),
                                )
                                .toList();
                            if (matches.isEmpty) return;
                            final index = _highlightedIndex.clamp(
                              0,
                              matches.length - 1,
                            );
                            await _completeMention(matches[index]);
                          } catch (error) {
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
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
                        textEditingController: _taskNameController,
                        focusNode: _focusNode,
                        optionsViewOpenDirection: OptionsViewOpenDirection.up,
                        optionsBuilder: (_) => const <String>[],
                        onSelected: _completeMention,
                        optionsViewBuilder: (ctx, onSelected, options) {
                          final matches = options.toList();
                          final highlightedIdx =
                              AutocompleteHighlightedOption.of(ctx);
                          _highlightedIndex = highlightedIdx;
                          return LayoutBuilder(
                            builder: (c, constraints) {
                              final availableHeight =
                                  constraints.hasBoundedHeight
                                  ? constraints.maxHeight
                                  : 260.0;
                              final popupHeight = availableHeight
                                  .clamp(0.0, 210.0)
                                  .toDouble();
                              const doneAreaHeight = 56.0;
                              final showDone = popupHeight >= doneAreaHeight;
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
                                                final name = matches[index];
                                                return ListTile(
                                                  dense: true,
                                                  selected:
                                                      index == highlightedIdx,
                                                  selectedTileColor:
                                                      TaskConstants.primaryColor
                                                          .withValues(
                                                            alpha: 0.45,
                                                          ),
                                                  title: Text(
                                                    name,
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  onTap: () => onSelected(name),
                                                );
                                              },
                                            ),
                                          ),
                                          if (showDone)
                                            Padding(
                                              padding: const EdgeInsets.all(8),
                                              child: SizedBox(
                                                width: double.infinity,
                                                child: ElevatedButton(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            TaskConstants
                                                                .primaryColor,
                                                        foregroundColor:
                                                            TaskConstants
                                                                .secondaryColor,
                                                      ),
                                                  onPressed: () {
                                                    final idx = highlightedIdx
                                                        .clamp(
                                                          0,
                                                          matches.length - 1,
                                                        );
                                                    onSelected(matches[idx]);
                                                  },
                                                  child: const Text('Done'),
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
                              ctx,
                              controller,
                              focusNode,
                              onFieldSubmitted,
                            ) => TextField(
                              controller: controller,
                              focusNode: focusNode,
                              onTap: () {
                                if (!focusNode.hasFocus) {
                                  focusNode.requestFocus();
                                } else if (kIsWeb) {
                                  SystemChannels.textInput.invokeMethod<void>(
                                    'TextInput.show',
                                  );
                                }
                              },
                              onEditingComplete: () {},
                              onTapOutside: (_) {},
                              minLines: 1,
                              maxLines: 4,
                              textInputAction: _mentionQuery == null
                                  ? TextInputAction.done
                                  : TextInputAction.search,
                              decoration: const InputDecoration(
                                hintText: 'Add a task',
                                border: InputBorder.none,
                              ),
                              onChanged: (val) {
                                final cursor = controller.selection.baseOffset;
                                final safeCursor = cursor.clamp(0, val.length);
                                final m = TaskMentionParser.parseMention(
                                  val,
                                  safeCursor,
                                );

                                _mentionSourceText = val;
                                setState(() {
                                  if (m != null) {
                                    _mentionStart = m.start;
                                    _mentionEnd = safeCursor;
                                    _mentionQuery = m.query;
                                    _mentionSymbol = m.symbol;
                                  } else {
                                    _mentionQuery = null;
                                    _mentionStart = -1;
                                    _mentionEnd = -1;
                                  }
                                });

                                if (m == null) {
                                  _activePickerSymbol = null;
                                  FloatingMetadataSheet.hide();
                                  return;
                                }

                                final pickerType =
                                    TaskMentionParser.typeForSymbol(m.symbol);
                                if (pickerType == null) return;

                                if (_activePickerSymbol != m.symbol) {
                                  _activePickerSymbol = m.symbol;
                                  FloatingMetadataSheet.show(
                                    context: context,
                                    buttonContext:
                                        _buttonKeys[pickerType]
                                            ?.currentContext ??
                                        textFieldCtx,
                                    type: pickerType,
                                    loadWorkTypes: mapVm.loadWorkTypes,
                                    loadClients: mapVm.loadClients,
                                    loadProjects: mapVm.loadProjects,
                                    loadAssignees: mapVm.loadAssignees,
                                    shouldShow: () =>
                                        _activePickerSymbol == m.symbol,
                                    searchQuery: () => _mentionQuery ?? '',
                                    multiSelect:
                                        pickerType == FloatingSheetType.assign,
                                    closeOnSelect:
                                        pickerType == FloatingSheetType.assign,
                                    selectedValues:
                                        pickerType == FloatingSheetType.assign
                                        ? addVm.selectedAssignees
                                        : null,
                                    focusNodeToKeep: _focusNode,
                                    onSelected: (opt) {
                                      if (pickerType ==
                                          FloatingSheetType.assign) {
                                        addVm.addAssignee(opt);
                                      } else {
                                        unawaited(_completeMention(opt));
                                      }
                                    },
                                    onDone: () {
                                      _activePickerSymbol = null;
                                      if (pickerType ==
                                          FloatingSheetType.assign) {
                                        final token =
                                            TaskMentionParser.removeMentionToken(
                                              text: _taskNameController.text,
                                              start: _mentionStart,
                                              end: _mentionEnd,
                                            );
                                        _taskNameController
                                            .value = TextEditingValue(
                                          text: token.newText,
                                          selection: TextSelection.collapsed(
                                            offset: token.newCursor,
                                          ),
                                        );
                                        setState(() {
                                          _mentionQuery = null;
                                          _mentionStart = -1;
                                          _mentionEnd = -1;
                                        });
                                      }
                                    },
                                  );
                                } else {
                                  FloatingMetadataSheet.update();
                                }
                              },
                              onSubmitted: (_) {
                                if (_mentionQuery != null &&
                                    _mentionQuery!.trim().isNotEmpty) {
                                  unawaited(_selectMentionOnEnter());
                                  return;
                                }
                                onFieldSubmitted();
                                _handleSubmit();
                              },
                            ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Task shortcuts',
                  onPressed: () => showTaskSymbolHelpDialog(context),
                  icon: const Icon(
                    Icons.info_outline,
                    color: TaskConstants.secondaryColor,
                  ),
                ),
                IconButton(
                  onPressed: _handleSubmit,
                  icon: const Icon(
                    Icons.send,
                    color: TaskConstants.secondaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
