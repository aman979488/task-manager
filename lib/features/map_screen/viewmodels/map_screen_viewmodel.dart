import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../services/task_home_widget_service.dart';
import '../../../utils/role_permissions.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../models/task.dart';
import '../repositories/task_repository.dart';
import '../services/task_assignment_notification_service.dart';

class MapScreenViewModel extends ChangeNotifier {
  MapScreenViewModel({
    TaskRepository? repository,
    TaskAssignmentNotificationService? assignmentNotificationService,
  }) : _repository = repository ?? TaskRepository(),
       _assignmentNotificationService =
           assignmentNotificationService ?? TaskAssignmentNotificationService();

  final TaskRepository _repository;
  final TaskAssignmentNotificationService _assignmentNotificationService;
  final List<Task> _tasks = [];
  final Set<Task> _pendingTasks = {};
  final Set<Task> _selectedTasks = {};
  final Map<Task, Future<void>> _pendingTaskSaves = {};

  StreamSubscription<List<Task>>? _tasksSubscription;
  bool _isAddingTask = false;
  String? _lastErrorMessage;

  // View presentation state
  String _sortBy = 'Priority';
  String _groupBy = 'Assignee';
  String _viewType = 'Detailed list';
  double _zoom = 1.0;
  DateTime _calendarDate = DateTime.now();
  String _myDayViewType = 'Day';
  String _taskSearchQuery = '';
  bool _isSearchVisible = false;

  List<Task> get tasks => List.unmodifiable(_tasks);
  bool get isAddingTask => _isAddingTask;

  // Selection state
  Set<Task> get selectedTasks => Set.unmodifiable(_selectedTasks);
  bool get isSelectionMode => _selectedTasks.isNotEmpty;
  int get selectedCount => _selectedTasks.length;
  bool isTaskSelected(Task task) => _selectedTasks.contains(task);

