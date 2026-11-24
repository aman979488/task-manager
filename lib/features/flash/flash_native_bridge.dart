import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class FlashNativeBridge {
  FlashNativeBridge._();

  static const MethodChannel _channel = MethodChannel('task_manager/flash_alert');

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> showNativeFlashAlert({
    required String flashId,
    required String senderName,
    required String text,
  }) async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('showNativeFlashAlert', {
        'flashId': flashId,
        'senderName': senderName,
        'text': text,
      });
    } catch (e) {
      debugPrint('Failed to invoke showNativeFlashAlert: $e');
    }
  }

  static Future<bool> checkOverlayPermission() async {
    if (!isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>('checkOverlayPermission');
      return res ?? true;
    } catch (e) {
      debugPrint('Failed to check overlay permission: $e');
      return true;
    }
  }

  static Future<bool> requestOverlayPermission() async {
    if (!isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>('requestOverlayPermission');
      return res ?? false;
    } catch (e) {
      debugPrint('Failed to request overlay permission: $e');
      return false;
    }
  }

  static Future<bool> isDeviceLocked() async {
    if (!isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('isDeviceLocked');
      return res ?? false;
    } catch (e) {
      return false;
    }
  }
}
