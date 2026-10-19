import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/map_screen/models/task.dart';
import 'package:task_manager/features/map_screen/utils/task_constants.dart';
import 'package:task_manager/features/map_screen/viewmodels/map_screen_viewmodel.dart';

void main() {
  final now = DateTime(2026, 10, 14, 13);

  test('priority options do not include Urgent', () {
    expect(TaskConstants.priorityOptions, isNot(contains('Urgent')));
  });

  test('My Day includes today-priority and tasks scheduled today', () {
    final todayByPriority = Task('Today priority', priority: ' TODAY ');
    final todayByDeadline = Task(
      'Today deadline',
      deadline: DateTime(2026, 10, 14, 22).toIso8601String(),
    );
    final todayByReminder = Task(
      'Today reminder',
      reminder: DateTime(2026, 10, 14, 9).toIso8601String(),
    );

    expect(
      MapScreenViewModel.myDayTasks([
        todayByPriority,
        todayByDeadline,
        todayByReminder,
      ], now: now),
      [todayByPriority, todayByDeadline, todayByReminder],
    );
  });

  test('My Day excludes completed and other-day tasks', () {
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

  test('My Work includes only my unassigned created tasks', () {
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

    expect(
      MapScreenViewModel.myTasksForUser(
        [createdUnassigned, createdAssigned, assignedToMe, assignedByUidOnly],
        userUid: 'user-1',
        userEmail: 'user@example.com',
        userName: 'Me',
      ),
      [createdUnassigned],
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
}