  void toggleTaskSelection(Task task) {
    if (!_selectedTasks.add(task)) {
      _selectedTasks.remove(task);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedTasks.clear();
    notifyListeners();
  }

  Future<void> deleteSelectedTasks() async {
    final toDelete = _selectedTasks.toList();
    for (final task in toDelete) {
      await _repository.deleteTask(task);
      _tasks.remove(task);
    }
    _selectedTasks.clear();
    sortTasks();
    await _updateHomeWidgetSafely();
    notifyListeners();
  }

  // Display and filter state getters and setters
  String get sortBy => _sortBy;
  void setSortBy(String value) {
    _sortBy = value;
    notifyListeners();
  }

  String get groupBy => _groupBy;
  void setGroupBy(String value) {
    _groupBy = value;
    notifyListeners();
  }

  String get viewType => _viewType;
  void setViewType(String value) {
    _viewType = value;
    notifyListeners();
  }

  double get zoom => _zoom;
  void setZoom(double value) {
    _zoom = value;
    notifyListeners();
  }

  DateTime get calendarDate => _calendarDate;
  void setCalendarDate(DateTime value) {
    _calendarDate = value;
    notifyListeners();
  }

  String get myDayViewType => _myDayViewType;
  void setMyDayViewType(String value) {
    _myDayViewType = value;
    notifyListeners();
  }

  String get taskSearchQuery => _taskSearchQuery;
  void setTaskSearchQuery(String value) {
    _taskSearchQuery = value;
    notifyListeners();
  }

  bool get isSearchVisible => _isSearchVisible;
  void toggleSearchVisibility() {
    _isSearchVisible = !_isSearchVisible;
    if (!_isSearchVisible) {
      _taskSearchQuery = '';
    }
    notifyListeners();
  }

  String? takeErrorMessage() {
    final message = _lastErrorMessage;
    _lastErrorMessage = null;
    return message;
  }

  void listenForTasks(AuthViewModel authViewModel) {
    _tasksSubscription?.cancel();
    _tasksSubscription = _repository.watchTasks().listen(
      (loaded) {
        _replaceTasks(
          loaded
              .where((task) => isTaskVisibleToUser(task, authViewModel))
              .toList(),
        );
        _updateHomeWidgetSafely();
      },
      onError: (Object error) {
        debugPrint('Error listening for task updates: $error');
        _lastErrorMessage = 'Could not sync tasks. Pull down to refresh.';
        notifyListeners();
      },
    );
  }

  Future<void> refreshTasks(AuthViewModel authViewModel) async {
    final loaded = await _repository.fetchTasks();
    _replaceTasks(
      loaded.where((task) => isTaskVisibleToUser(task, authViewModel)).toList(),
    );
    await _updateHomeWidgetSafely();
  }

  bool isTaskVisibleToUser(Task task, AuthViewModel authViewModel) {
    if (authViewModel.appRole == AppRole.superAdmin ||
        authViewModel.appRole == AppRole.admin ||
        authViewModel.appRole == AppRole.officeStaff) {
      return true;
    }
    final myUid = authViewModel.userUid.trim().toLowerCase();
    final myEmail = authViewModel.userEmail.trim().toLowerCase();
    final myName = authViewModel.userName.trim().toLowerCase();
    final creator = task.createdBy;
    if (creator != null) {
      final creatorUid = (creator['uid'] ?? '').toString().trim().toLowerCase();
      final creatorEmail = (creator['email'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final creatorName = (creator['name'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if ((creatorUid.isNotEmpty &&
              (creatorUid == myUid || myUid.contains(creatorUid))) ||
          (creatorEmail.isNotEmpty &&
              (creatorEmail == myEmail || myEmail.contains(creatorEmail))) ||
          (creatorName.isNotEmpty &&
              (creatorName == myName || myName.contains(creatorName)))) {
        return true;
      }
    }

    final assignee = (task.assignee ?? '').trim().toLowerCase();
    return assignee.isNotEmpty &&
        ((myName.isNotEmpty && assignee.contains(myName)) ||
            (myEmail.isNotEmpty && assignee.contains(myEmail)) ||
            (myUid.isNotEmpty && assignee.contains(myUid)));
  }

  Future<bool> addTask({
    required String title,
    required AuthViewModel authViewModel,
    String? priority,
    String? reminder,
    String? assignee,
    String? deadline,
    String? workType,
    String? folder,
    String? clientName,
    String? refProject,
  }) async {
    if (_isAddingTask) return false;
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) return false;

    _isAddingTask = true;
    notifyListeners();
    final task = Task(
      cleanTitle,
      priority: priority,
      reminder: reminder,
      reminderSent: false,
      deadlineReminderSent: false,
      assignee: assignee,
      deadline: deadline,
      workType: workType,
      folder: folder,
      clientName: clientName,
      refProject: refProject,
      createdBy: authViewModel.actorMetadata,
      assigneeUid: assignee,
      priorityUpdatedAt: priority == null
          ? null
          : DateTime.now().millisecondsSinceEpoch,
    );

    if (isTaskVisibleToUser(task, authViewModel)) {
      _pendingTasks.add(task);
      _tasks.add(task);
      sortTasks();
      notifyListeners();
    }
    if (assignee != null && assignee.trim().isNotEmpty) {
      unawaited(
        _sendAssignmentNotification(assignee, cleanTitle, authViewModel),
      );
    }
    final saveOperation = _saveNewTask(task);
    _pendingTaskSaves[task] = saveOperation;
    unawaited(saveOperation);
    _isAddingTask = false;
    notifyListeners();
    return true;
  }

  Future<void> updateTask(Task task) async {
    await _repository.updateTask(task);
    await _updateHomeWidgetSafely();
    notifyListeners();
  }

  Future<void> addTaskToMyDay(Task task) async {
    if (task.isInMyDay) return;
    task.isInMyDay = true;
    notifyListeners();
    try {
      await updateTask(task);
    } catch (error) {
      debugPrint('Error adding task to My Day: $error');
      task.isInMyDay = false;
      _lastErrorMessage =
          'Could not add "${task.title}" to My Day. Please try again.';
      notifyListeners();
    }
  }

  Future<void> toggleTaskDone(Task task) async {
    task.isDone = !task.isDone;
    task.completedAt = task.isDone
        ? DateTime.now().millisecondsSinceEpoch
        : null;
    await updateTask(task);
    sortTasks();
  }

  Future<void> updateTaskPriority(Task task, String? priority) async {
    task.priority = priority;
    task.priorityUpdatedAt = DateTime.now().millisecondsSinceEpoch;
    sortTasks();
    await updateTask(task);
  }

  Future<void> addSubstep(Task task, String title) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) return;
    final step = TaskStep(title: cleanTitle);
    task.steps.add(step);
    try {
      final pendingSave = _pendingTaskSaves[task];
      if (pendingSave != null) await pendingSave;
      if (task.id == null) {
        throw StateError('Task has not been saved yet.');
      }
      await updateTask(task);
      sortTasks();
    } catch (error) {
      task.steps.remove(step);
      debugPrint('Error saving substep for "${task.title}": $error');
      _lastErrorMessage =
          'Could not save "$cleanTitle" under "${task.title}". Please try again.';
      notifyListeners();
    }
  }

  Future<void> deleteTask(Task task) async {
    await _repository.deleteTask(task);
    _tasks.remove(task);
    _selectedTasks.remove(task);
    notifyListeners();
    await _updateHomeWidgetSafely();
  }

  Future<List<String>> loadClients() => _repository.loadClients();
  Future<List<String>> loadAssignees() => _repository.loadAssignees();
  Future<List<String>> loadWorkTypes() => _repository.loadWorkTypes();
  Future<List<String>> loadProjects() => _repository.loadProjects();

  void sortTasks() {
    _tasks.sort(MapScreenViewModel.compareTasks);
    notifyListeners();
  }

  static int compareTasks(Task first, Task second) {
    if (first.isDone != second.isDone) return first.isDone ? 1 : -1;
    if (first.isDone && first.completedAt != second.completedAt) {
      if (first.completedAt == null) return 1;
      if (second.completedAt == null) return -1;
      return second.completedAt!.compareTo(first.completedAt!);
    }
    final firstPriority = _priorityOrder(first.priority);
    final secondPriority = _priorityOrder(second.priority);
    if (firstPriority != secondPriority) {
      return firstPriority.compareTo(secondPriority);
    }
    return (second.priorityUpdatedAt ?? 0).compareTo(
      first.priorityUpdatedAt ?? 0,
    );
  }

  List<Task> overdueTasks() => _tasks.where(isOverdue).toList();

  List<Task> pendingTasks() =>
      _tasks.where((task) => !task.isDone && !isOverdue(task)).toList();

  List<Task> doneTasks() => _tasks.where((task) => task.isDone).toList();

  List<Task> getVisibleTasks({List<Task>? source}) {
    return visibleTasks(
      source: source ?? _tasks,
      query: _taskSearchQuery,
      sortBy: _sortBy,
    );
  }

  List<Task> upcomingReminders() {
    final now = DateTime.now();
    final reminders =
        _tasks.where((task) {
          if (task.isDone) return false;
          final scheduled = DateTime.tryParse(
            task.deadline ?? task.reminder ?? '',
          );
          return scheduled != null &&
              scheduled.isAfter(now.subtract(const Duration(days: 1)));
        }).toList()..sort((a, b) {
          final dateA =
              DateTime.tryParse(a.deadline ?? a.reminder ?? '') ??
              DateTime(2100);
          final dateB =
              DateTime.tryParse(b.deadline ?? b.reminder ?? '') ??
              DateTime(2100);
          return dateA.compareTo(dateB);
        });
    return reminders;
  }

  int upcomingNotificationCount() {
    final now = DateTime.now();
    return _tasks.where((task) {
      final scheduled = DateTime.tryParse(task.deadline ?? task.reminder ?? '');
      return !task.isDone && scheduled != null && scheduled.isAfter(now);
    }).length;
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

  static List<Task> myDayTasks(List<Task> source, {DateTime? now}) {
    final currentDate = now ?? DateTime.now();
    final today = DateTime(
      currentDate.year,
      currentDate.month,
      currentDate.day,
    );
    return source.where((task) {
      if (task.isDone) return false;
      if (task.isInMyDay) return true;
      if (task.priority?.trim().toLowerCase() == 'today') return true;

      final scheduled = DateTime.tryParse(task.deadline ?? task.reminder ?? '');
      return scheduled != null &&
          scheduled.year == today.year &&
          scheduled.month == today.month &&
          scheduled.day == today.day;
    }).toList();
  }

  bool isOverdue(Task task) {
    if (task.isDone) return false;
    final date = DateTime.tryParse(task.deadline ?? task.reminder ?? '');
    return date != null && date.isBefore(DateTime.now());
  }

  List<Task> myTasks(AuthViewModel authViewModel) {
    final myUid = authViewModel.userUid.trim().toLowerCase();
    final myEmail = authViewModel.userEmail.trim().toLowerCase();
    final myName = authViewModel.userName.trim().toLowerCase();
    return _tasks.where((task) {
      final creator = task.createdBy;
      var isCreator = false;
      if (creator != null) {
        final uid = (creator['uid'] ?? '').toString().trim().toLowerCase();
        final email = (creator['email'] ?? '').toString().trim().toLowerCase();
        final name = (creator['name'] ?? '').toString().trim().toLowerCase();
        isCreator =
            (uid.isNotEmpty && (uid == myUid || myUid.contains(uid))) ||
            (email.isNotEmpty &&
                (email == myEmail || myEmail.contains(email))) ||
            (name.isNotEmpty && (name == myName || myName.contains(name)));
      }
      final assignee = (task.assignee ?? '').trim().toLowerCase();
      final isAssignee =
          assignee.isNotEmpty &&
          ((myName.isNotEmpty && assignee.contains(myName)) ||
              (myEmail.isNotEmpty && assignee.contains(myEmail)) ||
              (myUid.isNotEmpty && assignee.contains(myUid)));
      return isCreator || isAssignee;
    }).toList();
  }

  Map<String, List<Task>> myWorkSections(List<Task> myTasks) {
    return sectionsForWork(myTasks);
  }

  static Map<String, List<Task>> sectionsForWork(List<Task> myTasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final pending = myTasks.where((task) => !task.isDone);
    final scheduled = pending
        .where((task) => task.priority?.trim().isEmpty ?? true)
        .map(
          (task) => (task: task, date: DateTime.tryParse(task.deadline ?? '')),
        )
        .where((entry) => entry.date != null)
        .toList();
    final todayWorks = <Task>{
      ...scheduled
          .where(
            (entry) =>
                entry.date!.year == today.year &&
                entry.date!.month == today.month &&
                entry.date!.day == today.day,
          )
          .map((entry) => entry.task),
      ...pending.where(
        (task) => task.priority?.trim().toLowerCase() == 'today',
      ),
    }.toList();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final tomorrowWorks = <Task>{
      ...scheduled
          .where(
            (entry) =>
                entry.date!.year == tomorrow.year &&
                entry.date!.month == tomorrow.month &&
                entry.date!.day == tomorrow.day,
          )
          .map((entry) => entry.task),
      ...pending.where(
        (task) => task.priority?.trim().toLowerCase() == 'tomorrow',
      ),
    }.toList();
    List<Task> withPriority(String priority) => pending
        .where((task) => task.priority?.trim().toLowerCase() == priority)
        .toList();
    return {
      'Urgent Works': pending
          .where(
            (task) => const {
              'u1',
              'u2',
              'u3',
              'urgent',
            }.contains(task.priority?.trim().toLowerCase()),
          )
          .toList(),
      'IMP Works': withPriority('imp'),
      'Today Works': todayWorks,
      'Tomorrow Works': tomorrowWorks,
      'Day Later Works': withPriority('day later'),
      'Later Works': withPriority('later'),
      'Process Works': withPriority('process'),
      'Hold Works': withPriority('hold'),
    };
  }

  List<Task> visibleTasks({
    List<Task>? source,
    required String query,
    required String sortBy,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final result = (source ?? _tasks)
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
        result.sort(MapScreenViewModel.compareTasks);
    }
    return result;
  }

  Future<void> _saveNewTask(Task task) async {
    try {
      await _repository.addTask(task);
      _pendingTasks.remove(task);
      await _updateHomeWidgetSafely();
    } catch (error) {
      debugPrint('Error adding task: $error');
      _pendingTasks.remove(task);
      _tasks.removeWhere(
        (existing) =>
            identical(existing, task) ||
            (task.id != null && existing.id == task.id),
      );
      _lastErrorMessage = 'Could not send "${task.title}". Please try again.';
      notifyListeners();
    } finally {
      _pendingTaskSaves.remove(task);
    }
  }

  Future<void> _sendAssignmentNotification(
    String assignee,
    String title,
    AuthViewModel authViewModel,
  ) async {
    try {
      await _assignmentNotificationService.sendAssignmentNotification(
        assignee: assignee,
        taskTitle: title,
        senderName: authViewModel.userName,
        senderUid: authViewModel.userUid,
        senderEmail: authViewModel.userEmail,
        notificationsEnabled: authViewModel.allowNotifications,
      );
    } catch (error) {
      debugPrint('Error sending notification: $error');
    }
  }

  void _replaceTasks(List<Task> loaded) {
    loaded.sort(MapScreenViewModel.compareTasks);
    final loadedIds = loaded.map((task) => task.id).toSet();
    final pending = _pendingTasks
        .where((task) => task.id == null || !loadedIds.contains(task.id))
        .toList();
    _tasks
      ..clear()
      ..addAll(loaded)
      ..addAll(pending)
      ..sort(MapScreenViewModel.compareTasks);
    notifyListeners();
  }

  Future<void> _updateHomeWidgetSafely() async {
    try {
      await updateTaskHomeWidget(_tasks);
    } catch (error) {
      debugPrint('Error updating task home widget: $error');
    }
  }

  static int _priorityOrder(String? priority) => switch (priority) {
    'U1' => 1,
    'U2' => 2,
    'U3' => 3,
    'Urgent' => 4,
    'IMP' => 5,
    'Today' => 6,
    'Tomorrow' => 7,
    'Day Later' => 8,
    'Later' => 9,
    'Process' => 10,
    'Hold' => 11,
    'Free' => 12,
    _ => 100,
  };

  @override
  void dispose() {
    _tasksSubscription?.cancel();
    super.dispose();
  }
}
