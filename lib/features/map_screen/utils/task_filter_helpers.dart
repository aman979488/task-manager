import '../../../utils/role_permissions.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../models/task.dart';

class TaskFilterHelpers {
  const TaskFilterHelpers._();

  static bool canReadAllTasks(AuthViewModel authViewModel) =>
      authViewModel.appRole == AppRole.superAdmin ||
      authViewModel.appRole == AppRole.admin;

  static bool isTaskVisibleToUser(Task task, AuthViewModel authViewModel) {
    if (canReadAllTasks(authViewModel)) return true;
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
    final lastUndoneByUid = (task.lastUndoneByUid ?? '').trim().toLowerCase();
    return (myUid.isNotEmpty && lastUndoneByUid == myUid) ||
        (assignee.isNotEmpty &&
            ((myName.isNotEmpty && assignee.contains(myName)) ||
                (myEmail.isNotEmpty && assignee.contains(myEmail)) ||
                (myUid.isNotEmpty && assignee.contains(myUid))));
  }

  static bool isTaskOverdue(Task task, {DateTime? now}) {
    if (task.isDone) return false;
    final currentTime = now ?? DateTime.now();
    final date = scheduledDateTime(task, now: currentTime);
    if (date == null || !date.isBefore(currentTime)) return false;
    return true;
  }

  static DateTime? scheduledDateTime(Task task, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    final deadline = DateTime.tryParse(task.deadline ?? '');
    final reminder = DateTime.tryParse(task.reminder ?? '');
    final manualTime =
        _minutesOfDay(task.endTime) ?? _minutesOfDay(task.startTime);
    final scheduledDate = deadline ?? reminder;
    return _scheduledDateTime(
      task,
      deadline: deadline,
      scheduledDate: scheduledDate,
      manualTime: manualTime,
      now: currentTime,
    );
  }

