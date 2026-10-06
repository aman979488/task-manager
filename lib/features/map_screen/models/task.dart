class TaskStep {
  String title;
  bool isDone;

  TaskStep({required this.title, this.isDone = false});

  Map<String, dynamic> toMap() {
    return {'title': title, 'isDone': isDone};
  }

  factory TaskStep.fromMap(dynamic raw) {
    final data = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    return TaskStep(
      title: (data['title'] ?? '').toString(),
      isDone: data['isDone'] is bool ? data['isDone'] as bool : false,
    );
  }
}

class TaskFile {
  String name;
  int size;
  String? path;

  TaskFile({required this.name, required this.size, this.path});

  Map<String, dynamic> toMap() {
    return {'name': name, 'size': size, 'path': path};
  }

  factory TaskFile.fromMap(dynamic raw) {
    final data = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    return TaskFile(
      name: (data['name'] ?? '').toString(),
      size: data['size'] is num ? (data['size'] as num).toInt() : 0,
      path: data['path']?.toString(),
    );
  }
}

class Task {
  String? id; // Firestore document ID
  String title;
  bool isDone;
  String note;
  String createdDate;

  // button selections
  String? priority;
  String? reminder;
  bool reminderSent;
  bool deadlineReminderSent;
  String? assignee;
  String? deadline;
  String? workType;
  String? folder;
  String? clientName;
  String? refProject;
  String? startTime;
  String? endTime;
  String? accompaniedBy;
  String? monitor;
  String? remark;

  Map<String, dynamic>? createdBy;
  Map<String, dynamic>? editedBy;
  String? assigneeUid;

  int? priorityUpdatedAt;

  List<TaskStep> steps;
  List<TaskFile> files;

  Task(
    this.title, {
    this.id,
    this.isDone = false,
    this.note = '',
    String? createdDate,
    this.priority,
    this.reminder,
    this.reminderSent = false,
    this.deadlineReminderSent = false,
    this.assignee,
    this.deadline,
    this.workType,
    this.folder,
    this.clientName,
    this.refProject,
    this.startTime,
    this.endTime,
    this.accompaniedBy,
    this.monitor,
    this.remark,
    this.createdBy,
    this.editedBy,
    this.assigneeUid,
    this.priorityUpdatedAt,
    List<TaskStep>? steps,
    List<TaskFile>? files,
  }) : createdDate = createdDate ?? _getCurrentDateTime(),
       steps = steps ?? <TaskStep>[],
       files = files ?? <TaskFile>[];

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'isDone': isDone,
      'note': note,
      'createdDate': createdDate,
      'priority': priority,
      'reminder': reminder,
      'reminderSent': reminderSent,
      'deadlineReminderSent': deadlineReminderSent,
      'assignee': assignee,
      'deadline': deadline,
      'workType': workType,
      'folder': folder,
      'clientName': clientName,
      'refProject': refProject,
      'startTime': startTime,
      'endTime': endTime,
      'accompaniedBy': accompaniedBy,
      'monitor': monitor,
      'remark': remark,
      'createdBy': createdBy,
      'editedBy': editedBy,
      'assigneeUid': assigneeUid,
      'priorityUpdatedAt': priorityUpdatedAt,
      'steps': steps.map((s) => s.toMap()).toList(),
      'files': files.map((f) => f.toMap()).toList(),
    };
  }

  factory Task.fromMap(String id, Map<String, dynamic> data) {
    final rawTitle = data['title'];
    final title = rawTitle is String ? rawTitle : '';
    final rawSteps = data['steps'];
    final rawFiles = data['files'];
    final parsedSteps = rawSteps is List ? rawSteps : const <dynamic>[];
    final parsedFiles = rawFiles is List ? rawFiles : const <dynamic>[];

    final dynamic priorityUpdatedAtValue = data['priorityUpdatedAt'];
    int? parsedPriorityUpdatedAt;
    if (priorityUpdatedAtValue is int) {
      parsedPriorityUpdatedAt = priorityUpdatedAtValue;
    } else if (priorityUpdatedAtValue is num) {
      parsedPriorityUpdatedAt = priorityUpdatedAtValue.toInt();
    } else if (priorityUpdatedAtValue is String) {
      parsedPriorityUpdatedAt = int.tryParse(priorityUpdatedAtValue);
    }

    return Task(
      title,
      id: id,
      isDone: data['isDone'] ?? false,
      note: data['note'] ?? '',
      createdDate: data['createdDate']?.toString(),
      priority: data['priority']?.toString(),
      reminder: data['reminder']?.toString(),
      reminderSent: data['reminderSent'] ?? false,
      deadlineReminderSent: data['deadlineReminderSent'] ?? false,
      assignee: data['assignee']?.toString(),
      deadline: data['deadline']?.toString(),
      workType: data['workType']?.toString(),
      folder: data['folder']?.toString(),
      clientName: data['clientName']?.toString(),
      refProject: data['refProject']?.toString(),
      startTime: data['startTime']?.toString(),
      endTime: data['endTime']?.toString(),
      accompaniedBy: data['accompaniedBy']?.toString(),
      monitor: data['monitor']?.toString(),
      remark: data['remark']?.toString(),
      createdBy: data['createdBy'] is Map
          ? Map<String, dynamic>.from(data['createdBy'] as Map)
          : null,
      editedBy: data['editedBy'] is Map
          ? Map<String, dynamic>.from(data['editedBy'] as Map)
          : null,
      assigneeUid: data['assigneeUid']?.toString(),
      priorityUpdatedAt: parsedPriorityUpdatedAt,
      steps: parsedSteps
          .map((e) => TaskStep.fromMap(e))
          .where((step) => step.title.isNotEmpty || step.isDone)
          .toList(),
      files: parsedFiles
          .map((e) => TaskFile.fromMap(e))
          .where((file) => file.name.isNotEmpty || file.path != null)
          .toList(),
    );
  }

  bool isReminderDueAt(DateTime now) {
    if (reminder == null || reminderSent) return false;

    final reminderTime = DateTime.tryParse(reminder!);
    if (reminderTime == null) return false;

    return !reminderTime.isAfter(now);
  }

  bool isDeadlineNotificationDue(DateTime now) {
    if (deadline == null || deadlineReminderSent) return false;

    final deadlineTime = DateTime.tryParse(deadline!);
    if (deadlineTime == null) return false;

    final diff = deadlineTime.difference(now);
    return diff > Duration.zero && diff <= const Duration(hours: 3);
  }
}

// helper
String _getCurrentDateTime() {
  final now = DateTime.now();
  return "${now.day}/${now.month}/${now.year} • "
      "${now.hour}:${now.minute.toString().padLeft(2, '0')}";
}
