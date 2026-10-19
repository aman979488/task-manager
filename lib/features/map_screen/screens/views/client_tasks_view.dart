import 'package:flutter/material.dart';

import '../../models/task.dart';

class ClientTasksView extends StatefulWidget {
  const ClientTasksView({
    super.key,
    required this.tasks,
    required this.loadClients,
    required this.refreshable,
    required this.onOpenTask,
  });

  final List<Task> tasks;
  final Future<List<String>> Function() loadClients;
  final Widget Function(Widget child) refreshable;
  final ValueChanged<Task> onOpenTask;

  @override
  State<ClientTasksView> createState() => _ClientTasksViewState();
}

class _ClientTasksViewState extends State<ClientTasksView> {
  late Future<List<String>> _clientsFuture;
  final Set<String> _expandedClients = {};

  @override
  void initState() {
    super.initState();
    _clientsFuture = widget.loadClients();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<String>>(
    future: _clientsFuture,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return widget.refreshable(
          ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: 240,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Could not load clients.'),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _clientsFuture = widget.loadClients();
                          });
                        },
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }

      if (!snapshot.hasData) {
        return widget.refreshable(
          ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: 240,
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
        );
      }

      final namesByKey = <String, String>{};
      for (final name in snapshot.data!) {
        final cleanName = name.trim();
        if (cleanName.isNotEmpty) {
          namesByKey.putIfAbsent(cleanName.toLowerCase(), () => cleanName);
        }
      }

      final tasksByClient = <String, List<Task>>{};
      for (final task in widget.tasks) {
        final clientName = task.clientName?.trim() ?? '';
        if (clientName.isEmpty) continue;
        final key = clientName.toLowerCase();
        namesByKey.putIfAbsent(key, () => clientName);
        tasksByClient.putIfAbsent(key, () => []).add(task);
      }

      final clientKeys = namesByKey.keys.toList()
        ..sort(
          (a, b) => namesByKey[a]!.toLowerCase().compareTo(
            namesByKey[b]!.toLowerCase(),
          ),
        );

      if (clientKeys.isEmpty) {
        return widget.refreshable(
          ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: 240,
                child: Center(child: Text('No clients found.')),
              ),
            ],
          ),
        );
      }

      return widget.refreshable(
        ListView.builder(
          key: const PageStorageKey('clients-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 100),
          itemCount: clientKeys.length,
          itemBuilder: (context, index) {
            final key = clientKeys[index];
            final name = namesByKey[key]!;
            final tasks = tasksByClient[key] ?? const <Task>[];
            final expanded = _expandedClients.contains(key);
            final completedCount = tasks.where((task) => task.isDone).length;

            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: ExpansionTile(
                  key: PageStorageKey('client-$key'),
                  initiallyExpanded: expanded,
                  dense: true,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                  childrenPadding: EdgeInsets.zero,
                  onExpansionChanged: (isExpanded) => setState(() {
                    if (isExpanded) {
                      _expandedClients.add(key);
                    } else {
                      _expandedClients.remove(key);
                    }
                  }),
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFFFBE64E)
                        .withValues(alpha: 0.3),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B5800),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    'Total: ${tasks.length} • Pending: ${tasks.length - completedCount} • Done: $completedCount',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                  children: [
                    if (tasks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
                        child: Text('No tasks for this client yet.'),
                      )
                    else
                      _ClientTaskTable(
                        tasks: tasks,
                        onOpenTask: widget.onOpenTask,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

class _ClientTaskTable extends StatelessWidget {
  const _ClientTaskTable({required this.tasks, required this.onOpenTask});

  final List<Task> tasks;
  final ValueChanged<Task> onOpenTask;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      showCheckboxColumn: false,
      horizontalMargin: 8,
      columnSpacing: 12,
      columns: const [
        DataColumn(label: Text('Task')),
        DataColumn(label: Text('Task date')),
        DataColumn(label: Text('Complete date')),
        DataColumn(label: Text('Status')),
      ],
      rows: tasks
          .map(
            (task) => DataRow(
              onSelectChanged: (_) => onOpenTask(task),
              cells: [
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(Text(task.createdDate)),
                DataCell(Text(_completionDate(task.completedAt))),
                DataCell(Text(task.isDone ? 'Done' : 'Pending')),
              ],
            ),
          )
          .toList(),
    ),
  );

  String _completionDate(int? completedAt) {
    if (completedAt == null) return '—';
    final date = DateTime.fromMillisecondsSinceEpoch(completedAt);
    return '${date.day}/${date.month}/${date.year}';
  }
}
