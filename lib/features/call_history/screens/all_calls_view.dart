import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/call_log_model.dart';
import '../screens/contacts_view.dart';
import '../utils/date_label_utils.dart';
import '../utils/phone_utils.dart';
import '../viewmodels/call_log_controller.dart';
import '../viewmodels/contact_controller.dart';
import '../widgets/call_log_tile.dart';

class AllCallsView extends StatefulWidget {
  const AllCallsView({super.key});

  @override
  State<AllCallsView> createState() => _AllCallsViewState();
}

class _AllCallsViewState extends State<AllCallsView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _query = '';
  String _dateFilter = 'All time';
  String _analyticsDateFilter = 'Today';
  DateTimeRange? _customAnalyticsRange;
  int _selectedNavigationIndex = 0;
  int _analyticsSectionIndex = 0;
  bool _showAnalyticsGraph = false;
  bool _analyticsGraphByDuration = false;

  static const _filters = <_CallFilter>[
    _CallFilter.all,
    _CallFilter.incoming,
    _CallFilter.outgoing,
    _CallFilter.missed,
    _CallFilter.rejected,
    _CallFilter.neverAttended,
    _CallFilter.notPickedUpByClient,
  ];
  static const _dateFilters = ['All time', 'Today', 'Yesterday', 'Last 7 days'];
  static const _bottomNavigationLabels = [
    'Call History',
    'Analytics',
    'Premium',
    'Contacts',
    'More',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _filters.length, vsync: this);
    _tabController.addListener(_handleTabChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CallLogController>().loadRecent();
    });
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChange)
      ..dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CallLogController>();
    final logs = controller.logs.where((log) {
      final matchesType = _matchesCallFilter(
        _filters[_tabController.index],
        log,
      );
      final matchesDate = _matchesDateFilter(log.time);
      final query = _query.trim().toLowerCase();
      final matchesQuery =
          query.isEmpty ||
          (log.name?.toLowerCase().contains(query) ?? false) ||
          log.number.toLowerCase().contains(query);
      return matchesType && matchesDate && matchesQuery;
    }).toList();
    final groupedLogs = <String, List<CallLogModel>>{};
    for (final log in logs) {
      groupedLogs
          .putIfAbsent(DateLabelUtils.dayLabel(log.time), () => [])
          .add(log);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _selectedNavigationIndex == 3
          ? null
          : AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: Text(
          _selectedNavigationIndex == 1 ? 'Analytics' : 'Call History',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        actions: _selectedNavigationIndex == 1
            ? [
                IconButton(
                  tooltip: 'Copy analytics',
                  onPressed: () => _copyAnalytics(_analyticsLogs(controller)),
                  icon: const Icon(Icons.copy_outlined),
                ),
                IconButton(
                  tooltip: 'Export analytics',
                  onPressed: () => _exportCalls(_analyticsLogs(controller)),
                  icon: const Icon(Icons.insert_drive_file),
                ),
                IconButton(
                  tooltip: 'Share analytics on WhatsApp',
                  onPressed: () =>
                      _shareAnalyticsOnWhatsApp(_analyticsLogs(controller)),
                  icon: const Icon(Icons.chat),
                ),
                const SizedBox(width: 4),
              ]
            : _selectedNavigationIndex == 3
            ? [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.view_list, color: Color(0xFF2F2F2F)),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.grid_view_rounded,
                    color: Color(0xFF2F2F2F),
                  ),
                ),
              ]
            : [
                PopupMenuButton<String>(
                  tooltip: 'Filter by date',
                  initialValue: _dateFilter,
                  onSelected: (value) => setState(() => _dateFilter = value),
                  itemBuilder: (context) => [
                    for (final filter in _dateFilters)
                      PopupMenuItem(value: filter, child: Text(filter)),
                  ],
                  icon: const Icon(Icons.filter_list, color: Color(0xFF43556A)),
                ),
                IconButton(
                  tooltip: 'Export to Excel',
                  onPressed: () => _exportCalls(logs),
                  icon: const Icon(Icons.grid_on, color: Color(0xFF218C57)),
                ),
                const SizedBox(width: 8),
              ],
      ),
      body: _selectedNavigationIndex == 3
          ? ChangeNotifierProvider(
              create: (_) => ContactController()..loadContacts(),
              child: const ContactsView(),
            )
          : _selectedNavigationIndex == 1
          ? _buildAnalytics(controller)
          : Column(
              children: [
                if (controller.permissionDenied)
                  _MissingPermissionsBanner(
                    onFix: controller.openCallLogSettings,
                    onRetry: controller.loadRecent,
                  ),
                SizedBox(
                  height: 76,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicatorColor: const Color(0xFFFFB900),
                    indicatorWeight: 3,
                    labelColor: Colors.black87,
                    unselectedLabelColor: Colors.blueGrey,
                    tabs: [
                      _CallFilterTab(
                        icon: Icons.call,
                        label: 'All Calls',
                        color: _tabController.index == 0
                            ? const Color(0xFF202124)
                            : const Color(0xFF687386),
                      ),
                      const _CallFilterTab(
                        icon: Icons.south_west,
                        label: 'Incoming',
                        color: Color(0xFF218C57),
                      ),
                      const _CallFilterTab(
                        icon: Icons.north_east,
                        label: 'Outgoing',
                        color: Color(0xFFE1A400),
                      ),
                      const _CallFilterTab(
                        icon: Icons.call_missed,
                        label: 'Missed',
                        color: Color(0xFFD64545),
                      ),
                      const _CallFilterTab(
                        icon: Icons.south_east,
                        label: 'Rejected',
                        color: Color(0xFFE17D32),
                      ),
                      const _CallFilterTab(
                        icon: Icons.phone_missed,
                        label: 'Never Attended Calls',
                        color: Color(0xFF8A5AA6),
                      ),
                      const _CallFilterTab(
                        icon: Icons.person_off_outlined,
                        label: 'Not Pickup by Client',
                        color: Color(0xFF536B8A),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'Search',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: controller.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : controller.loadError != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(controller.loadError!),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: controller.loadRecent,
                                child: const Text('Try again'),
                              ),
                            ],
                          ),
                        )
                      : logs.isEmpty
                      ? const Center(child: Text('No calls found'))
                      : ListView(
                          padding: const EdgeInsets.only(bottom: 96),
                          children: [
                            for (final entry in groupedLogs.entries) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  2,
                                ),
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              for (final log in entry.value)
                                CallLogTile(log: log),
                            ],
                          ],
                        ),
                ),
              ],
            ),
      floatingActionButton: (_selectedNavigationIndex == 0 || _selectedNavigationIndex == 3)
          ? FloatingActionButton(
              onPressed: _showDialPad,
              backgroundColor: const Color(0xFFFAB400),
              foregroundColor: Colors.black,
              elevation: 4,
              shape: const CircleBorder(),
              child: const Icon(Icons.dialpad, size: 28),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedNavigationIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: _selectedNavigationIndex == 3
            ? Colors.black
            : const Color(0xFFD39B00),
        unselectedItemColor: const Color(0xFF78808C),
        selectedFontSize: 10,
        unselectedFontSize: 10,
        iconSize: 22,
        onTap: _handleBottomNavigation,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.call),
            label: 'Call History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.workspace_premium_outlined, color: Color(0xFFEAA61A)),
            activeIcon: Icon(Icons.workspace_premium, color: Color(0xFFEAA61A)),
            label: 'Premium',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_ind_outlined),
            activeIcon: Icon(Icons.assignment_ind, color: Colors.black),
            label: 'Contacts',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'More'),
        ],
      ),
    );
  }

  Widget _buildAnalytics(CallLogController controller) {
    final logs = _analyticsLogs(controller);
    final incoming = logs
        .where((log) => log.kind == CallKind.incoming)
        .toList();
    final outgoing = logs
        .where((log) => log.kind == CallKind.outgoing)
        .toList();
    final missed = logs.where((log) => log.kind == CallKind.missed).toList();
    final rejected = logs
        .where((log) => log.kind == CallKind.rejected)
        .toList();
    final neverAttended = [...missed, ...rejected];
    final notPickedUp = outgoing
        .where((log) => log.durationSeconds == 0)
        .toList();

    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(controller.loadError!),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: controller.loadRecent,
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    final cards = _analyticsSectionIndex == 0
        ? <_AnalyticsMetric>[
            _AnalyticsMetric(
              title: 'Total Phone Calls',
              logs: logs,
              icon: Icons.phone_in_talk_outlined,
              color: const Color(0xFFE9B422),
              showDuration: true,
            ),
            _AnalyticsMetric(
              title: 'Incoming Calls',
              logs: incoming,
              icon: Icons.call_received,
              color: const Color(0xFF86C52A),
              showDuration: true,
            ),
            _AnalyticsMetric(
              title: 'Outgoing Calls',
              logs: outgoing,
              icon: Icons.call_made,
              color: const Color(0xFFE5AD22),
              showDuration: true,
            ),
            _AnalyticsMetric(
              title: 'Missed Calls',
              logs: missed,
              icon: Icons.call_missed,
              color: const Color(0xFFE35C64),
            ),
          ]
        : <_AnalyticsMetric>[
            _AnalyticsMetric(
              title: 'Rejected Calls',
              logs: rejected,
              icon: Icons.call_missed_outgoing,
              color: const Color(0xFFE17D32),
            ),
            _AnalyticsMetric(
              title: 'Never Attended Calls',
              logs: neverAttended,
              icon: Icons.phone_missed,
              color: const Color(0xFF8A5AA6),
            ),
            _AnalyticsMetric(
              title: 'Not Pickup by Client',
              logs: notPickedUp,
              icon: Icons.person_off_outlined,
              color: const Color(0xFF536B8A),
            ),
          ];

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (controller.permissionDenied)
          _MissingPermissionsBanner(
            onFix: controller.openCallLogSettings,
            onRetry: controller.loadRecent,
          ),
        _AnalyticsDateRange(
          value: _analyticsDateFilter,
          logs: logs,
          customRange: _customAnalyticsRange,
          onTapRange: _showAnalyticsDurationDialog,
          onCustom: _showAnalyticsDurationDialog,
          onChanged: (value) => setState(() {
            _analyticsDateFilter = value;
            _customAnalyticsRange = null;
          }),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            elevation: 2,
            child: Column(
              children: [
                ListTile(
                  title: const Text(
                    'Graph View',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  trailing: Icon(
                    _showAnalyticsGraph
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                  ),
                  onTap: () => setState(
                    () => _showAnalyticsGraph = !_showAnalyticsGraph,
                  ),
                ),
                if (_showAnalyticsGraph)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: _AnalyticsGraph(
                      logs: logs,
                      byDuration: _analyticsGraphByDuration,
                      onModeChanged: (byDuration) => setState(
                        () => _analyticsGraphByDuration = byDuration,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _AnalyticsSectionButton(
                label: 'Summary',
                selected: _analyticsSectionIndex == 0,
                onTap: () => setState(() => _analyticsSectionIndex = 0),
              ),
              const SizedBox(width: 34),
              _AnalyticsSectionButton(
                label: 'Analysis',
                selected: _analyticsSectionIndex == 1,
                onTap: () => setState(() => _analyticsSectionIndex = 1),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 20) / 2;
              return Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  for (final metric in cards)
                    SizedBox(width: width, child: _AnalyticsMetricCard(metric)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  List<CallLogModel> _analyticsLogs(CallLogController controller) => controller
      .logs
      .where((log) => _matchesAnalyticsDateFilter(log.time))
      .toList();

  bool _matchesAnalyticsDateFilter(DateTime date) {
    final customRange = _customAnalyticsRange;
    if (customRange != null) {
      return !date.isBefore(customRange.start) &&
          !date.isAfter(customRange.end);
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final callDay = DateTime(date.year, date.month, date.day);
    switch (_analyticsDateFilter) {
      case 'Today':
        return callDay == today;


      case 'Yesterday':
        return callDay == today.subtract(const Duration(days: 1));
      case 'Last 7 days':
        return !callDay.isBefore(today.subtract(const Duration(days: 6))) &&
            !callDay.isAfter(today);
      case 'This month':
        return callDay.year == today.year && callDay.month == today.month;
      case 'This year':
        return callDay.year == today.year;
      default:
        return true;
    }
  }

  Future<void> _showAnalyticsDurationDialog() async {
    final now = DateTime.now();
    final selected = await showDialog<DateTimeRange>(
      context: context,
      builder: (context) => _SelectDurationDialog(
        initialRange:
            _customAnalyticsRange ??
            DateTimeRange(
              start: DateTime(now.year, now.month, now.day),
              end: DateTime(now.year, now.month, now.day, 23, 59),
            ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _analyticsDateFilter = 'Custom';
      _customAnalyticsRange = selected;
    });
  }

  void _handleBottomNavigation(int index) {
    if (index == 0 || index == 1 || index == 3) {
      setState(() => _selectedNavigationIndex = index);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_bottomNavigationLabels[index]} is not available yet'),
      ),
    );
  }

  Future<void> _copyAnalytics(List<CallLogModel> logs) async {
    final text = _analyticsSummary(logs);
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Analytics copied')));
    }
  }

  Future<void> _shareAnalyticsOnWhatsApp(List<CallLogModel> logs) async {
    final uri = Uri.https('wa.me', '/', {'text': _analyticsSummary(logs)});
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp')));
    }
  }

  String _analyticsSummary(List<CallLogModel> logs) {
    final incoming = logs.where((log) => log.kind == CallKind.incoming).length;
    final outgoing = logs.where((log) => log.kind == CallKind.outgoing).length;
    final missed = logs.where((log) => log.kind == CallKind.missed).length;
    final duration = logs.fold<int>(
      0,
      (total, log) => total + log.durationSeconds,
    );
    return 'Call Analytics ($_analyticsDateFilter)\n'
        'Total calls: ${logs.length}\nIncoming: $incoming\n'
        'Outgoing: $outgoing\nMissed: $missed\n'
        'Total duration: ${PhoneUtils.formatDuration(duration)}';
  }

  bool _matchesCallFilter(_CallFilter filter, CallLogModel log) {
    switch (filter) {
      case _CallFilter.all:
        return true;
      case _CallFilter.incoming:
        return log.kind == CallKind.incoming;
      case _CallFilter.outgoing:
        return log.kind == CallKind.outgoing;
      case _CallFilter.missed:
        return log.kind == CallKind.missed;
      case _CallFilter.rejected:
        return log.kind == CallKind.rejected;
      case _CallFilter.neverAttended:
        return log.kind == CallKind.missed || log.kind == CallKind.rejected;
      case _CallFilter.notPickedUpByClient:
        return log.kind == CallKind.outgoing && log.durationSeconds == 0;
    }
  }

  bool _matchesDateFilter(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final callDay = DateTime(date.year, date.month, date.day);
    switch (_dateFilter) {
      case 'Today':
        return callDay == today;
      case 'Yesterday':
        return callDay == today.subtract(const Duration(days: 1));
      case 'Last 7 days':
        return !callDay.isBefore(today.subtract(const Duration(days: 6))) &&
            !callDay.isAfter(today);
      default:
        return true;
    }
  }

  Future<void> _exportCalls(List<CallLogModel> logs) async {
    String csvValue(String value) => '"${value.replaceAll('"', '""')}"';

    final rows = <List<String>>[
      ['Name', 'Number', 'Type', 'Date', 'Time', 'Duration (seconds)'],
      for (final log in logs)
        [
          log.name ?? '',
          log.number,
          log.kind.name,
          log.time.toIso8601String().split('T').first,
          DateLabelUtils.timeLabel(log.time),
          log.durationSeconds.toString(),
        ],
    ];
    final csv = rows.map((row) => row.map(csvValue).join(',')).join('\r\n');
    final file = XFile.fromData(
      Uint8List.fromList(utf8.encode(csv)),
      mimeType: 'text/csv',
      name: 'call_history.csv',
    );
    await SharePlus.instance.share(
      ShareParams(
        subject: 'Call History',
        files: [file],
        fileNameOverrides: const ['call_history.csv'],
      ),
    );
  }

  Future<void> _showDialPad() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _DialPadSheet(),
  );
}

enum _CallFilter {
  all,
  incoming,
  outgoing,
  missed,
  rejected,
  neverAttended,
  notPickedUpByClient,
}

class _CallFilterTab extends StatelessWidget {
  const _CallFilterTab({
    required this.icon,
    required this.label,
    this.color = const Color(0xFF687386),
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Tab(
    height: 70,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 4),
        Text(label),
      ],
    ),
  );
}

class _AnalyticsDateRange extends StatelessWidget {
  const _AnalyticsDateRange({
    required this.value,
    required this.logs,
    required this.customRange,
    required this.onTapRange,
    required this.onCustom,
    required this.onChanged,
  });

  final String value;
  final List<CallLogModel> logs;
  final DateTimeRange? customRange;
  final VoidCallback onTapRange;
  final VoidCallback onCustom;
  final ValueChanged<String> onChanged;

  static const _options = [
    'Today',
    'Yesterday',
    'Week',
    'Month',
    'Year',
    'Custom',
    'All Time',
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final selectedOption = switch (value) {
      'Last 7 days' => 'Week',
      'This month' => 'Month',
      'This year' => 'Year',
      'All time' => 'All Time',
      _ => value,
    };
    final start = switch (value) {
      'Yesterday' => now.subtract(const Duration(days: 1)),
      'Last 7 days' => now.subtract(const Duration(days: 6)),
      'This month' => DateTime(now.year, now.month),
      'This year' => DateTime(now.year),
      _ => now,
    };
    final rangeText = customRange != null
        ? '${_dateTimeLabel(customRange!.start)} - '
              '${_dateTimeLabel(customRange!.end)}'
        : value == 'All time'
        ? (logs.isEmpty
              ? 'No calls in selected period'
              : '${_dateLabel(logs.last.time)} - ${_dateLabel(logs.first.time)}')
        : '${_dateLabel(start)} 12:00 AM - ${_dateLabel(now)} 11:59 PM';

    return Container(
      color: const Color(0xFFE9E9E9),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              key: const ValueKey('analytics-date-range'),
              onTap: onTapRange,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  rangeText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              key: const ValueKey('analytics-period-selector'),
              onTap: () => _showOptions(context, selectedOption),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 18,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selectedOption,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 14),
                    const Icon(Icons.keyboard_arrow_down),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _dateLabel(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day.toString().padLeft(2, '0')}-${months[date.month - 1]}';
  }

  static String _dateTimeLabel(DateTime date) =>
      '${_dateLabel(date)} ${_timeLabel(date)}';

  static String _fullDateTimeLabel(DateTime date) =>
      '${_dateLabel(date)}-${date.year} ${_timeLabel(date)}';

  static String _timeLabel(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Future<void> _showOptions(BuildContext context, String selectedOption) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E5E5),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 24),
              for (final option in _options)
                InkWell(
                  onTap: () => Navigator.pop(context, option),
                  child: SizedBox(
                    height: 76,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: option == selectedOption
                              ? const Icon(
                                  Icons.check,
                                  color: Color(0xFFE0AE00),
                                  size: 25,
                                )
                              : null,
                        ),
                        Text(
                          option,
                          style: const TextStyle(
                            fontSize: 21,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected == null) return;
    switch (selected) {
      case 'Custom':
        onCustom();
      case 'Today':
        onChanged('Today');
      case 'Yesterday':
        onChanged('Yesterday');
      case 'Week':
        onChanged('Last 7 days');
      case 'Month':
        onChanged('This month');
      case 'Year':
        onChanged('This year');
      case 'All Time':
        onChanged('All time');
    }
  }
}

class _SelectDurationDialog extends StatefulWidget {
  const _SelectDurationDialog({required this.initialRange});

  final DateTimeRange initialRange;

  @override
  State<_SelectDurationDialog> createState() => _SelectDurationDialogState();
}

class _SelectDurationDialogState extends State<_SelectDurationDialog> {
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    _from = widget.initialRange.start;
    _to = widget.initialRange.end;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Center(
      child: Text(
        'Select Duration',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dateTimePickerField(
          label: 'From Date & Time',
          value: _from,
          onTap: () => _selectDateTime(isStart: true),
        ),
        const SizedBox(height: 22),
        _dateTimePickerField(
          label: 'To Date & Time',
          value: _to,
          onTap: () => _selectDateTime(isStart: false),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () {
          if (_to.isBefore(_from)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('End date/time must be after the start'),
              ),
            );
            return;
          }
          Navigator.pop(context, DateTimeRange(start: _from, end: _to));
        },
        child: const Text('OK'),
      ),
    ],
  );

  Widget _dateTimePickerField({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black87,
          side: const BorderSide(color: Colors.black87),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _AnalyticsDateRange._fullDateTimeLabel(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Future<void> _selectDateTime({required bool isStart}) async {
    final current = isStart ? _from : _to;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;

    setState(() {
      final selected = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (isStart) {
        _from = selected;
      } else {
        _to = selected;
      }
    });
  }
}

class _AnalyticsSectionButton extends StatelessWidget {
  const _AnalyticsSectionButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF242424) : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    ),
  );
}

class _AnalyticsMetric {
  const _AnalyticsMetric({
    required this.title,
    required this.logs,
    required this.icon,
    required this.color,
    this.showDuration = false,
  });

  final String title;
  final List<CallLogModel> logs;
  final IconData icon;
  final Color color;
  final bool showDuration;

  int get totalSeconds =>
      logs.fold(0, (total, log) => total + log.durationSeconds);
}

class _AnalyticsMetricCard extends StatelessWidget {
  const _AnalyticsMetricCard(this.metric);

  final _AnalyticsMetric metric;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 174),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Row(
          children: [
            Icon(metric.icon, size: 31, color: metric.color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                metric.title,
                style: const TextStyle(fontSize: 13, color: Color(0xFF424242)),
              ),
            ),
          ],
        ),
        Row(
          children: [
            const Icon(Icons.call, size: 22),
            const SizedBox(width: 12),
            Text(
              '${metric.logs.length}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        if (metric.showDuration)
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 22),
              const SizedBox(width: 12),
              Text(
                PhoneUtils.formatDuration(metric.totalSeconds),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
      ],
    ),
  );
}

