import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/call_log_model.dart';
import '../models/contact_model.dart';
import '../utils/date_label_utils.dart';
import '../utils/phone_utils.dart';
import '../utils/demo_data.dart';

const _callLogChannel = MethodChannel('task_manager/call_history');

class CallLogController extends ChangeNotifier {
  List<CallLogModel> _logs = [];
  bool isLoading = true;
  bool permissionDenied = false;
  String? loadError;

  List<CallLogModel> get logs => _logs;

  Future<void> loadRecent() async {
    isLoading = true;
    permissionDenied = false;
    loadError = null;
    notifyListeners();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _logs = [
        for (final contact in DemoData.contacts)
          ...DemoData.callLogsFor(contact),
      ]..sort((a, b) => b.time.compareTo(a.time));
      isLoading = false;
      notifyListeners();
      return;
    }

    final entries = await _loadDeviceEntries();
    if (entries == null) return;
    _logs = entries.map(CallLogModel.fromMap).toList()
      ..sort((a, b) => b.time.compareTo(a.time));
    isLoading = false;
    notifyListeners();
  }

  /// Day label -> calls of that day, newest first.
  Map<String, List<CallLogModel>> get groupedLogs {
    final map = <String, List<CallLogModel>>{};
    for (final log in _logs) {
      map.putIfAbsent(DateLabelUtils.dayLabel(log.time), () => []).add(log);
    }
    return map;
  }

  Future<void> loadFor(ContactModel contact) async {
    isLoading = true;
    permissionDenied = false;
    loadError = null;
    notifyListeners();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _logs = DemoData.callLogsFor(contact);
      isLoading = false;
      notifyListeners();
      return;
    }

    final wanted = contact.phoneNumbers
        .map(PhoneUtils.normalize)
        .where((n) => n.isNotEmpty)
        .toSet();

    final entries = await _loadDeviceEntries();
    if (entries == null) return;

    _logs =
        entries
            .where(
              (entry) => wanted.contains(
                PhoneUtils.normalize(entry['number'] as String? ?? ''),
              ),
            )
            .map(CallLogModel.fromMap)
            .toList()
          ..sort((a, b) => b.time.compareTo(a.time));

    isLoading = false;
    notifyListeners();
  }

  Future<List<Map<Object?, Object?>>?> _loadDeviceEntries() async {
    try {
      final entries = await _callLogChannel
          .invokeListMethod<Map<Object?, Object?>>('getRecentCalls');
      return entries ?? const [];
    } on PlatformException catch (error) {
      isLoading = false;
      if (error.code == 'PERMISSION_NOT_GRANTED' ||
          error.code == 'MISSING_PERMISSIONS') {
        permissionDenied = true;
      } else {
        loadError = error.message ?? 'Could not load call history.';
      }
      notifyListeners();
      return null;
    }
  }

  Future<void> openCallLogSettings() =>
      _callLogChannel.invokeMethod<void>('openCallLogSettings');
}
