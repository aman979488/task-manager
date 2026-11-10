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
    List<Task> withPriority(String priority) => pending
        .where((task) => task.priority?.trim().toLowerCase() == priority)
        .toList();
    final urgentWorks = pending
        .where(
          (task) => const {
            'u1',
            'u2',
            'u3',
            'urgent',
          }.contains(task.priority?.trim().toLowerCase()),
        )
        .toList();
    final freeWorks = pending.where((task) {
      final priority = task.priority?.trim().toLowerCase();
      return priority == null ||
          priority.isEmpty ||
          priority == 'free' ||
          priority == 'monitor';
    }).toList();
    final todayWorks = withPriority('today');
    final overdueWorks = pending.where((task) {
      final priority = task.priority?.trim().toLowerCase();
      if (priority == null ||
          priority.isEmpty ||
          priority == 'free' ||
          priority == 'monitor') {
        return false;
      }
      return TaskFilterHelpers.isTaskOverdue(task, now: now) &&
          !urgentWorks.contains(task) &&
          !todayWorks.contains(task);
    }).toList();
    bool isOverdue(Task task) => overdueWorks.contains(task);
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
      final assignedToSomeoneElse = (task.assignee ?? '').trim().isNotEmpty;
      return TaskFilterHelpers.isMonitoredByUser(
            task,
            userUid: normalizedUid,
            userEmail: normalizedEmail,
            userName: normalizedName,
          ) ||
          (assignedToSomeoneElse &&
              TaskFilterHelpers.isCreatedByUser(
                task,
                userUid: normalizedUid,
                userEmail: normalizedEmail,
                userName: normalizedName,
              ));
    }).toList();

    for (final sectionTasks in sections.values) {
      sectionTasks.removeWhere(monitoredTasks.contains);
    }
    sections['Monitor Works'] = monitoredTasks;
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

    int compareDates(String? first, String? second) {
      final firstDate = DateTime.tryParse(first ?? '');
      final secondDate = DateTime.tryParse(second ?? '');
      if (firstDate == null) return secondDate == null ? 0 : 1;
      if (secondDate == null) return -1;
      return firstDate.compareTo(secondDate);
    }

    switch (sortBy) {
      case 'Title':
        result.sort(
          (first, second) =>
              first.title.toLowerCase().compareTo(second.title.toLowerCase()),
        );
      case 'Due date':
        result.sort(
          (first, second) => compareDates(
            first.deadline ?? first.reminder,
            second.deadline ?? second.reminder,
          ),
        );
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