class _AnalyticsGraph extends StatelessWidget {
  const _AnalyticsGraph({
    required this.logs,
    required this.byDuration,
    required this.onModeChanged,
  });

  final List<CallLogModel> logs;
  final bool byDuration;
  final ValueChanged<bool> onModeChanged;

  static const _series = [
    _GraphSeries('Incoming', Color(0xFF93C900)),
    _GraphSeries('Outgoing', Color(0xFFFFA900)),
    _GraphSeries('Missed', Color(0xFFF04D54)),
    _GraphSeries('Rejected', Color(0xFF990E0E)),
  ];
  static const _timeLabels = ['12:00 AM', '06:00 AM', '12:00 PM', '06:00 PM'];

  @override
  Widget build(BuildContext context) {
    final values = List.generate(
      _series.length,
      (seriesIndex) => List.generate(4, (bucketIndex) {
        final matching = logs.where(
          (log) =>
              _series[seriesIndex].matches(log.kind) &&
              log.time.hour ~/ 6 == bucketIndex,
        );
        if (byDuration) {
          return matching.fold<double>(
            0,
            (total, log) => total + log.durationSeconds / 60,
          );
        }
        return matching.length.toDouble();
      }),
    );
    final maximum = values
        .expand((seriesValues) => seriesValues)
        .fold<double>(0, (max, value) => value > max ? value : max);
    final chartMaximum = maximum == 0 ? 1.0 : maximum.ceilToDouble();

    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            for (final series in _series)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: series.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(series.label, style: const TextStyle(fontSize: 12)),
                ],
              ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 230,
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var step = 4; step >= 0; step--)
                      Text(
                        '${(chartMaximum * step / 4).round()}',
                        style: const TextStyle(fontSize: 10),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: CustomPaint(
                  painter: _AnalyticsChartPainter(
                    values: values,
                    maximum: chartMaximum,
                    colors: [for (final series in _series) series.color],
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 26, top: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final label in _timeLabels)
                Text(label, style: const TextStyle(fontSize: 10)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _AnalyticsSectionButton(
              label: 'Phone Call',
              selected: !byDuration,
              onTap: () => onModeChanged(false),
            ),
            const SizedBox(width: 28),
            _AnalyticsSectionButton(
              label: 'Duration',
              selected: byDuration,
              onTap: () => onModeChanged(true),
            ),
          ],
        ),
      ],
    );
  }
}

