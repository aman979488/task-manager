import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/task.dart';

class TaskRepository {
  TaskRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  List<String>? _clientsCache;
  List<String>? _projectsCache;
  List<String>? _workTypesCache;
  List<String>? _assigneesCache;

  CollectionReference<Map<String, dynamic>> get _tasks =>
      _firestore.collection('map');

  Future<List<Task>> fetchTasks({
    required bool canReadAll,
    required String userUid,
    required String userName,
  }) async {
    final queries = _taskQueries(
      canReadAll: canReadAll,
      userUid: userUid,
      userName: userName,
    );
    if (queries.isEmpty) return Future.value(const <Task>[]);
    final snapshots = await Future.wait(queries.map((query) => query.get()));
    return _tasksFromSnapshots(snapshots);
  }

  Stream<List<Task>> watchTasks({
    required bool canReadAll,
    required String userUid,
    required String userName,
  }) {
    final queries = _taskQueries(
      canReadAll: canReadAll,
      userUid: userUid,
      userName: userName,
    );
    if (queries.isEmpty) return Stream.value(const <Task>[]);
    if (canReadAll) {
      return queries.single.snapshots().map(
        (snapshot) => snapshot.docs
            .map((doc) => Task.fromMap(doc.id, doc.data()))
            .toList(),
      );
    }

    return Stream<List<Task>>.multi((controller) {
      final snapshots = <int, QuerySnapshot<Map<String, dynamic>>>{};
      final subscriptions =
          <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
      for (var index = 0; index < queries.length; index++) {
        subscriptions.add(
          queries[index].snapshots().listen((snapshot) {
            snapshots[index] = snapshot;
            controller.add(_tasksFromSnapshots(snapshots.values));
          }, onError: controller.addError),
        );
      }
      controller.onCancel = () async {
        await Future.wait(
          subscriptions.map((subscription) => subscription.cancel()),
        );
      };
    });
  }

  List<Query<Map<String, dynamic>>> _taskQueries({
    required bool canReadAll,
    required String userUid,
    required String userName,
  }) {
    if (canReadAll) return [_tasks];
    final uid = userUid.trim();
    if (uid.isEmpty) return [];

    final queries = <Query<Map<String, dynamic>>>[
      _tasks.where('createdBy.uid', isEqualTo: uid),
      _tasks.where('assigneeUids', arrayContains: uid),
      _tasks.where('assigneeUid', isEqualTo: uid),
    ];
    final name = userName.trim();
    if (name.isNotEmpty) {
      queries
        ..add(_tasks.where('assignee', isEqualTo: name))
        ..add(_tasks.where('monitor', isEqualTo: name));
    }
    return queries;
  }

  List<Task> _tasksFromSnapshots(
    Iterable<QuerySnapshot<Map<String, dynamic>>> snapshots,
  ) {
    final tasksById = <String, Task>{};
    for (final snapshot in snapshots) {
      for (final doc in snapshot.docs) {
        tasksById[doc.id] = Task.fromMap(doc.id, doc.data());
      }
    }
    return tasksById.values.toList();
  }

  Future<void> addTask(Task task) async {
    final docRef = _tasks.doc();
    task.id = docRef.id;
    await docRef.set(_taskData(task));
  }

  Future<void> updateTask(Task task) async {
    if (task.id == null) return;
    await _tasks.doc(task.id).update(_taskData(task));
  }

  Future<void> deleteTask(Task task) async {
    if (task.id == null) return;
    await _tasks.doc(task.id).delete();
  }

  Future<List<String>> loadClients() async {
    if (_clientsCache != null) return _clientsCache!;
    final snapshot = await _firestore.collection('leads').get();
    _clientsCache = snapshot.docs
        .map((doc) {
          final data = doc.data();
          final name = data['name']?.toString().trim() ?? '';
          final surname = data['surname']?.toString().trim() ?? '';
          return surname.isNotEmpty ? '$name $surname' : name;
        })
        .where((name) => name.isNotEmpty)
        .toList();
    return _clientsCache!;
  }

  Future<List<String>> loadWorkTypes() async {
    if (_workTypesCache != null) return _workTypesCache!;
    final snapshot = await _firestore.collection('WorkType').get();
    _workTypesCache = snapshot.docs
        .map((doc) => doc.data()['workType']?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .toList();
    return _workTypesCache!;
  }

  Future<List<String>> loadProjects() async {
    if (_projectsCache != null) return _projectsCache!;
    final snapshot = await _firestore.collection('projects').get();
    _projectsCache = snapshot.docs
        .map((doc) => doc.data()['projectName']?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .toList();
    return _projectsCache!;
  }

  Future<List<String>> loadAssignees() async {
    if (_assigneesCache != null) return _assigneesCache!;
    final snapshots = await Future.wait([
      _firestore.collection('users').get(),
      _firestore.collection('cps').get(),
    ]);
    final valuesByName = <String, String>{};

    void addName(Object? value) {
      final name = value?.toString().trim() ?? '';
      if (name.isNotEmpty) {
        valuesByName.putIfAbsent(name.toLowerCase(), () => name);
      }
    }

    for (final doc in snapshots[0].docs) {
      final data = doc.data();
      addName(data['name'] ?? data['fullName'] ?? data['email']);
    }
    for (final doc in snapshots[1].docs) {
      final data = doc.data();
      addName(
        data['cpName'] ?? data['name'] ?? data['fullName'] ?? data['email'],
      );
    }

    _assigneesCache = valuesByName.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return _assigneesCache!;
  }

  Map<String, dynamic> _taskData(Task task) {
    final data = task.toMap();
    final reminderDate = DateTime.tryParse(task.reminder ?? '');
    final deadlineDate = DateTime.tryParse(task.deadline ?? '');
    data['reminderAt'] = reminderDate == null
        ? null
        : Timestamp.fromDate(reminderDate);
    data['deadlineAt'] = deadlineDate == null
        ? null
        : Timestamp.fromDate(deadlineDate);
    return data;
  }
}