  static DateTime? _scheduledDateTime(
    Task task, {
    required DateTime? deadline,
    required DateTime? scheduledDate,
    required int? manualTime,
    required DateTime now,
  }) {
    if (scheduledDate == null) {
      return _dateForPriorityTime(task, manualTime, now);
    }
    if (manualTime == null ||
        (deadline != null && (deadline.hour != 0 || deadline.minute != 0))) {
      return scheduledDate;
    }
    return DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      manualTime ~/ 60,
      manualTime % 60,
    );
  }

  static DateTime? _dateForPriorityTime(
    Task task,
    int? manualTime,
    DateTime now,
  ) {
    if (manualTime == null) return null;
    final offset = switch (task.priority?.trim().toLowerCase()) {
      'today' => 0,
      'tomorrow' => 1,
      'day later' => 2,
      'later' => 3,
      _ => task.isInMyDay ? 0 : null,
    };
    if (offset == null) return null;
    final baseDate = task.priorityUpdatedAt == null
        ? now
        : DateTime.fromMillisecondsSinceEpoch(task.priorityUpdatedAt!);
    final date = DateTime(baseDate.year, baseDate.month, baseDate.day + offset);
    return DateTime(
      date.year,
      date.month,
      date.day,
      manualTime ~/ 60,
      manualTime % 60,
    );
  }

  static int? _minutesOfDay(String? value) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?:\s*(AM|PM))?$',
      caseSensitive: false,
    ).firstMatch(value?.trim() ?? '');
    if (match == null) return null;
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final meridiem = match.group(3)?.toUpperCase();
    if (minute > 59) return null;
    if (meridiem != null) {
      if (hour < 1 || hour > 12) return null;
      hour %= 12;
      if (meridiem == 'PM') hour += 12;
    } else if (hour > 23) {
      return null;
    }
    return hour * 60 + minute;
  }

  static List<Task> myDayTasks(List<Task> source, {DateTime? now}) {
    return source.where((task) {
      if (task.isDone) return false;
      if (task.isInMyDay) return true;
      if (const {
        'today',
        'tomorrow',
        'later',
        'day later',
      }.contains(task.priority?.trim().toLowerCase())) {
        return true;
      }

      return DateTime.tryParse(task.deadline ?? task.reminder ?? '') != null;
    }).toList();
  }

  static List<Task> assignedTasksForUser(
    Iterable<Task> tasks, {
    required String userUid,
    required String userEmail,
    required String userName,
  }) {
    final normalizedUid = userUid.trim().toLowerCase();
    final normalizedEmail = userEmail.trim().toLowerCase();
    final normalizedName = userName.trim().toLowerCase();
    return tasks
        .where(
          (task) => isAssignedToUser(
            task,
            userUid: normalizedUid,
            userEmail: normalizedEmail,
            userName: normalizedName,
          ),
        )
        .toList();
  }

  static List<Task> assignTabTasksForUser(
    Iterable<Task> tasks, {
    required String userUid,
    required String userEmail,
    required String userName,
  }) {
    return assignedTasksForUser(
      tasks,
      userUid: userUid,
      userEmail: userEmail,
      userName: userName,
    );
  }

  static List<Task> myTasksForUser(
    Iterable<Task> tasks, {
    required String userUid,
    required String userEmail,
    required String userName,
  }) {
    final myUid = userUid.trim().toLowerCase();
    final myEmail = userEmail.trim().toLowerCase();
    final myName = userName.trim().toLowerCase();
    return tasks.where((task) {
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
      final isAssignedToMe = isAssignedToUser(
        task,
        userUid: myUid,
        userEmail: myEmail,
        userName: myName,
      );
      final isMonitoredByMe = isMonitoredByUser(
        task,
        userUid: myUid,
        userEmail: myEmail,
        userName: myName,
      );
      final priorityUpdatedByUid = (task.priorityUpdatedByUid ?? '')
          .trim()
          .toLowerCase();
      final isPriorityUpdatedByMe =
          myUid.isNotEmpty && priorityUpdatedByUid == myUid;
      final lastUndoneByUid = (task.lastUndoneByUid ?? '').trim().toLowerCase();
      final isUndoneByMe = myUid.isNotEmpty && lastUndoneByUid == myUid;
      return isCreator ||
          isAssignedToMe ||
          isMonitoredByMe ||
          isPriorityUpdatedByMe ||
          isUndoneByMe;
    }).toList();
  }

  static List<Task> doneTasksForUser(
    Iterable<Task> tasks, {
    required bool canViewAll,
    required String userUid,
    required String userEmail,
    required String userName,
  }) {
    final completedTasks = tasks.where((task) => task.isDone);
    if (canViewAll) return completedTasks.toList();
    return assignedTasksForUser(
      completedTasks,
      userUid: userUid,
      userEmail: userEmail,
      userName: userName,
    );
  }

  static bool isAssignedToUser(
    Task task, {
    required String userUid,
    required String userEmail,
    required String userName,
  }) {
    final identities = {userName, userEmail, userUid}
      ..removeWhere((identity) => identity.isEmpty);
    if (identities.isEmpty) return false;

    final assigneeIdentities = {
      ...(task.assignee ?? '').split(RegExp(r'[,;\n]')),
      ...(task.assigneeUid ?? '').split(RegExp(r'[,;\n]')),
    }.map((identity) => identity.trim().toLowerCase());
    return assigneeIdentities.any(
      (identity) => identity.isNotEmpty && identities.contains(identity),
    );
  }

  static bool isCreatedByUser(
    Task task, {
    required String userUid,
    required String userEmail,
    required String userName,
  }) {
    final creator = task.createdBy;
    if (creator == null) return false;
    final creatorUid = (creator['uid'] ?? '').toString().trim().toLowerCase();
    final creatorEmail = (creator['email'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final creatorName = (creator['name'] ?? '').toString().trim().toLowerCase();
    return (userUid.isNotEmpty &&
            creatorUid.isNotEmpty &&
            (creatorUid == userUid || userUid.contains(creatorUid))) ||
        (userEmail.isNotEmpty && creatorEmail == userEmail) ||
        (userName.isNotEmpty && creatorName == userName);
  }

  static bool isMonitoredByUser(
    Task task, {
    required String userUid,
    required String userEmail,
    required String userName,
  }) {
    final monitorPeople = (task.monitor ?? '')
        .split(RegExp(r'[,;\n]'))
        .map((person) => person.trim().toLowerCase())
        .where((person) => person.isNotEmpty);
    return monitorPeople.any(
      (person) => [userName, userEmail, userUid].any((identity) {
        if (identity.isEmpty) return false;
        final personParts = person
            .split(RegExp(r'[^a-z0-9@._-]+'))
            .where((part) => part.isNotEmpty);
        return person == identity || personParts.contains(identity);
      }),
    );
  }

  static List<Task> upcomingReminders(Iterable<Task> tasks) {
    final now = DateTime.now();
    final reminders =
        tasks.where((task) {
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

  static int upcomingNotificationCount(Iterable<Task> tasks) {
    final now = DateTime.now();
    return tasks.where((task) {
      final scheduled = DateTime.tryParse(task.deadline ?? task.reminder ?? '');
      return !task.isDone && scheduled != null && scheduled.isAfter(now);
    }).length;
  }
}
