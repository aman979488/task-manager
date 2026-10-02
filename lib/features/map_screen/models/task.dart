class TaskStep {
  String title;
  bool isDone;

  TaskStep({
    required this.title,
    this.isDone = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'isDone': isDone,
    };
  }

  factory TaskStep.fromMap(Map<String, dynamic> data) {
    return TaskStep(
      title: data['title'] ?? '',
      isDone: data['isDone'] ?? false,
    );
  }
}

class TaskFile {
  String name;
  int size;
  String? path;

  TaskFile({
    required this.name,
    required this.size,
    this.path,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'size': size,
      'path': path,
    };
  }

  factory TaskFile.fromMap(Map<String, dynamic> data) {
    return TaskFile(
      name: data['name'] ?? '',
      size: data['size'] ?? 0,
      path: data['path'],
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
      })  : createdDate = createdDate ?? _getCurrentDateTime(),
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
    final rawSteps = data['steps'] as List<dynamic>?;
    final rawFiles = data['files'] as List<dynamic>?;

    return Task(
      data['title'] ?? '',
      id: id,
      isDone: data['isDone'] ?? false,
      note: data['note'] ?? '',
      createdDate: data['createdDate'],
      priority: data['priority'],
      reminder: data['reminder'],
      assignee: data['assignee'],
      deadline: data['deadline'],
      workType: data['workType'],
      folder: data['folder'],
      clientName: data['clientName'],
      refProject: data['refProject'],
      startTime: data['startTime'],
      endTime: data['endTime'],
      accompaniedBy: data['accompaniedBy'],
      monitor: data['monitor'],
      remark: data['remark'],
      createdBy: data['createdBy'] is Map ? Map<String, dynamic>.from(data['createdBy']) : null,
      editedBy: data['editedBy'] is Map ? Map<String, dynamic>.from(data['editedBy']) : null,
      assigneeUid: data['assigneeUid'],
      priorityUpdatedAt: data['priorityUpdatedAt'] as int?,
      steps: rawSteps
          ?.map((e) => TaskStep.fromMap(e as Map<String, dynamic>))
          .toList() ??
          <TaskStep>[],
      files: rawFiles
          ?.map((e) => TaskFile.fromMap(e as Map<String, dynamic>))
          .toList() ??
          <TaskFile>[],
    );
  }
}

// helper
String _getCurrentDateTime() {
  final now = DateTime.now();
  return "${now.day}/${now.month}/${now.year} • "
      "${now.hour}:${now.minute.toString().padLeft(2, '0')}";
}
