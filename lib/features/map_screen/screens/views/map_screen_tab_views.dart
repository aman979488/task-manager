import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../viewmodels/auth_viewmodel.dart';
import '../../models/task.dart';
import '../../utils/task_date_formatter.dart';
import '../../utils/task_mention_parser.dart';
import '../../viewmodels/map_screen_viewmodel.dart';
import '../widgets/map_task_list_item.dart';
import 'all_work_view.dart';
import 'calendar_view.dart';
import 'client_tasks_view.dart';
import 'done_tasks_view.dart';
import 'group_by_assignee_view.dart';
import 'group_by_view.dart';
import 'my_day_view.dart';
import 'my_work_task_results_view.dart';
import 'my_work_view.dart';
import 'overdue_tasks_view.dart';
import 'pending_tasks_view.dart';

class MapScreenTabViews extends StatelessWidget {
  const MapScreenTabViews({
    super.key,
    required this.tabController,
    required this.viewModel,
    required this.authViewModel,
    required this.onOpenTask,
    required this.onRefresh,
    required this.onToggleTaskDone,
    required this.onAddSubstep,
    required this.onEditPriority,
  });

  final TabController tabController;
  final MapScreenViewModel viewModel;
  final AuthViewModel authViewModel;
  final void Function(Task task) onOpenTask;
  final Future<void> Function() onRefresh;
  final void Function(Task task, {bool confirmCompletion, bool keepInMyDay})
  onToggleTaskDone;
  final void Function(Task task) onAddSubstep;
  final void Function(BuildContext badgeContext, Task task) onEditPriority;

