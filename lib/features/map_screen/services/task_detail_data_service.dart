import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/task_constants.dart';
import 'metadata_cache_service.dart';

class TaskDetailDataService {
  List<String>? _workTypesCache;
  List<String>? _assigneesCache;
  List<String>? _clientsCache;
  List<String>? _foldersCache;
  List<String>? _projectsCache;

  Future<List<String>> loadWorkTypes() async {
    if (_workTypesCache != null && _workTypesCache!.isNotEmpty) return _workTypesCache!;
    final local = await MetadataCacheService.loadStringList(MetadataCacheService.keyWorkTypes);
    if (local != null && local.isNotEmpty) {
      _workTypesCache = local;
    }
    try {
      final snap = await FirebaseFirestore.instance.collection('WorkType').get();
      final values = TaskConstants.orderWorkTypes(
        snap.docs
            .map((d) => (d.data()['workType'] ?? '').toString())
            .where((e) => e.isNotEmpty),
      );
      if (values.isNotEmpty) {
        _workTypesCache = values;
        await MetadataCacheService.saveStringList(MetadataCacheService.keyWorkTypes, values);
      }
    } catch (_) {}
    return _workTypesCache ?? const [];
  }

  Future<List<String>> loadAssignees() async {
    if (_assigneesCache != null && _assigneesCache!.isNotEmpty) return _assigneesCache!;
    final local = await MetadataCacheService.loadStringList(MetadataCacheService.keyAssignees);
    if (local != null && local.isNotEmpty) {
      _assigneesCache = local;
    }
    try {
      final snapshots = await Future.wait([
        FirebaseFirestore.instance.collection('users').get(),
        FirebaseFirestore.instance.collection('cps').get(),
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
        addName(data['name'] ?? data['fullName'] ?? data['email'] ?? doc.id);
      }
      for (final doc in snapshots[1].docs) {
        final data = doc.data();
        addName(
          data['cpName'] ??
              data['name'] ??
              data['fullName'] ??
              data['email'] ??
              doc.id,
        );
      }

      final values = valuesByName.values.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      if (values.isNotEmpty) {
        _assigneesCache = values;
        await MetadataCacheService.saveStringList(MetadataCacheService.keyAssignees, values);
      }
    } catch (_) {}
    return _assigneesCache ?? const [];
  }

  Future<List<String>> loadClients() async {
    if (_clientsCache != null && _clientsCache!.isNotEmpty) return _clientsCache!;
    final local = await MetadataCacheService.loadStringList(MetadataCacheService.keyClients);
    if (local != null && local.isNotEmpty) {
      _clientsCache = local;
    }
    try {
      final snap = await FirebaseFirestore.instance.collection('leads').get();
      final values = snap.docs
          .map((d) {
            final data = d.data();
            final name = data['name']?.toString().trim() ?? '';
            final surname = data['surname']?.toString().trim() ?? '';
            return surname.isNotEmpty ? '$name $surname' : name;
          })
          .where((e) => e.isNotEmpty)
          .toList();
      if (values.isNotEmpty) {
        _clientsCache = values;
        await MetadataCacheService.saveStringList(MetadataCacheService.keyClients, values);
      }
    } catch (_) {}
    return _clientsCache ?? const [];
  }

  Future<List<String>> loadFolders() async {
    if (_foldersCache != null && _foldersCache!.isNotEmpty) return _foldersCache!;
    final local = await MetadataCacheService.loadStringList(MetadataCacheService.keyFolders);
    if (local != null && local.isNotEmpty) {
      _foldersCache = local;
      return _foldersCache!;
    }
    _foldersCache = ['Personal', 'Office', 'Freelance'];
    await MetadataCacheService.saveStringList(MetadataCacheService.keyFolders, _foldersCache!);
    return _foldersCache!;
  }

  Future<List<String>> loadProjects() async {
    if (_projectsCache != null && _projectsCache!.isNotEmpty) return _projectsCache!;
    final local = await MetadataCacheService.loadStringList(MetadataCacheService.keyProjects);
    if (local != null && local.isNotEmpty) {
      _projectsCache = local;
    }
    try {
      final snap =
          await FirebaseFirestore.instance.collection('projects').get();
      final values = snap.docs
          .map((d) => d['projectName']?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
      if (values.isNotEmpty) {
        _projectsCache = values;
        await MetadataCacheService.saveStringList(MetadataCacheService.keyProjects, values);
      }
    } catch (_) {}
    return _projectsCache ?? const [];
  }

  String? metadataCreatorName(Map<String, dynamic>? createdBy) {
    if (createdBy == null) return null;
    for (final key in [
      'name',
      'displayName',
      'fullName',
      'userName',
      'cpName',
    ]) {
      final value = createdBy[key]?.toString().trim();
      if (value != null &&
          value.isNotEmpty &&
          value.toLowerCase() != 'user' &&
          value.toLowerCase() != 'unknown') {
        return value;
      }
    }
    return null;
  }

  String? creatorEmailName(Map<String, dynamic>? createdBy) {
    final email = createdBy?['email']?.toString().trim() ?? '';
    if (email.isEmpty) return null;
    return email.contains('@') ? email.split('@').first : email;
  }

  Future<String?> loadCreatorName(Map<String, dynamic>? createdBy) async {
    final metaName = metadataCreatorName(createdBy);
    if (metaName != null) return metaName;

    if (createdBy == null) return null;
    final uid = createdBy['uid']?.toString().trim() ?? '';
    final email = createdBy['email']?.toString().trim() ?? '';
    final users = FirebaseFirestore.instance.collection('users');

    if (uid.isNotEmpty) {
      final profile = await users.where('uid', isEqualTo: uid).limit(1).get();
      if (profile.docs.isNotEmpty) {
        final profileName = _profileName(profile.docs.first.data());
        if (profileName != null) return profileName;
      }

      final profileById = await users.doc(uid).get();
      final profileName = _profileName(profileById.data());
      if (profileName != null) return profileName;
    }

    if (email.isNotEmpty) {
      final profile =
          await users.where('email', isEqualTo: email).limit(1).get();
      if (profile.docs.isNotEmpty) {
        return _profileName(profile.docs.first.data());
      }
    }
    return null;
  }

  String? _profileName(Map<String, dynamic>? profile) {
    if (profile == null) return null;
    for (final key in [
      'name',
      'displayName',
      'fullName',
      'userName',
      'cpName',
    ]) {
      final value = profile[key]?.toString().trim();
      if (value != null &&
          value.isNotEmpty &&
          value.toLowerCase() != 'user' &&
          value.toLowerCase() != 'unknown') {
        return value;
      }
    }
    return null;
  }
}
