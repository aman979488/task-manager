import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

typedef ConnectionChecker = Future<bool> Function();

class NetworkStatusService {
  NetworkStatusService({
    this.checkInterval = const Duration(seconds: 6),
    ConnectionChecker? connectionChecker,
    bool? autoStart,
  }) : _connectionChecker = connectionChecker {
    final shouldStart = autoStart ?? !_isTestEnvironment;
    if (shouldStart) {
      _startMonitoring();
    }
  }
  final Duration checkInterval;
  final ConnectionChecker? _connectionChecker;
  final StreamController<bool> _statusController =
      StreamController<bool>.broadcast();
  Timer? _timer;
  bool _isOnline = true;
  bool _isDisposed = false;

  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;
  Stream<bool> get onStatusChanged => _statusController.stream;

  static bool get _isTestEnvironment {
    if (kIsWeb) return false;
    try {
      return Platform.environment['FLUTTER_TEST'] == 'true';
    } catch (_) {
      return false;
    }
  }

  void _startMonitoring() {
    checkNow();
    _timer = Timer.periodic(checkInterval, (_) => checkNow());
  }

  Future<bool> checkNow() async {
    if (_isDisposed) return _isOnline;
    final online = await _checkConnection();
    if (_isDisposed) return online;
    if (_isOnline != online) {
      _isOnline = online;
      _statusController.add(_isOnline);
    }
    return _isOnline;
  }

  Future<bool> _checkConnection() async {
    if (_connectionChecker != null) {
      return _connectionChecker();
    }
    if (kIsWeb || _isTestEnvironment) return true;
    try {
      final lookup = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    _statusController.close();
  }
}
