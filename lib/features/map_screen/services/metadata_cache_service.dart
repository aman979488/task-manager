import 'package:shared_preferences/shared_preferences.dart';

class MetadataCacheService {
  const MetadataCacheService._();

  static const String keyClients = 'cached_clients';
  static const String keyWorkTypes = 'cached_work_types';
  static const String keyProjects = 'cached_projects';
  static const String keyAssignees = 'cached_assignees';
  static const String keyFolders = 'cached_folders';

  static Future<void> saveStringList(String key, List<String> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(key, list);
    } catch (_) {}
  }

  static Future<List<String>?> loadStringList(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(key);
    } catch (_) {
      return null;
    }
  }
}
