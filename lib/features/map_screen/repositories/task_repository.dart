
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

  Future<List<Task>> fetchTasks() async {
    final snapshot = await _tasks.get();
    return snapshot.docs
        .map((doc) => Task.fromMap(doc.id, doc.data()))
        .toList();
  }

  Stream<List<Task>> watchTasks() => _tasks.snapshots().map(
    (snapshot) => snapshot.docs
        .map((doc) => Task.fromMap(doc.id, doc.data()))
        .toList(),
  );

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
