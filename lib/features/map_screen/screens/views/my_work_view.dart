import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/task.dart';
import '../../utils/task_priority_color.dart';

class MyWorkView extends StatefulWidget {
  const MyWorkView({
    super.key,
    required this.sections,
    required this.taskResultsBuilder,
    this.sectionNames,
    this.emptyMessage = 'No tasks in My Work.',
  });

  final Map<String, List<Task>> sections;
  final Widget Function(List<Task> tasks) taskResultsBuilder;
  final List<String>? sectionNames;
  final String emptyMessage;

  @override
  State<MyWorkView> createState() => _MyWorkViewState();
}

class _MyWorkViewState extends State<MyWorkView>
    with AutomaticKeepAliveClientMixin<MyWorkView> {
  static const _expandedSectionsPreferenceKey = 'my_work_expanded_sections';
  static const double _sectionHeaderHeight = 48;
  static const _defaultSectionNames = [
    'Urgent Works',
    'Today Works',
    'Overdue Works',
    'IMP Works',
    'Tomorrow Works',
    'Later Works',
    'Day Later Works',
    'Process Works',
    'Hold Works',
    'Monitor Works',
    'Free Works',
  ];

  List<String> get _sectionNames => widget.sectionNames ?? _defaultSectionNames;

  final Set<String> _expandedSections = {};
  bool _restoredExpandedSections = false;
  bool _hasChangedExpandedSections = false;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();
  final Map<String, GlobalKey> _sectionHeaderKeys = {};
  final Map<String, double> _sectionHeaderOffsets = {};
  List<String> _pinnedSections = const [];
  Timer? _blankTapTimer;
  int _blankTapCount = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updatePinnedSections);
    _restoreExpandedSections();
  }

  Future<void> _restoreExpandedSections() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getStringList(_expandedSectionsPreferenceKey);
    if (!mounted || _hasChangedExpandedSections || saved == null) return;

    setState(() {
      _expandedSections
        ..clear()
        ..addAll(saved.where(_sectionNames.contains));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restoredExpandedSections) return;
    _restoredExpandedSections = true;
    final saved = PageStorage.maybeOf(context)?.readState(
      context,
      identifier: const ValueKey('my-work-expanded-sections'),
    );
    if (saved is List) {
      _expandedSections.addAll(saved.whereType<String>());
    }
  }

  Future<void> _saveExpandedSections() async {
    PageStorage.maybeOf(context)?.writeState(
      context,
      _expandedSections.toList(),
      identifier: const ValueKey('my-work-expanded-sections'),
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _expandedSectionsPreferenceKey,
      _expandedSections.toList(),
    );
  }

  @override
  void dispose() {
    _blankTapTimer?.cancel();
    _scrollController
      ..removeListener(_updatePinnedSections)
      ..dispose();
    super.dispose();
  }

  void _handleBlankTap(List<String> populatedNames) {
    _blankTapCount++;
    _blankTapTimer?.cancel();
    _blankTapTimer = Timer(const Duration(milliseconds: 350), () {
      final tapCount = _blankTapCount;
      _blankTapCount = 0;
      if (!mounted || populatedNames.isEmpty || tapCount < 2) return;

      final sectionNames = tapCount >= 3
          ? populatedNames.take(2).toList()
          : populatedNames.take(1).toList();
      if (sectionNames.isEmpty) return;
      setState(() {
        _hasChangedExpandedSections = true;
        final allExpanded = sectionNames.every(_expandedSections.contains);
        if (allExpanded) {
          _expandedSections.removeAll(sectionNames);
        } else {
          _expandedSections.addAll(sectionNames);
        }
      });
      unawaited(_saveExpandedSections());
    });
  }

  void _updatePinnedSections() {
    if (!_scrollController.hasClients) return;
    final viewport = _viewportKey.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return;

    final firstThreeSections = _sectionNames
        .where((name) => widget.sections[name]?.isNotEmpty ?? false)
        .take(3)
        .toList();
    final scrollOffset = _scrollController.offset;
    for (final name in firstThreeSections) {
      final header = _sectionHeaderKeys[name]?.currentContext
          ?.findRenderObject();
      if (header is RenderBox && header.hasSize) {
        _sectionHeaderOffsets[name] =
            header.localToGlobal(Offset.zero, ancestor: viewport).dy +
            scrollOffset;
      }
    }

    final pinned = <String>[];
    for (var index = 0; index < firstThreeSections.length; index++) {
      final name = firstThreeSections[index];
      final headerOffset = _sectionHeaderOffsets[name];
      if (headerOffset == null ||
          headerOffset - scrollOffset > pinned.length * _sectionHeaderHeight) {
        break;
      }
      pinned.add(name);
    }

    if (listEquals(_pinnedSections, pinned)) return;
    setState(() => _pinnedSections = pinned);
  }

  Color _sectionColor(String section) {
    switch (section) {
      case 'Completed Tasks':
        return Colors.green.shade700;
      case 'Urgent Works':
        return const Color(0xFF526D8A);
      case 'IMP Works':
        return taskPriorityColor('IMP');
      case 'Today Works':
        return taskPriorityColor('Today');
      case 'Overdue Works':
        return const Color(0xFFC65353);
      case 'Tomorrow Works':
        return const Color(0xFF557E9B);
      case 'Hold Works':
        return const Color(0xFF99765B);
      case 'Monitor Works':
        return const Color(0xFF526D8A);
      default:
        return const Color(0xFF71808D);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final populatedNames = _sectionNames
        .where((name) => widget.sections[name]?.isNotEmpty ?? false)
        .toList();
    final stickySectionNames = populatedNames.take(3).toSet();
    _sectionHeaderKeys.removeWhere(
      (name, _) => !stickySectionNames.contains(name),
    );
    _sectionHeaderOffsets.removeWhere(
      (name, _) => !stickySectionNames.contains(name),
    );
    for (final name in stickySectionNames) {
      _sectionHeaderKeys.putIfAbsent(name, GlobalKey.new);
    }
    Widget blankArea({double? height}) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleBlankTap(populatedNames),
      child: SizedBox(height: height, width: double.infinity),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updatePinnedSections();
    });

    return Stack(
      children: [
        CustomScrollView(
          key: _viewportKey,
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverList(
              delegate: SliverChildListDelegate(
                populatedNames.isEmpty
                    ? [
                        Padding(
                          padding: EdgeInsets.fromLTRB(16, 20, 16, 20),
                          child: Text(
                            widget.emptyMessage,
                            style: TextStyle(color: Colors.blueGrey),
                          ),
                        ),
                      ]
                    : [
                        for (final name in populatedNames)
                          _buildSection(name, populatedNames),
                      ],
                addAutomaticKeepAlives: false,
              ),
            ),
            if (populatedNames.isNotEmpty)
              SliverToBoxAdapter(child: blankArea(height: 100)),
            if (populatedNames.isNotEmpty)
              SliverFillRemaining(hasScrollBody: false, child: blankArea()),
          ],
        ),
        if (_pinnedSections.isNotEmpty)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final name in _pinnedSections)
                    _buildSectionHeader(name, populatedNames),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSection(String name, List<String> populatedNames) {
    final tasks = widget.sections[name] ?? const <Task>[];
    final isExpanded = _expandedSections.contains(name);
    return Column(
      children: [
        if (_sectionHeaderKeys.containsKey(name))
          KeyedSubtree(
            key: _sectionHeaderKeys[name],
            child: _buildSectionHeader(name, populatedNames),
          )
        else
          _buildSectionHeader(name, populatedNames),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: widget.taskResultsBuilder(tasks),
          ),
      ],
    );
  }

  Widget _buildSectionHeader(String name, List<String> populatedNames) {
    final tasks = widget.sections[name] ?? const <Task>[];
    final isExpanded = _expandedSections.contains(name);
    final color = _sectionColor(name);

    return SizedBox(
      height: _sectionHeaderHeight,
      child: InkWell(
        onTap: () {
          setState(() {
            _hasChangedExpandedSections = true;
            if (name == 'Urgent Works') {
              _expandedSections.add(name);
            } else if (isExpanded) {
              _expandedSections.remove(name);
            } else {
              _expandedSections.add(name);
            }
          });
          unawaited(_saveExpandedSections());
          if (name == 'Urgent Works') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || !_scrollController.hasClients) return;
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
              );
            });
          }
        },
        onDoubleTap: () {
          setState(() {
            _hasChangedExpandedSections = true;
            if (_expandedSections.length == populatedNames.length) {
              _expandedSections.clear();
            } else {
              _expandedSections
                ..clear()
                ..addAll(populatedNames);
            }
          });
          unawaited(_saveExpandedSections());
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                name.replaceFirst(RegExp(r' Works$'), '').toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(minWidth: 28),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${tasks.length}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
