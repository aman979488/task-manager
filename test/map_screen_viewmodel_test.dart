import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/map_screen/models/task.dart';
import 'package:task_manager/features/map_screen/utils/task_constants.dart';
import 'package:task_manager/features/map_screen/viewmodels/map_screen_viewmodel.dart';

void main() {
  final now = DateTime(2026, 10, 14, 13);

  test('priority options do not include Urgent', () {
    expect(TaskConstants.priorityOptions, isNot(contains('Urgent')));
  });

  test('My Day includes today-priority and overdue scheduled tasks', () {
    final todayByPriority = Task('Today priority', priority: ' TODAY ');
    final todayByDeadline = Task(
      'Today deadline',
      deadline: DateTime(2026, 10, 14, 22).toIso8601String(),
    );
    final todayByReminder = Task(
      'Today reminder',
      reminder: DateTime(2026, 10, 14, 9).toIso8601String(),
    );
    final yesterdayDeadline = Task(
      'Yesterday deadline',
      deadline: DateTime(2026, 10, 13, 17).toIso8601String(),
    );

    expect(
      MapScreenViewModel.myDayTasks([
        todayByPriority,
        todayByDeadline,
        todayByReminder,
        yesterdayDeadline,
      ], now: now),
      [todayByPriority, todayByDeadline, todayByReminder, yesterdayDeadline],
    );
  });

  test('My Day excludes completed and future-date tasks', () {
    final completedToday = Task(
      'Completed today',
      isDone: true,
      deadline: DateTime(2026, 10, 14, 12).toIso8601String(),
    );
    final tomorrow = Task(
      'Tomorrow',
      deadline: DateTime(2026, 10, 15, 9).toIso8601String(),
    );
    final malformedDate = Task('Invalid date', reminder: 'not-a-date');

    expect(
      MapScreenViewModel.myDayTasks([
        completedToday,
        tomorrow,
        malformedDate,
      ], now: now),
      isEmpty,
    );
  });

  test('completed tasks added to My Day are hidden from My Day', () {
    final completedTask = Task(
      'Call me',
      isDone: true,
      isInMyDay: true,
      priority: 'IMP',
    );

    expect(MapScreenViewModel.myDayTasks([completedTask], now: now), isEmpty);
    expect(Task.fromMap('call-me', completedTask.toMap()).isInMyDay, isTrue);
  });

  test('My Work includes tasks created by me or assigned to me', () {
    final createdUnassigned = Task(
      'Created unassigned',
      createdBy: {'uid': 'user-1', 'email': 'user@example.com', 'name': 'Me'},
    );
    final createdAssigned = Task(
      'Created assigned',
      assignee: 'Priya',
      createdBy: {'uid': 'user-1', 'email': 'user@example.com', 'name': 'Me'},
    );
    final assignedToMe = Task('Assigned to me', assignee: 'Me');
    final assignedByUidOnly = Task('Assigned by uid', assigneeUid: 'user-1');
    final assignedToSomeoneElse = Task(
      'Assigned to someone else',
      assignee: 'Priya',
    );

    expect(
      MapScreenViewModel.myTasksForUser(
        [
          createdUnassigned,
          createdAssigned,
          assignedToMe,
          assignedByUidOnly,
          assignedToSomeoneElse,
        ],
        userUid: 'user-1',
        userEmail: 'user@example.com',
        userName: 'Me',
      ),
      [createdUnassigned, createdAssigned, assignedToMe, assignedByUidOnly],
    );
  });

  test('Done tasks are ordered by most recently completed', () {
    final olderDone = Task(
      'Older completed',
      isDone: true,
      priority: 'U1',
      completedAt: 100,
    );
    final newestDone = Task(
      'Newest completed',
      isDone: true,
      priority: 'Today',
      completedAt: 200,
    );
    final pending = Task('Pending', priority: 'U1');
    final tasks = [olderDone, newestDone, pending];
    tasks.sort(MapScreenViewModel.compareTasks);

    expect(tasks, [pending, newestDone, olderDone]);
  });

  test('grouping uses trimmed values and meaningful fallbacks', () {
    final urgent = Task('Urgent', priority: '  U1  ');
    final missingPriority = Task('No priority');
    final unassigned = Task('Unassigned');
    final assigned = Task('Assigned', assignee: '  Aman ');

    expect(
      MapScreenViewModel.groupTasks([urgent, missingPriority], 'Priority'),
      {
        'U1': [urgent],
        'No priority': [missingPriority],
      },
    );
    expect(MapScreenViewModel.groupTasks([unassigned, assigned], 'Assignee'), {
      'Unassigned': [unassigned],
      'Aman': [assigned],
    });
  });

  test(
    'assigned tasks are grouped by name and unassigned tasks are skipped',
    () {
      final amanTask1 = Task('Aman task 1', assignee: ' Aman ');
      final amanTask2 = Task('Aman task 2', assignee: 'Aman');
      final otherTask = Task('Other task', assignee: 'Riya');
      final unassignedTask = Task('Unassigned task');

      expect(
        MapScreenViewModel.assignedTasksByName([
          amanTask1,
          amanTask2,
          otherTask,
          unassignedTask,
        ]),
        {
          'Aman': [amanTask1, amanTask2],
          'Riya': [otherTask],
        },
      );
    },
  );

  test('assignee work sections group pending tasks by priority', () {
    final urgent = Task('Urgent task', priority: 'Urgent', assignee: 'Aman');
    final tomorrow = Task(
      'Tomorrow task',
      priority: 'Tomorrow',
      assignee: 'Aman',
    );
    final completed = Task(
      'Completed urgent',
      priority: 'Urgent',
      assignee: 'Aman',
      isDone: true,
    );

    final sections = MapScreenViewModel.sectionsForWork([
      urgent,
      tomorrow,
      completed,
    ]);

    expect(sections['Urgent Works'], [urgent]);
    expect(sections['Tomorrow Works'], [tomorrow]);
    expect(
      sections.values.expand((tasks) => tasks),
      isNot(contains(completed)),
    );
  });

  test('assignee work sections group pending tasks by priority', () {
    final urgent = Task('Urgent task', priority: 'Urgent', assignee: 'Aman');
    final tomorrow = Task(
      'Tomorrow task',
      priority: 'Tomorrow',
      assignee: 'Aman',
    );
    final completed = Task(
      'Completed urgent',
      priority: 'Urgent',
      assignee: 'Aman',
      isDone: true,
    );

    final sections = MapScreenViewModel.sectionsForWork([
      urgent,
      tomorrow,
      completed,
    ]);

    expect(sections['Urgent Works'], [urgent]);
    expect(sections['Tomorrow Works'], [tomorrow]);
    expect(
      sections.values.expand((tasks) => tasks),
      isNot(contains(completed)),
    );
  });

  test('my work sections order overdue after today and before IMP', () {
    final urgent = Task('Urgent task', priority: 'U1');
    final today = Task('Today task', priority: 'Today');
    final overdueImp = Task(
      'Overdue IMP task',
      priority: 'IMP',
      deadline: DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String(),
    );
    final imp = Task('IMP task', priority: 'IMP');
    final tomorrow = Task('Tomorrow task', priority: 'Tomorrow');
    final later = Task('Later task', priority: 'Later');
    final dayLater = Task('Day later task', priority: 'Day Later');

    final sections = MapScreenViewModel.sectionsForWork([
      urgent,
      today,
      overdueImp,
      imp,
      tomorrow,
      later,
      dayLater,
    ]);

    expect(sections.keys.toList(), [
      'Urgent Works',
      'Today Works',
      'Overdue Works',
      'IMP Works',
      'Tomorrow Works',
      'Later Works',
      'Day Later Works',
      'Process Works',
      'Hold Works',
    ]);
    expect(sections['Overdue Works'], [overdueImp]);
    expect(sections['IMP Works'], [imp]);
  });
}
