import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/services/network_status_service.dart';

void main() {
  test('NetworkStatusService initializes with default online state and disposes cleanly', () async {
    final service = NetworkStatusService(
      checkInterval: const Duration(seconds: 10),
    );
    expect(service.isOnline, isTrue);
    expect(service.isOffline, isFalse);
    service.dispose();
  });
}
