import 'dart:async';
import 'dart:ui' show DartPluginRegistrant;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../features/flash/flash_native_bridge.dart';
import '../firebase_options.dart';

const AndroidNotificationChannel _notificationChannel =
    AndroidNotificationChannel(
      'task_notifications',
      'Task notifications',
      description: 'Notifications about assigned tasks and reminders',
      importance: Importance.max,
    );

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  DartPluginRegistrant.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  if (defaultTargetPlatform != TargetPlatform.android ||
      message.data['type'] != 'flash') {
    return;
  }

  final flashId = message.data['flashId']?.toString() ?? '';
  final title = message.data['title']?.toString() ?? 'Flash message';
  final body = message.data['body']?.toString() ?? '';

  if (flashId.isNotEmpty) {
    await FlashNativeBridge.showNativeFlashAlert(
      flashId: flashId,
      senderName: title,
      text: body,
    );
  }
}

class NotificationService {
  NotificationService({this.onFlashNotificationOpened});

  final Future<void> Function(String flashId)? onFlashNotificationOpened;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<String>? _tokenSubscription;

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize() async {
    if (_isMobile) {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _localNotifications.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
      );
      final launchDetails = await _localNotifications
          .getNotificationAppLaunchDetails();
      final launchPayload = launchDetails?.notificationResponse?.payload;
      if (launchDetails?.didNotificationLaunchApp == true &&
          launchPayload != null &&
          launchPayload.isNotEmpty) {
        _handleFlashNotificationOpened(launchPayload);
      }

      final androidNotifications = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidNotifications?.createNotificationChannel(
        _notificationChannel,
      );
    }

    if (!_isMobile) return;

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: false,
          sound: false,
        );

    _messageSubscription = FirebaseMessaging.onMessage.listen(
      _showForegroundNotification,
      onError: (Object error) {
        debugPrint('Foreground notification error: $error');
      },
    );
    _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) await _saveToken(user.uid, token);
      },
      onError: (Object error) {
        debugPrint('FCM token refresh error: $error');
      },
    );
  }

  Future<void> registerDevice(String uid) async {
    if (!_isMobile) return;

    final permission = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (permission.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('Notification permission was denied for $uid.');
      return;
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      debugPrint('FCM did not return a device token for $uid.');
      return;
    }
    await _saveToken(uid, token);

    if (defaultTargetPlatform == TargetPlatform.android) {
      final fullScreenPermission = await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestFullScreenIntentPermission();
      if (fullScreenPermission != true) {
        debugPrint('Full-screen Flash alerts are not enabled for $uid.');
      }
    }
  }

  Future<void> _saveToken(String uid, String token) async {
    final users = FirebaseFirestore.instance.collection('users');
    final userRef = users.doc(uid);
    final user = await userRef.get();
    if (user.exists) {
      await userRef.set({
        'fcmToken': token,
        'fcmTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true));
      return;
    }

    final legacyProfile = await users
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (legacyProfile.docs.isEmpty) {
      throw StateError('No staff profile found for authenticated user $uid.');
    }

    await legacyProfile.docs.first.reference.set({
      'fcmToken': token,
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (!_isMobile) return;
    if (message.data['type'] == 'flash') return;
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      id: message.hashCode,
      title: notification.title ?? 'Task Manager',
      body: notification.body ?? '',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _notificationChannel.id,
          _notificationChannel.name,
          channelDescription: _notificationChannel.description,
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final flashId = response.payload;
    if (flashId == null || flashId.isEmpty) return;
    _handleFlashNotificationOpened(flashId);
  }

  void _handleFlashNotificationOpened(String flashId) {
    final callback = onFlashNotificationOpened;
    if (callback == null) return;
    unawaited(
      callback(flashId).catchError((Object error) {
        debugPrint('Could not open Flash message $flashId: $error');
      }),
    );
  }

  Future<void> dispose() async {
    await _messageSubscription?.cancel();
    await _tokenSubscription?.cancel();
  }
}
