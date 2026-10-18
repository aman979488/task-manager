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
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 100),
          itemCount: clientKeys.length,
          itemBuilder: (context, index) {
            final key = clientKeys[index];
            final name = namesByKey[key]!;
            final tasks = tasksByClient[key] ?? const <Task>[];
            final expanded = _expandedClients.contains(key);
            const sectionColor = Color(0xFF71808D);

            return Column(
              children: [
                SizedBox(
                  height: 48,
                  child: InkWell(
                    key: PageStorageKey('client-$key'),
                    onTap: () => setState(() {
                      if (expanded) {
                        _expandedClients.remove(key);
                      } else {
                        _expandedClients.add(key);
                      }
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              name.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: sectionColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
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
                              color: sectionColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${tasks.length}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: sectionColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            expanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: sectionColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (expanded)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: sectionColor.withValues(alpha: 0.25),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: tasks.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'No tasks for this client yet.',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              )
                            : _ClientTaskTable(
                                tasks: tasks,
                                onOpenTask: widget.onOpenTask,
                              ),
                      ),
                    ),
                  ),
              ],
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