class _GraphSeries {
  const _GraphSeries(this.label, this.color);

  final String label;
  final Color color;

  bool matches(CallKind kind) => switch (label) {
    'Incoming' => kind == CallKind.incoming,
    'Outgoing' => kind == CallKind.outgoing,
    'Missed' => kind == CallKind.missed,
    'Rejected' => kind == CallKind.rejected,
    _ => false,
  };
}

class _AnalyticsChartPainter extends CustomPainter {
  const _AnalyticsChartPainter({
    required this.values,
    required this.maximum,
    required this.colors,
  });

  final List<List<double>> values;
  final double maximum;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    const divisions = 4;
    final gridPaint = Paint()
      ..color = const Color(0xFFBDBDBD)
      ..strokeWidth = 0.8;
    final barWidth = size.width / (4 * 7);
    final groupWidth = size.width / 4;

    for (var line = 0; line <= divisions; line++) {
      final y = size.height * line / divisions;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (var bucket = 0; bucket < 4; bucket++) {
      for (var series = 0; series < values.length; series++) {
        final value = values[series][bucket];
        if (value == 0) continue;
        final height = (value / maximum * size.height).clamp(0.0, size.height);
        final x =
            groupWidth * bucket + groupWidth * 0.2 + series * (barWidth + 2);
        final rect = Rect.fromLTWH(x, size.height - height, barWidth, height);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          Paint()..color = colors[series],
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AnalyticsChartPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.maximum != maximum ||
      oldDelegate.colors != colors;
}

class _MissingPermissionsBanner extends StatelessWidget {
  const _MissingPermissionsBanner({required this.onFix, required this.onRetry});

  final Future<void> Function() onFix;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF6E5),
      border: Border.all(color: const Color(0xFFF2D7A6)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, color: Color(0xFFE2A52E)),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: TextStyle(color: Colors.blueGrey.shade700, height: 1.4),
              children: [
                const TextSpan(
                  text:
                      'Some required permissions are missing. Please fix this '
                      'for smooth functionality. ',
                ),
                WidgetSpan(
                  child: GestureDetector(
                    onTap: onFix,
                    child: const Text(
                      'FIX NOW',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}

class _DialPadSheet extends StatefulWidget {
  const _DialPadSheet();

  @override
  State<_DialPadSheet> createState() => _DialPadSheetState();
}

class _DialPadSheetState extends State<_DialPadSheet> {
  String _number = '';

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _number.isEmpty ? 'Enter a number' : _number,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['*', '0', '#'],
          ])
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final digit in row)
                  TextButton(
                    onPressed: () => setState(() => _number += digit),
                    child: Text(digit, style: const TextStyle(fontSize: 24)),
                  ),
              ],
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: 'Delete digit',
                onPressed: _number.isEmpty
                    ? null
                    : () => setState(
                        () =>
                            _number = _number.substring(0, _number.length - 1),
                      ),
                icon: const Icon(Icons.backspace_outlined),
              ),
              FilledButton(
                onPressed: _number.isEmpty ? null : _placeCall,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFAB400),
                  foregroundColor: Colors.black,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(16),
                ),
                child: const Icon(Icons.call),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Future<void> _placeCall() async {
    final launched = await launchUrl(
      Uri(scheme: 'tel', path: _number),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the phone app')),
      );
    }
  }
}
