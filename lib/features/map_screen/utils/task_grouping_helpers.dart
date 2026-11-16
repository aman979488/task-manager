import '../models/task.dart';
import 'task_filter_helpers.dart';

class TaskGroupingHelpers {
  const TaskGroupingHelpers._();

  static int priorityOrder(String? priority) {
    final normalized = priority?.trim();
    if (normalized == null || normalized.isEmpty) return 100;

    return switch (normalized.toLowerCase()) {
      'u1' => 1,
      'u2' => 2,
      'u3' => 3,
      'urgent' => 4,
      'monitor' => 5,
      'imp' => 6,
      'today' => 7,
      'tomorrow' => 8,
      'day later' => 9,
      'later' => 10,
      'process' => 11,
      'hold' => 12,
      'free' => 13,
      _ => 100,
    };
  }

  static int compareTasks(Task first, Task second) {
    if (first.isDone != second.isDone) return first.isDone ? 1 : -1;
    if (first.isDone && first.completedAt != second.completedAt) {
      if (first.completedAt == null) return 1;
      if (second.completedAt == null) return -1;
      return second.completedAt!.compareTo(first.completedAt!);
    }
    final firstPriority = priorityOrder(first.priority);
    final secondPriority = priorityOrder(second.priority);
    if (firstPriority != secondPriority) {
      return firstPriority.compareTo(secondPriority);
    }
    return (second.priorityUpdatedAt ?? 0).compareTo(
      first.priorityUpdatedAt ?? 0,
    );
  }

  static int compareDueDates(Task first, Task second) {
    final firstDate = TaskFilterHelpers.scheduledDateTime(first);
    final secondDate = TaskFilterHelpers.scheduledDateTime(second);
    if (firstDate == null) return secondDate == null ? 0 : 1;
    if (secondDate == null) return -1;
    final dateOrder = firstDate.compareTo(secondDate);
    if (dateOrder != 0) return dateOrder;
    return first.title.toLowerCase().compareTo(second.title.toLowerCase());
  }

  static int compareOverdueTasks(Task first, Task second) =>
      compareDueDates(second, first);

  static Map<String, List<Task>> groupTasks(List<Task> tasks, String groupBy) {
    final groups = <String, List<Task>>{};
    for (final task in tasks) {
      final value = switch (groupBy) {
        'Priority' =>
          task.priority?.trim().isNotEmpty == true
              ? task.priority!.trim()
              : 'No priority',
        'Work type' =>
          task.workType?.trim().isNotEmpty == true
              ? task.workType!.trim()
              : 'No work type',
        'Status' => task.isDone ? 'Done' : 'Pending',
        _ =>
          task.assignee?.trim().isNotEmpty == true
              ? task.assignee!.trim()
              : 'Unassigned',
      };
      groups.putIfAbsent(value, () => []).add(task);
    }
    return groups;
  }

  static Map<String, List<Task>> assignedTasksByName(List<Task> tasks) {
    final groups = <String, List<Task>>{};
    for (final task in tasks) {
      final assignee = task.assignee?.trim();
      if (assignee == null || assignee.isEmpty) continue;
      groups.putIfAbsent(assignee, () => []).add(task);
    }
    return groups;
  }

  static Map<String, List<Task>> sectionsForWork(List<Task> myTasks) {
    final now = DateTime.now();
    final pending = myTasks.where((task) => !task.isDone);
    bool isOverdue(Task task) =>
        TaskFilterHelpers.isTaskOverdue(task, now: now);
    final overdueWorks = pending.where(isOverdue).toList();
    List<Task> withPriority(String priority) => pending
        .where(
          (task) =>
              task.priority?.trim().toLowerCase() == priority &&
              !isOverdue(task),
        )
        .toList();
    final urgentWorks = pending
        .where(
          (task) =>
              const {
                'u1',
                'u2',
                'u3',
                'urgent',
              }.contains(task.priority?.trim().toLowerCase()) &&
              !isOverdue(task),
        )
        .toList();
    final freeWorks = pending.where((task) {
      final priority = task.priority?.trim().toLowerCase();
      return (priority == null ||
              priority.isEmpty ||
              priority == 'free' ||
              priority == 'monitor') &&
          !isOverdue(task);
    }).toList();
    final todayWorks = withPriority('today');
    final tomorrowWorks = withPriority('tomorrow')
        .where((task) => !isOverdue(task))
        .toList();
    return {
      'Urgent Works': urgentWorks,
      'Today Works': todayWorks,
      'Overdue Works': overdueWorks,
      'IMP Works': withPriority('imp')
          .where((task) => !isOverdue(task))
          .toList(),
      'Tomorrow Works': tomorrowWorks,
      'Later Works': withPriority('later')
          .where((task) => !isOverdue(task))
          .toList(),
      'Day Later Works': withPriority('day later')
          .where((task) => !isOverdue(task))
          .toList(),
      'Process Works': withPriority('process')
          .where((task) => !isOverdue(task))
          .toList(),
      'Hold Works': withPriority('hold')
          .where((task) => !isOverdue(task))
          .toList(),
      'Free Works': freeWorks,
    };
  }

  static Map<String, List<Task>> myWorkSections(
    List<Task> myTasks, {
    String userUid = '',
    String userEmail = '',
    String userName = '',
  }) {
    final sections = sectionsForWork(myTasks);
    final normalizedUid = userUid.trim().toLowerCase();
    final normalizedEmail = userEmail.trim().toLowerCase();
    final normalizedName = userName.trim().toLowerCase();
    if (normalizedUid.isEmpty &&
        normalizedEmail.isEmpty &&
        normalizedName.isEmpty) {
      return sections;
    }

    final monitoredTasks = myTasks.where((task) {
      if (task.isDone ||
          TaskFilterHelpers.isAssignedToUser(
            task,
            userUid: normalizedUid,
            userEmail: normalizedEmail,
            userName: normalizedName,
          )) {
        return false;
      }
      return TaskFilterHelpers.isMonitoredByUser(
        task,
        userUid: normalizedUid,
        userEmail: normalizedEmail,
        userName: normalizedName,
      );
    }).toList();

    for (final sectionTasks in sections.values) {
      sectionTasks.removeWhere(monitoredTasks.contains);
    }
    sections['Free Works']!.addAll(monitoredTasks);
    return sections;
  }

  static List<Task> filterAndSortTasks({
    required List<Task> source,
    required String query,
    required String sortBy,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final result = source
        .where(
          (task) =>
              normalizedQuery.isEmpty ||
              task.title.toLowerCase().contains(normalizedQuery) ||
              task.note.toLowerCase().contains(normalizedQuery) ||
              (task.assignee ?? '').toLowerCase().contains(normalizedQuery) ||
              (task.workType ?? '').toLowerCase().contains(normalizedQuery) ||
              (task.priority ?? '').toLowerCase().contains(normalizedQuery),
        )
        .toList();

    switch (sortBy) {
      case 'Title':
        result.sort(
          (first, second) =>
              first.title.toLowerCase().compareTo(second.title.toLowerCase()),
        );
      case 'Due date':
        result.sort(compareDueDates);
      case 'Overdue':
        result.sort(compareOverdueTasks);
      case 'Status':
        result.sort(
          (first, second) => first.isDone == second.isDone
              ? first.title.toLowerCase().compareTo(second.title.toLowerCase())
              : (first.isDone ? 1 : -1),
        );
      default:
        result.sort(compareTasks);
    }
    return result;
  }
}