  Widget _refreshableScrollView(Widget child) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Scrollbar(thumbVisibility: kIsWeb, child: child),
    );
  }

  Widget _buildMapTaskListItem(
    Task task, {
    String? viewType,
    bool dense = false,
    bool showMetadata = false,
    bool hideTaskMetadata = false,
    bool confirmCompletion = false,
    bool tapCompletesTask = false,
    bool keepInMyDay = false,
  }) {
    return MapTaskListItem(
      task: task,
      viewType: viewType ?? viewModel.viewType,
      dense: dense,
      showMetadata: showMetadata && !hideTaskMetadata,
      taskName: task.title,
      description: _taskDescription(
        task,
        hideMetadataMentions: hideTaskMetadata,
      ),
      isSelected: viewModel.isTaskSelected(task),
      onEditPriority: (badgeContext) => onEditPriority(badgeContext, task),
      onToggleDone: () => onToggleTaskDone(
        task,
        confirmCompletion: confirmCompletion,
        keepInMyDay: keepInMyDay,
      ),
      onAddSubtask: () => onAddSubstep(task),
      onToggleSelection: () => viewModel.toggleTaskSelection(task),
      onOpen: () {
        if (viewModel.isSelectionMode) {
          viewModel.toggleTaskSelection(task);
        } else if (tapCompletesTask) {
          onToggleTaskDone(task, keepInMyDay: keepInMyDay);
        } else {
          onOpenTask(task);
        }
      },
    );
  }

  Widget _buildTaskItem(
    Task task,
    int index, {
    bool dense = true,
    bool showMetadata = false,
    bool hideTaskMetadata = false,
    bool confirmCompletion = false,
    bool tapCompletesTask = false,
    bool keepInMyDay = false,
    String? viewType,
  }) {
    final effectiveViewType = viewType ?? viewModel.viewType;
    if (effectiveViewType == 'Detailed list') {
      return Column(
        children: [
          _buildMapTaskListItem(
            task,
            viewType: effectiveViewType,
            dense: dense,
            showMetadata:
                !hideTaskMetadata &&
                (showMetadata || effectiveViewType == 'Detailed list'),
            hideTaskMetadata: hideTaskMetadata,
            confirmCompletion: confirmCompletion,
            tapCompletesTask: tapCompletesTask,
            keepInMyDay: keepInMyDay,
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.only(left: 15, right: 15),
            color: Colors.grey.withAlpha(15),
          ),
        ],
      );
    }
    return _buildMapTaskListItem(
      task,
      viewType: effectiveViewType,
      dense: dense,
      showMetadata:
          !hideTaskMetadata &&
          (showMetadata || effectiveViewType == 'Detailed list'),
      hideTaskMetadata: hideTaskMetadata,
      confirmCompletion: confirmCompletion,
      tapCompletesTask: tapCompletesTask,
      keepInMyDay: keepInMyDay,
    );
  }

  String? _taskDescription(Task task, {bool hideMetadataMentions = false}) {
    final note = task.note.trim();
    if (note.isEmpty) return null;
    if (!hideMetadataMentions) return note;

    final description = TaskMentionParser.removeMetadataMentions(
      text: note,
      assignee: task.assignee,
      clientName: task.clientName,
      workType: task.workType,
    );
    return description.isEmpty ? null : description;
  }

  Widget _buildCalendarView(List<Task> visibleTasks) {
    return CalendarView(
      tasks: visibleTasks,
      selectedDate: viewModel.calendarDate,
      onDateChanged: viewModel.setCalendarDate,
      scheduledDate: (t) =>
          TaskDateFormatter.scheduledDate(t.deadline, t.reminder),
      refreshable: _refreshableScrollView,
      taskBuilder: (task, index) => Column(
        children: [
          _buildMapTaskListItem(
            task,
            viewType: 'Detailed list',
            dense: true,
            showMetadata: true,
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.only(left: 15, right: 15),
            color: Colors.grey.withAlpha(15),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allTasks = viewModel.tasks;
    final myTasks = viewModel.myTasks(authViewModel);
    final myDayTasks = MapScreenViewModel.myDayTasks(myTasks);
    final doneTasks = viewModel.doneTasks();
    final overdueTasks = viewModel.overdueTasks();
    final pendingTasks = viewModel.pendingTasks();

    final visibleAllTasks = viewModel.getVisibleTasks(source: allTasks);
    final visibleMyDayTasks = viewModel.getVisibleTasks(source: myDayTasks);
    final visibleDoneTasks = viewModel.getVisibleTasks(source: doneTasks);
    final visibleOverdueTasks = viewModel.getVisibleTasks(source: overdueTasks);
    final visiblePendingTasks = viewModel.getVisibleTasks(source: pendingTasks);

    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(viewModel.zoom)),
      child: TabBarView(
        controller: tabController,
        children: [
          Builder(
            key: const PageStorageKey('my-day-tab'),
            builder: (_) => MyDayView(
              tasks: visibleMyDayTasks,
              suggestions: viewModel.getVisibleTasks(
                source: myTasks.where((t) => !t.isDone).toList(),
              ),
              taskBuilder: (task, index) => _buildTaskItem(
                task,
                index,
                tapCompletesTask: true,
                keepInMyDay: true,
                viewType:
                    const {
                      'Grid',
                      'List',
                      'Detailed list',
                    }.contains(viewModel.myDayViewType)
                    ? viewModel.myDayViewType
                    : 'Detailed list',
              ),
              calendarViewType: viewModel.myDayViewType,
              selectedDate: viewModel.calendarDate,
              onDateChanged: viewModel.setCalendarDate,
              onTaskTap: (task) => onToggleTaskDone(task, keepInMyDay: true),
              suggestionBuilder: (task, onAdd) => ListTile(
                onTap: () => onOpenTask(task),
                leading: Checkbox(
                  value: task.isDone,
                  onChanged: (_) => onToggleTaskDone(task),
                ),
                title: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                trailing: IconButton(
                  tooltip: 'Add to My Day',
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, color: Color(0xFF526D8A)),
                ),
              ),
              onAddToMyDay: viewModel.addTaskToMyDay,
              onRefresh: onRefresh,
            ),
          ),
          Builder(
            key: const PageStorageKey('my-work-tab'),
            builder: (_) => _refreshableScrollView(
              MyWorkView(
                sections: viewModel.myWorkSections(myTasks),
                taskResultsBuilder: (secTasks) => MyWorkTaskResultsView(
                  tasks: viewModel.getVisibleTasks(source: secTasks),
                  viewType: viewModel.viewType,
                  zoom: viewModel.zoom,
                  selectedDate: viewModel.calendarDate,
                  onDateChanged: viewModel.setCalendarDate,
                  scheduledDate: (t) =>
                      TaskDateFormatter.scheduledDate(t.deadline, t.reminder),
                  taskBuilder: (task, index) => _buildTaskItem(
                    task,
                    index,
                    dense: true,
                    hideTaskMetadata: true,
                    confirmCompletion: true,
                  ),
                  detailedTaskBuilder: (task) => Column(
                    children: [
                      _buildMapTaskListItem(
                        task,
                        viewType: 'Detailed list',
                        dense: true,
                        showMetadata: false,
                        hideTaskMetadata: true,
                        confirmCompletion: true,
                      ),
                      Container(
                        height: 1,
                        margin: const EdgeInsets.only(left: 15, right: 15),
                        color: Colors.grey.withAlpha(15),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Builder(
            key: const PageStorageKey('assign-tab'),
            builder: (assignContext) => GroupByAssigneeView(
              groups: MapScreenViewModel.assignedTasksByName(visibleAllTasks),
              pageStorageId: 'assign-tab',
              refreshable: _refreshableScrollView,
              onOpenAssignee: (name, tasks) => assignContext.push(
                '/assignee-tasks',
                extra: {'assigneeName': name, 'tasks': tasks},
              ),
              onOpenTask: onOpenTask,
            ),
          ),
          Builder(
            key: const PageStorageKey('clients-tab'),
            builder: (_) => ClientTasksView(
              tasks: visibleAllTasks,
              loadClients: viewModel.loadClients,
              refreshable: _refreshableScrollView,
              onOpenTask: onOpenTask,
            ),
          ),
          Builder(
            key: const PageStorageKey('all-work-tab'),
            builder: (_) => AllWorkView(
              tasks: visibleAllTasks,
              viewType: viewModel.viewType,
              zoom: viewModel.zoom,
              taskBuilder: (task, index) =>
                  _buildTaskItem(task, index, dense: true),
              calendarBuilder: _buildCalendarView,
              refreshable: _refreshableScrollView,
            ),
          ),
          Builder(
            key: const PageStorageKey('done-tasks-tab'),
            builder: (_) => DoneTasksView(
              tasks: visibleDoneTasks,
              viewType: viewModel.viewType,
              zoom: viewModel.zoom,
              taskBuilder: (task, index) => _buildTaskItem(task, index),
              calendarBuilder: _buildCalendarView,
              refreshable: _refreshableScrollView,
            ),
          ),
          Builder(
            key: const PageStorageKey('overdue-tasks-tab'),
            builder: (_) => OverdueTasksView(
              tasks: visibleOverdueTasks,
              viewType: viewModel.viewType,
              zoom: viewModel.zoom,
              taskBuilder: (task, index) => _buildTaskItem(task, index),
              calendarBuilder: _buildCalendarView,
              refreshable: _refreshableScrollView,
            ),
          ),
          Builder(
            key: const PageStorageKey('pending-tasks-tab'),
            builder: (_) => PendingTasksView(
              tasks: visiblePendingTasks,
              viewType: viewModel.viewType,
              zoom: viewModel.zoom,
              taskBuilder: (task, index) => _buildTaskItem(task, index),
              calendarBuilder: _buildCalendarView,
              refreshable: _refreshableScrollView,
            ),
          ),
          Builder(
            key: const PageStorageKey('group-by-tab'),
            builder: (groupByContext) {
              final grouped = MapScreenViewModel.groupTasks(
                visibleAllTasks,
                viewModel.groupBy,
              );
              if (viewModel.groupBy == 'Assignee') {
                return GroupByAssigneeView(
                  groups: grouped,
                  pageStorageId: 'group-by-${viewModel.groupBy}-tab',
                  refreshable: _refreshableScrollView,
                  onOpenAssignee: (name, tasks) => groupByContext.push(
                    '/assignee-tasks',
                    extra: {'assigneeName': name, 'tasks': tasks},
                  ),
                  onOpenTask: onOpenTask,
                );
              }
              return GroupByView(
                groups: grouped,
                groupBy: viewModel.groupBy,
                pageStorageId: 'group-by-${viewModel.groupBy}-tab',
                refreshable: _refreshableScrollView,
                onOpenAssignee: (name, tasks) => groupByContext.push(
                  '/assignee-tasks',
                  extra: {'assigneeName': name, 'tasks': tasks},
                ),
                onOpenTask: onOpenTask,
              );
            },
          ),
        ],
      ),
    );
  }
}
