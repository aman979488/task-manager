import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../call_history/viewmodels/call_log_controller.dart';
import '../../map_screen/models/task.dart';
import '../models/daily_report_model.dart';
import '../services/daily_report_service.dart';

class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key, required this.tasks});

  final List<Task> tasks;

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(context.read<CallLogController>().loadRecent());
      }
    });
  }

  Widget _daySection(DayReport report, int index) {
    return ExpansionTile(
      key: PageStorageKey<String>('daily-report-${report.dateKey}'),
      initiallyExpanded: index == 0,
      maintainState: true,
      title: Text(
        report.displayDate,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        'Calls: ${report.totalCalls}  •  Visits: ${report.totalVisits}'
        '  •  Duration: ${report.formattedDuration}',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        if (report.workTypes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'No completed work for this date.',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          )
        else
          for (final workType in report.workTypes)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(workType.title),
              subtitle: Text('Duration: ${workType.formattedDuration}'),
              trailing: Text(
                'Count: ${workType.count}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CallLogController>();
    final reports = DailyReportService.generateReports(
      tasks: widget.tasks,
      callLogs: controller.logs,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Report')),
      body: controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (controller.permissionDenied)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      'Call log permission was not granted. Calls from '
                      'completed Call tasks are included instead.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  )
                else if (controller.loadError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      'Call history could not be loaded: '
                      '${controller.loadError}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                for (var index = 0; index < reports.length; index++)
                  _daySection(reports[index], index),
              ],
            ),
    );
  }
}
