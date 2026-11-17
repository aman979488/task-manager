import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_manager/features/map_screen/services/metadata_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('MetadataCacheService saves and retrieves string lists', () async {
    final clients = ['Acme Corp', 'Wayne Enterprises'];
    await MetadataCacheService.saveStringList(
      MetadataCacheService.keyClients,
      clients,
    );

    final retrieved = await MetadataCacheService.loadStringList(
      MetadataCacheService.keyClients,
    );
    expect(retrieved, equals(clients));
  });

  test('MetadataCacheService returns null for uncached keys', () async {
    final retrieved = await MetadataCacheService.loadStringList('non_existing');
    expect(retrieved, isNull);
  });
}
