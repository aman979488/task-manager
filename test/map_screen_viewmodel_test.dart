import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/map_screen/models/task.dart';
import 'package:task_manager/features/map_screen/repositories/task_repository.dart';
import 'package:task_manager/features/map_screen/services/task_assignment_notification_service.dart';
import 'package:task_manager/features/map_screen/utils/task_constants.dart';
import 'package:task_manager/features/map_screen/viewmodels/map_screen_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 10, 14, 13);

  test('priority options do not include Urgent', () {
    expect(TaskConstants.priorityOptions, isNot(contains('Urgent')));
  });

  test('Monitor priority appears immediately above Free', () {
    final monitorIndex = TaskConstants.priorityOptions.indexOf('Monitor');
    final freeIndex = TaskConstants.priorityOptions.indexOf('Free');

    expect(monitorIndex, greaterThanOrEqualTo(0));
    expect(freeIndex, monitorIndex + 1);
  });

  test(
    'completing a task updates its state before persistence finishes',
    () async {
      final repository = _TaskRepositoryStub();
      final viewModel = MapScreenViewModel(
        repository: repository,
        assignmentNotificationService: _AssignmentNotificationServiceStub(),
      );
      final task = Task('Assigned task', id: 'task-1');
      var notified = false;
      viewModel.addListener(() => notified = true);

      final save = viewModel.toggleTaskDone(task);

      expect(task.isDone, isTrue);
      expect(task.completedAt, isNotNull);
      expect(notified, isTrue);

      repository.updateCompleter.complete();
      await save;
      viewModel.dispose();
    },
  );

  test(
    'failed completion save restores the pending task and reports error',
    () async {
      final repository = _TaskRepositoryStub();
      final viewModel = MapScreenViewModel(
        repository: repository,
        assignmentNotificationService: _AssignmentNotificationServiceStub(),
      );
      final task = Task('Assigned task', id: 'task-1');

      final save = viewModel.toggleTaskDone(task);
      repository.updateCompleter.completeError(StateError('permission denied'));
      await save;

      expect(task.isDone, isFalse);
      expect(task.completedAt, isNull);
      expect(viewModel.takeErrorMessage(), contains('Could not update'));
      viewModel.dispose();
    },
  );

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

  test('My Day includes tasks prioritized for today, tomorrow, or later', () {
    final today = Task('Today', priority: ' TODAY ');
    final tomorrow = Task('Tomorrow', priority: 'Tomorrow');
    final later = Task('Later', priority: 'Later');
    final dayLater = Task('Day later', priority: 'Day Later');

    expect(
      MapScreenViewModel.myDayTasks([
        today,
        tomorrow,
        later,
        dayLater,
      ], now: now),
      [today, tomorrow, later, dayLater],
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

  test('My Work recognizes a person in a multi-select monitor value', () {
    final selectedMonitor = Task(
      'Selected monitor',
      monitor: 'Aman Yadav, Priya',
    );
    final alternateSeparator = Task(
      'Selected monitor with semicolon',
      monitor: 'Riya; Aman Yadav',
    );
    final similarName = Task('Similar name', monitor: 'Amana');

    expect(
      MapScreenViewModel.myTasksForUser(
        [selectedMonitor, alternateSeparator, similarName],
        userUid: 'user-1',
        userEmail: 'user@example.com',
        userName: 'Aman',
      ),
      [selectedMonitor, alternateSeparator],
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

  test('monitor priority gets its own My Work section and not tomorrow', () {
    final monitorTask = Task('Monitor task', priority: 'Monitor');
    final tomorrowTask = Task('Tomorrow task', priority: 'Tomorrow');

    final sections = MapScreenViewModel.sectionsForWork([
      monitorTask,
      tomorrowTask,
    ]);

    expect(sections['Monitor Works'], [monitorTask]);
    expect(sections['Tomorrow Works'], [tomorrowTask]);
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
      'Monitor Works',
      'Free Works',
    ]);
  });

  test('my work sections order overdue after today and before IMP', () {
    final urgent = Task('Urgent task', priority: 'U1');
    final today = Task('Today task', priority: 'Today');
    final unprioritizedOverdue = Task(
      'Free task',
      deadline: DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String(),
    );
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
      unprioritizedOverdue,
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
      'Monitor Works',
      'Free Works',
    ]);
    expect(sections['Overdue Works'], [overdueImp]);
    expect(sections['IMP Works'], [imp]);
    expect(sections['Free Works'], [unprioritizedOverdue]);
  });

  test(
    'changing priority regroups overdue tasks into the matching section',
    () {
      final overdue = Task(
        'Overdue task',
        priority: 'Later',
        deadline: DateTime.now()
            .subtract(const Duration(days: 1))
            .toIso8601String(),
      );

      var sections = MapScreenViewModel.sectionsForWork([overdue]);
      expect(sections['Overdue Works'], [overdue]);
      expect(sections['Later Works'], isEmpty);

      overdue.priority = 'Monitor';
      sections = MapScreenViewModel.sectionsForWork([overdue]);
      expect(sections['Overdue Works'], isEmpty);
      expect(sections['Monitor Works'], [overdue]);

      overdue.priority = 'Free';
      sections = MapScreenViewModel.sectionsForWork([overdue]);
      expect(sections['Overdue Works'], isEmpty);
      expect(sections['Free Works'], [overdue]);

      overdue.priority = 'Today';
      sections = MapScreenViewModel.sectionsForWork([overdue]);
      expect(sections['Overdue Works'], isEmpty);
      expect(sections['Today Works'], [overdue]);
    },
  );
}

class _TaskRepositoryStub implements TaskRepository {
  final Completer<void> updateCompleter = Completer<void>();

  @override
  Future<void> updateTask(Task task) => updateCompleter.future;

  @override
  Future<void> addTask(Task task) async {}

  @override
  Future<void> deleteTask(Task task) async {}

  @override
  Future<List<Task>> fetchTasks({
    required bool canReadAll,
    required String userUid,
    required String userName,
  }) async => [];

  @override
  Future<List<String>> loadAssignees() async => [];

  @override
  Future<List<String>> loadClients() async => [];

  @override
  Future<List<String>> loadProjects() async => [];

  @override
  Future<List<String>> loadWorkTypes() async => [];

  @override
  Stream<List<Task>> watchTasks({
    required bool canReadAll,
    required String userUid,
    required String userName,
  }) => const Stream.empty();
}

class _AssignmentNotificationServiceStub
    implements TaskAssignmentNotificationService {
  @override
  Future<void> sendAssignmentNotification({
    required String assignee,
    required String taskTitle,
    required String senderName,
    required String senderUid,
    required String senderEmail,
    required bool notificationsEnabled,
  }) async {}
}
