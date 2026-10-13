import 'package:flutter/material.dart';

import '../../models/task.dart';

class MyWorkView extends StatefulWidget {
  const MyWorkView({
    super.key,
    required this.sections,
    required this.taskResultsBuilder,
  });

  final Map<String, List<Task>> sections;
  final Widget Function(List<Task> tasks) taskResultsBuilder;

  @override
  State<MyWorkView> createState() => _MyWorkViewState();
}

class _MyWorkViewState extends State<MyWorkView> {
  static const _sectionNames = [
    'Urgent Works',
    'IMP Works',
    'Today Works',
    'Tomorrow Works',
    'Day Later Works',
    'Later Works',
    'Process Works',
    'Hold Works',
    'Done Works',
  ];

  final Set<String> _expandedSections = {};

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
      case 'Done Works':
        return const Color(0xFF708276);
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
      onTap: () {
        if (populatedNames.isEmpty) return;
        setState(() {
          final first = populatedNames.first;
          if (!_expandedSections.add(first)) _expandedSections.remove(first);
        });
      },
      child: SizedBox(height: height, width: double.infinity),
    );

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverList(
          delegate: SliverChildListDelegate(
            populatedNames.isEmpty
                ? const [
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 20, 16, 20),
                      child: Text(
                        'No tasks in My Work.',
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
    );
  }

  Widget _buildSection(String name, List<String> populatedNames) {
    final tasks = widget.sections[name] ?? const <Task>[];
    final isExpanded = _expandedSections.contains(name);
    final color = _sectionColor(name);
    return Column(
      children: [
        InkWell(
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
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
                      fontSize: 11,
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
        if (isExpanded)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: color.withValues(alpha: 0.25)),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              child: widget.taskResultsBuilder(tasks),
            ),
          ),
      ],
    );
  }
}
