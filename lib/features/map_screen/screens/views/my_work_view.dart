import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals;

import '../../models/task.dart';

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

class _MyWorkViewState extends State<MyWorkView> {
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
  ];

  List<String> get _sectionNames => widget.sectionNames ?? _defaultSectionNames;

  final Set<String> _expandedSections = {};
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();
  final Map<String, GlobalKey> _sectionHeaderKeys = {};
  List<String> _pinnedSections = const [];
  Timer? _blankTapTimer;
  int _blankTapCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updatePinnedSections);
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

      final sectionIndex = tapCount >= 3 ? 1 : 0;
      if (sectionIndex >= populatedNames.length) return;
      setState(() {
        final section = populatedNames[sectionIndex];
        if (!_expandedSections.add(section)) {
          _expandedSections.remove(section);
        }
      });
    });
  }

  void _updatePinnedSections() {
    final viewport = _viewportKey.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return;

    final pinned = <String>[];
    for (final name in _sectionNames.take(3)) {
      final header = _sectionHeaderKeys[name]?.currentContext
          ?.findRenderObject();
      if (header is! RenderBox || !header.hasSize) continue;

      final top = header.localToGlobal(Offset.zero, ancestor: viewport).dy;
      if (top > pinned.length * _sectionHeaderHeight) break;
      pinned.add(name);
    }

    if (listEquals(_pinnedSections, pinned)) return;
    setState(() => _pinnedSections = pinned);
  }

  Color _sectionColor(String section) {
    switch (section) {
      case 'Urgent Works':
        return const Color(0xFF9B5965);
      case 'IMP Works':
        return const Color(0xFF526D8A);
      case 'Today Works':
      case 'Tomorrow Works':
        return const Color(0xFF557E9B);
      case 'Hold Works':
        return const Color(0xFF99765B);
      default:
        return const Color(0xFF71808D);
    }
  }

  @override
  Widget build(BuildContext context) {
    final populatedNames = _sectionNames
        .where((name) => widget.sections[name]?.isNotEmpty ?? false)
        .toList();
    Widget blankArea({double? height}) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleBlankTap(populatedNames),
      child: SizedBox(height: height, width: double.infinity),
    );

    final stickySectionNames = _sectionNames
        .take(3)
        .where(populatedNames.contains)
        .toList();
    _sectionHeaderKeys.removeWhere(
      (name, _) => !stickySectionNames.contains(name),
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
        KeyedSubtree(
          key: _sectionHeaderKeys.putIfAbsent(name, GlobalKey.new),
          child: _buildSectionHeader(name, populatedNames),
        ),
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
        onTap: () => setState(() {
          if (isExpanded) {
            _expandedSections.remove(name);
          } else {
            _expandedSections.add(name);
          }
        }),
        onDoubleTap: () => setState(() {
          if (_expandedSections.length == populatedNames.length) {
            _expandedSections.clear();
          } else {
            _expandedSections
              ..clear()
              ..addAll(populatedNames);
          }
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                name.replaceFirst(RegExp(r' Works$'), '').toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: 12,
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
                    fontSize: 12,
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
