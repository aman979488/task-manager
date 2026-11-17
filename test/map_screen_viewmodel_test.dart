import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/utils/role_permissions.dart';
import 'package:task_manager/viewmodels/auth_viewmodel.dart';
import 'package:task_manager/features/map_screen/models/task.dart';
import 'package:task_manager/features/map_screen/repositories/task_repository.dart';
import 'package:task_manager/features/map_screen/services/task_assignment_notification_service.dart';
import 'package:task_manager/features/map_screen/utils/task_constants.dart';
import 'package:task_manager/features/map_screen/viewmodels/map_screen_viewmodel.dart';
import 'package:task_manager/services/network_status_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 10, 14, 13);

  test('priority options do not include Urgent', () {
    expect(TaskConstants.priorityOptions, isNot(contains('Urgent')));
  });

  test('Monitor is not a task priority option', () {
    expect(TaskConstants.priorityOptions, isNot(contains('Monitor')));
  });

  test('metadata options are sorted by usage with stable ties', () async {
    final repository = _TaskRepositoryStub()
      ..tasksToFetch = [
        Task(
          'First',
          assignee: 'Ravi, Amit',
          clientName: 'Acme',
          workType: 'Design',
          refProject: 'Alpha',
          createdBy: {'uid': 'user-1'},
        ),
        Task(
          'Second',
          assignee: 'ravi',
          clientName: 'Acme',
          workType: 'design',
          refProject: 'Beta',
          createdBy: {'uid': 'user-1'},
        ),
        Task(
          'Third',
          assignee: 'Nina',
          clientName: 'Zeta',
          workType: 'Support',
          refProject: 'Beta',
          createdBy: {'uid': 'user-1'},
        ),
      ]
      ..assigneeOptions = ['Amit', 'Nina', 'Ravi', 'Zoya']
      ..clientOptions = ['Acme', 'Beta', 'Zeta', 'Zulu']
      ..workTypeOptions = ['Design', 'QA', 'Support']
      ..projectOptions = ['Alpha', 'Beta', 'Gamma'];
    final viewModel = MapScreenViewModel(
      repository: repository,
      assignmentNotificationService: _AssignmentNotificationServiceStub(),
    );

    await viewModel.refreshTasks(_AuthViewModelStub());

    expect(await viewModel.loadAssignees(), ['Ravi', 'Amit', 'Nina', 'Zoya']);
    expect(await viewModel.loadClients(), ['Acme', 'Zeta', 'Beta', 'Zulu']);
    expect(await viewModel.loadWorkTypes(), ['Design', 'Support', 'QA']);
    expect(await viewModel.loadProjects(), ['Beta', 'Alpha', 'Gamma']);
    viewModel.dispose();
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
      final completionDate = DateTime.fromMillisecondsSinceEpoch(
        task.completedAt!,
      );
      final today = DateTime.now();
      expect(
        DateTime(completionDate.year, completionDate.month, completionDate.day),
        DateTime(today.year, today.month, today.day),
      );
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

  test(
    'undoing a task records the user and makes it visible in My Work',
    () async {
      final repository = _TaskRepositoryStub();
      final viewModel = MapScreenViewModel(
        repository: repository,
        assignmentNotificationService: _AssignmentNotificationServiceStub(),
      );
      final task = Task(
        'Someone else task',
        id: 'task-1',
        isDone: true,
        assignee: 'Someone else',
      );

      final undo = viewModel.toggleTaskDone(task, actorUid: 'user-1');
      expect(task.isDone, isFalse);
      expect(task.lastUndoneByUid, 'user-1');
      expect(
        MapScreenViewModel.myTasksForUser(
          [task],
          userUid: 'user-1',
          userEmail: 'user@example.com',
          userName: 'Me',
        ),
        contains(task),
      );
      expect(Task.fromMap('task-1', task.toMap()).lastUndoneByUid, 'user-1');

      repository.updateCompleter.complete();
      await undo;
      viewModel.dispose();
    },
  );

  test(
    'changing a task priority updates it before persistence finishes',
    () async {
      final repository = _TaskRepositoryStub();
      final viewModel = MapScreenViewModel(
        repository: repository,
        assignmentNotificationService: _AssignmentNotificationServiceStub(),
      );
      final task = Task(
        'Overdue task',
        priority: 'U1',
        deadline: DateTime.now()
            .subtract(const Duration(days: 1))
            .toIso8601String(),
        createdBy: {'uid': 'user-1'},
      );
      repository.tasksToFetch = [task];
      await viewModel.refreshTasks(_AuthViewModelStub());
      var notified = false;
      viewModel.addListener(() => notified = true);

      final save = viewModel.updateTaskPriority(
        task,
        'IMP',
        updatedByUid: 'user-1',
      );

      expect(task.priority, 'IMP');
      expect(task.priorityUpdatedAt, isNotNull);
      expect(task.priorityUpdatedByUid, 'user-1');
      expect(task.overdueAcknowledgedAt, isNull);
      expect(viewModel.overdueTasks(), [task]);
      expect(viewModel.myWorkSections([task])['Overdue Works'], [task]);
      expect(notified, isTrue);

      repository.updateCompleter.complete();
      await save;
      final restored = Task.fromMap('overdue-task', task.toMap());
      expect(restored.priorityUpdatedByUid, 'user-1');
      expect(restored.overdueAcknowledgedAt, task.overdueAcknowledgedAt);
      viewModel.dispose();
    },
  );

  test(
    'changing to a date priority preserves an existing task reminder',
    () async {
      final repository = _TaskRepositoryStub();
      final viewModel = MapScreenViewModel(
        repository: repository,
        assignmentNotificationService: _AssignmentNotificationServiceStub(),
      );
      const selectedReminder = '2026-11-06T14:30:00.000';
      final task = Task('Scheduled task', reminder: selectedReminder);

      final save = viewModel.updateTaskPriority(
        task,
        'Tomorrow',
        updatedByUid: 'user-1',
      );

      expect(task.reminder, selectedReminder);
      repository.updateCompleter.complete();
      await save;
      viewModel.dispose();
    },
  );

  test(
    'failed priority save restores the previous priority and reports error',
    () async {
      final repository = _TaskRepositoryStub();
      final viewModel = MapScreenViewModel(
        repository: repository,
        assignmentNotificationService: _AssignmentNotificationServiceStub(),
      );
      final previousTimestamp = now.millisecondsSinceEpoch;
      final task = Task(
        'Overdue task',
        priority: 'U1',
        priorityUpdatedAt: previousTimestamp,
        priorityUpdatedByUid: 'original-user',
        overdueAcknowledgedAt: previousTimestamp,
      );

      final save = viewModel.updateTaskPriority(
        task,
        'IMP',
        updatedByUid: 'user-1',
      );
      repository.updateCompleter.completeError(StateError('permission denied'));
      await save;

      expect(task.priority, 'U1');
      expect(task.priorityUpdatedAt, previousTimestamp);
      expect(task.priorityUpdatedByUid, 'original-user');
      expect(task.overdueAcknowledgedAt, previousTimestamp);
      expect(
        viewModel.takeErrorMessage(),
        contains('Could not update priority'),
      );
      viewModel.dispose();
    },
  );

  test('reprioritized overdue tasks remain Overdue for every priority', () {
    final acknowledgedAt = DateTime.now().millisecondsSinceEpoch;
    for (final priority in TaskConstants.priorityOptions) {
      final task = Task(
        'Overdue task',
        priority: priority,
        deadline: DateTime.now()
            .subtract(const Duration(days: 1))
            .toIso8601String(),
        overdueAcknowledgedAt: acknowledgedAt,
      );

      expect(MapScreenViewModel.isTaskOverdue(task), isTrue, reason: priority);
      final sections = MapScreenViewModel.sectionsForWork([task]);
      expect(sections['Overdue Works'], [task], reason: priority);
      expect(
        sections.values.expand((tasks) => tasks),
        contains(task),
        reason: priority,
      );
    }
  });

  test('Today task with a passed time moves to Overdue when unfinished', () {
    final dueTime = DateTime.now().subtract(const Duration(minutes: 2));
    final hour = dueTime.hour % 12 == 0 ? 12 : dueTime.hour % 12;
    final endTime =
        '${hour.toString().padLeft(2, '0')}:'
        '${dueTime.minute.toString().padLeft(2, '0')} '
        '${dueTime.hour >= 12 ? 'PM' : 'AM'}';
    final task = Task(
      'Hello',
      priority: 'Today',
      endTime: endTime,
      priorityUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      overdueAcknowledgedAt: DateTime.now().millisecondsSinceEpoch,
    );

    expect(MapScreenViewModel.isTaskOverdue(task), isTrue);
    final sections = MapScreenViewModel.sectionsForWork([task]);
    expect(sections['Overdue Works'], [task]);
    expect(sections['Today Works'], isEmpty);
  });

  testWidgets('overdue status refreshes locally each minute', (tester) async {
    final viewModel = MapScreenViewModel(
      repository: _TaskRepositoryStub(),
      assignmentNotificationService: _AssignmentNotificationServiceStub(),
    );
    var notified = false;
    viewModel.addListener(() => notified = true);
    viewModel.listenForTasks(_AuthViewModelStub());
    notified = false;

    await tester.pump(const Duration(minutes: 1));

    expect(notified, isTrue);
    viewModel.dispose();
  });

  test('newly overdue tasks appear above older overdue tasks', () async {
    final now = DateTime.now();
    final oldest = Task(
      'Oldest due',
      priority: 'U1',
      deadline: now.subtract(const Duration(hours: 4)).toIso8601String(),
      createdBy: {'uid': 'user-1'},
    );
    final middle = Task(
      'Middle due',
      deadline: now.subtract(const Duration(hours: 2)).toIso8601String(),
      createdBy: {'uid': 'user-1'},
    );
    final newest = Task(
      'Newest due',
      priority: 'Today',
      deadline: now.subtract(const Duration(hours: 1)).toIso8601String(),
      createdBy: {'uid': 'user-1'},
    );
    final repository = _TaskRepositoryStub()
      ..tasksToFetch = [newest, oldest, middle];
    final viewModel = MapScreenViewModel(
      repository: repository,
      assignmentNotificationService: _AssignmentNotificationServiceStub(),
    );
    await viewModel.refreshTasks(_AuthViewModelStub());
    viewModel.setSortBy('Title');

    expect(viewModel.overdueTasks(), [newest, middle, oldest]);
    expect(
      viewModel.getVisibleTasks(
        source: viewModel.overdueTasks(),
        sortBy: 'Overdue',
      ),
      [newest, middle, oldest],
    );
    viewModel.dispose();
  });

  test(
    'map overdue tasks read Firestore deadline and reminder timestamps',
    () async {
      final pastDate = DateTime.now().subtract(const Duration(days: 1));
      final deadlineTask = Task.fromMap('deadline-task', {
        'title': 'Past deadline',
        'deadline': 'not-a-date',
        'deadlineAt': Timestamp.fromDate(pastDate),
        'createdBy': {'uid': 'user-1'},
      });
      final reminderTask = Task.fromMap('reminder-task', {
        'title': 'Past reminder',
        'reminderAt': Timestamp.fromDate(pastDate),
        'createdBy': {'uid': 'user-1'},
      });
      final reminderFallbackTask = Task(
        'Past reminder with invalid deadline',
        deadline: 'not-a-date',
        reminder: pastDate.toIso8601String(),
        createdBy: {'uid': 'user-1'},
      );
      final repository = _TaskRepositoryStub()
        ..tasksToFetch = [deadlineTask, reminderTask, reminderFallbackTask];
      final viewModel = MapScreenViewModel(
        repository: repository,
        assignmentNotificationService: _AssignmentNotificationServiceStub(),
      );

      await viewModel.refreshTasks(_AuthViewModelStub());

      expect(deadlineTask.deadline, isNotNull);
      expect(reminderTask.reminder, isNotNull);
      expect(
        viewModel.overdueTasks().map((task) => task.title),
        containsAll([
          'Past deadline',
          'Past reminder',
          'Past reminder with invalid deadline',
        ]),
      );
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

  test('My Day includes future scheduled tasks but excludes done tasks', () {
    final completedToday = Task(
      'Completed today',
      isDone: true,
      deadline: DateTime(2026, 10, 14, 12).toIso8601String(),
    );
    final tomorrow = Task(
      'Tomorrow',
      deadline: DateTime(2026, 10, 15, 9).toIso8601String(),
    );
    final futureReminder = Task(
      'Future reminder',
      reminder: DateTime(2026, 10, 19, 9).toIso8601String(),
    );
    final malformedDate = Task('Invalid date', reminder: 'not-a-date');

    expect(
      MapScreenViewModel.myDayTasks([
        completedToday,
        tomorrow,
        futureReminder,
        malformedDate,
      ], now: now),
      [tomorrow, futureReminder],
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

  test('admin My Work includes tasks created by other users', () async {
    final ownTask = Task('My task', createdBy: {'uid': 'user-1'});
    final otherUserTask = Task(
      'Other user task',
      priority: 'Today',
      createdBy: {'uid': 'user-2'},
    );
    final viewModel = MapScreenViewModel(
      repository: _TaskRepositoryStub()
        ..tasksToFetch = [ownTask, otherUserTask],
      assignmentNotificationService: _AssignmentNotificationServiceStub(),
    );
    final admin = _AuthViewModelStub(role: AppRole.admin);

    await viewModel.refreshTasks(admin);

    expect(
      viewModel.myWorkTasks(admin),
      unorderedEquals([ownTask, otherUserTask]),
    );
    viewModel.dispose();
  });

  test('refreshes assigned tasks when the network reconnects', () async {
    var online = true;
    final networkStatusService = NetworkStatusService(
      autoStart: false,
      connectionChecker: () async => online,
    );
    final repository = _TaskRepositoryStub();
    final viewModel = MapScreenViewModel(
      repository: repository,
      assignmentNotificationService: _AssignmentNotificationServiceStub(),
      networkStatusService: networkStatusService,
    );
    final authViewModel = _AuthViewModelStub(role: AppRole.admin);
    viewModel.listenForTasks(authViewModel);
    final taskCreatedByOtherUser = Task(
      'Task created while offline',
      priority: 'Today',
      createdBy: {'uid': 'user-2'},
    );
    repository.tasksToFetch = [taskCreatedByOtherUser];

    online = false;
    await networkStatusService.checkNow();
    online = true;
    await networkStatusService.checkNow();
    await Future<void>.delayed(Duration.zero);

    expect(
      viewModel.myWorkTasks(authViewModel),
      contains(taskCreatedByOtherUser),
    );

    viewModel.dispose();
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

  test(
    'My Work shows monitored tasks in Free Works and assignees by priority',
    () {
      final monitoredTask = Task(
        'Follow up',
        priority: 'Today',
        assignee: 'Priya',
        monitor: 'Aman Yadav',
      );
      final assignedTask = Task(
        'Assigned today',
        priority: 'Today',
        assignee: 'Aman Yadav',
      );

      final viewModel = MapScreenViewModel(
        repository: _TaskRepositoryStub(),
        assignmentNotificationService: _AssignmentNotificationServiceStub(),
      );
      final monitorSections = viewModel.myWorkSections([
        monitoredTask,
      ], userName: 'Aman Yadav');
      final assigneeSections = viewModel.myWorkSections([
        monitoredTask,
        assignedTask,
      ], userName: 'Priya');

      expect(monitorSections['Monitor Works'], isNull);
      expect(monitorSections['Free Works'], [monitoredTask]);
      expect(monitorSections['Today Works'], isEmpty);
      expect(assigneeSections['Today Works'], [monitoredTask, assignedTask]);
      expect(monitoredTask.priority, 'Today');
      viewModel.dispose();
    },
  );

  test('task creator and assignee see their tasks by priority', () {
    final task = Task(
      'Follow up',
      priority: 'IMP',
      assignee: 'Priya',
      createdBy: {
        'uid': 'assigner-1',
        'email': 'assigner@example.com',
        'name': 'Assigner',
      },
    );
    final viewModel = MapScreenViewModel(
      repository: _TaskRepositoryStub(),
      assignmentNotificationService: _AssignmentNotificationServiceStub(),
    );

    final assignerSections = viewModel.myWorkSections(
      [task],
      userUid: 'assigner-1',
      userEmail: 'assigner@example.com',
      userName: 'Assigner',
    );
    final assigneeSections = viewModel.myWorkSections([
      task,
    ], userName: 'Priya');

    expect(assignerSections['Monitor Works'], isNull);
    expect(assignerSections['Free Works'], isEmpty);
    expect(assignerSections['IMP Works'], [task]);
    expect(assigneeSections['Monitor Works'], isNull);
    expect(assigneeSections['IMP Works'], [task]);
    viewModel.dispose();
  });

  test(
    'Assign tab includes tasks created and assigned by the current user',
    () {
      final createdAndAssigned = Task(
        'Assigned by me',
        assignee: 'Priya',
        createdBy: {'uid': 'user-1', 'email': 'me@example.com', 'name': 'Me'},
      );
      final assignedToMe = Task('Assigned to me', assignee: 'Me');
      final createdUnassigned = Task(
        'Not assigned',
        createdBy: {'uid': 'user-1', 'email': 'me@example.com', 'name': 'Me'},
      );
      final anotherUsersTask = Task(
        'Another user assigned',
        assignee: 'Priya',
        createdBy: {'uid': 'user-2', 'email': 'other@example.com'},
      );

      expect(
        MapScreenViewModel.assignTabTasksForUser(
          [
            createdAndAssigned,
            assignedToMe,
            createdUnassigned,
            anotherUsersTask,
          ],
          userUid: 'user-1',
          userEmail: 'me@example.com',
          userName: 'Me',
        ),
        [createdAndAssigned, assignedToMe],
      );
    },
  );

  test('monitor names are serialized for monitor task queries', () {
    final task = Task('Follow up', monitor: 'Aman Yadav, Priya');

    expect(task.toMap()['monitorNames'], ['Aman Yadav', 'Priya']);
    expect(Task.fromMap('task-1', task.toMap()).monitor, 'Aman Yadav, Priya');
  });

  test('My Work includes tasks whose priority I changed', () {
    final reprioritizedByMe = Task(
      'Reprioritized task',
      priority: 'IMP',
      priorityUpdatedByUid: 'user-1',
    );
    final reprioritizedBySomeoneElse = Task(
      'Someone else reprioritized',
      priority: 'U2',
      priorityUpdatedByUid: 'user-2',
    );

    expect(
      MapScreenViewModel.myTasksForUser(
        [reprioritizedByMe, reprioritizedBySomeoneElse],
        userUid: 'user-1',
        userEmail: 'user@example.com',
        userName: 'User',
      ),
      [reprioritizedByMe],
    );
  });

  test('My Work includes tasks undone by the current user only', () {
    final undoneByMe = Task(
      'Undone by me',
      isDone: false,
      lastUndoneByUid: 'user-1',
    );
    final undoneBySomeoneElse = Task(
      'Undone by someone else',
      isDone: false,
      lastUndoneByUid: 'user-2',
    );

    expect(
      MapScreenViewModel.myTasksForUser(
        [undoneByMe, undoneBySomeoneElse],
        userUid: 'user-1',
        userEmail: 'user@example.com',
        userName: 'Me',
      ),
      [undoneByMe],
    );
  });

  test('refresh keeps a task undone by me visible in My Work', () async {
    final task = Task(
      'Undone task',
      isDone: false,
      priority: 'U1',
      assignee: 'Someone else',
      lastUndoneByUid: 'user-1',
    );
    final repository = _TaskRepositoryStub()..tasksToFetch = [task];
    final viewModel = MapScreenViewModel(
      repository: repository,
      assignmentNotificationService: _AssignmentNotificationServiceStub(),
    );
    final authViewModel = _AuthViewModelStub();

    await viewModel.refreshTasks(authViewModel);

    final myTasks = viewModel.myTasks(authViewModel);
    expect(myTasks, contains(task));
    expect(viewModel.myWorkSections(myTasks)['Urgent Works'], [task]);
    viewModel.dispose();
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

  test('assigned task list only includes tasks assigned to this user', () {
    final assignedByName = Task('Assigned by name', assignee: 'Priya, Aman');
    final assignedByEmail = Task(
      'Assigned by email',
      assignee: 'aman@example.com',
    );
    final assignedByUid = Task('Assigned by uid', assigneeUid: 'user-1');
    final similarName = Task('Assigned to someone else', assignee: 'Amana');
    final unassigned = Task('Unassigned');

    expect(
      MapScreenViewModel.assignedTasksForUser(
        [
          assignedByName,
          assignedByEmail,
          assignedByUid,
          similarName,
          unassigned,
        ],
        userUid: 'user-1',
        userEmail: 'aman@example.com',
        userName: 'Aman',
      ),
      [assignedByName, assignedByEmail, assignedByUid],
    );
  });

  test('only admins see all users completed tasks', () {
    final amanTask = Task('Aman completed', isDone: true, assignee: 'Aman');
    final riyaTask = Task('Riya completed', isDone: true, assignee: 'Riya');
    final pendingTask = Task('Aman pending', assignee: 'Aman');
    final tasks = [amanTask, riyaTask, pendingTask];

    expect(
      MapScreenViewModel.doneTasksForUser(
        tasks,
        canViewAll: true,
        userUid: 'aman-uid',
        userEmail: 'aman@example.com',
        userName: 'Aman',
      ),
      [amanTask, riyaTask],
    );
    expect(
      MapScreenViewModel.doneTasksForUser(
        tasks,
        canViewAll: false,
        userUid: 'aman-uid',
        userEmail: 'aman@example.com',
        userName: 'Aman',
      ),
      [amanTask],
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

  test('monitor priority goes to Free Works, not Tomorrow', () {
    final monitorTask = Task('Monitor task', priority: 'Monitor');
    final tomorrowTask = Task('Tomorrow task', priority: 'Tomorrow');

    final sections = MapScreenViewModel.sectionsForWork([
      monitorTask,
      tomorrowTask,
    ]);

    expect(sections['Monitor Works'], isNull);
    expect(sections['Free Works'], [monitorTask]);
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
      'Free Works',
    ]);
    expect(sections['Overdue Works'], [unprioritizedOverdue, overdueImp]);
    expect(sections['IMP Works'], [imp]);
    expect(sections['Free Works'], isEmpty);
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
      expect(sections['Overdue Works'], [overdue]);
      expect(sections['Monitor Works'], isNull);
      expect(sections['Free Works'], isEmpty);

      overdue.priority = 'Free';
      sections = MapScreenViewModel.sectionsForWork([overdue]);
      expect(sections['Overdue Works'], [overdue]);
      expect(sections['Free Works'], isEmpty);

      overdue.priority = 'Today';
      sections = MapScreenViewModel.sectionsForWork([overdue]);
      expect(sections['Overdue Works'], [overdue]);
      expect(sections['Today Works'], isEmpty);
    },
  );
}

class _TaskRepositoryStub implements TaskRepository {
  final Completer<void> updateCompleter = Completer<void>();
  List<Task> tasksToFetch = const [];
  List<String> assigneeOptions = const [];
  List<String> clientOptions = const [];
  List<String> workTypeOptions = const [];
  List<String> projectOptions = const [];

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
  }) async => tasksToFetch;

  @override
  Future<List<String>> loadAssignees() async => assigneeOptions;

  @override
  Future<List<String>> loadClients() async => clientOptions;

  @override
  Future<List<String>> loadProjects() async => projectOptions;

  @override
  Future<List<String>> loadWorkTypes() async => workTypeOptions;

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

class _AuthViewModelStub implements AuthViewModel {
  _AuthViewModelStub({this.role = AppRole.user});

  final AppRole role;

  @override
  AppRole get appRole => role;

  @override
  String get userEmail => 'user@example.com';

  @override
  String get userName => 'User';

  @override
  String get userUid => 'user-1';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
