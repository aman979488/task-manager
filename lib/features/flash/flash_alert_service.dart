import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../routes/app_router.dart';
import 'flash_alert_screen.dart';
import 'flash_native_bridge.dart';

const kFlashOption = '⚡ Flash message';

class Staff {
  const Staff(this.uid, this.name, this.email);

  final String uid;
  final String name;
  final String email;
}

class FlashTemplate {
  const FlashTemplate({required this.label, required this.text});

  final String label;
  final String text;
}

class FlashDraft {
  const FlashDraft({
    required this.recipient,
    required this.text,
    this.sendAt,
    this.taskId,
    this.templateLabel,
    this.notificationTiming,
  });

  final Staff recipient;
  final String text;
  final DateTime? sendAt;
  final String? taskId;
  final String? templateLabel;
  final String? notificationTiming;

  FlashDraft copyWith({String? taskId}) => FlashDraft(
    recipient: recipient,
    text: text,
    sendAt: sendAt,
    taskId: taskId ?? this.taskId,
    templateLabel: templateLabel,
    notificationTiming: notificationTiming,
  );
}

class _IncomingFlash {
  const _IncomingFlash(this.id, this.senderName, this.text);

  final String id;
  final String senderName;
  final String text;
}

class FlashAlertService {
  FlashAlertService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const defaultTemplates = [
    FlashTemplate(
      label: 'Flash call',
      text: 'Please call me when you are free.',
    ),
    FlashTemplate(
      label: 'Work update',
      text: 'Work update: I am working on it.',
    ),
    FlashTemplate(
      label: 'Finished',
      text: 'Work update: The task is finished.',
    ),
    FlashTemplate(
      label: 'In process',
      text: 'Work update: This task is in progress.',
    ),
    FlashTemplate(
      label: 'Will take time',
      text: 'Work update: This will take more time.',
    ),
    FlashTemplate(
      label: 'Forgot',
      text: 'I forgot about this. I will follow up shortly.',
    ),
  ];

  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _deliveredSubscription;
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _scheduledSubscription;
  static final List<_IncomingFlash> _queue = [];
  static final Set<String> _pendingNotificationIds = {};
  static final Map<String, Timer> _scheduledTimers = {};
  static final Map<String, int> _scheduledTimes = {};
  static bool _showing = false;
  static String? _currentId;
  static OverlayEntry? _currentEntry;
  static Timer? _overlayRetryTimer;
  static String? _activeUid;
  static const Duration _maxTimerDelay = Duration(days: 20);

  static Future<List<Staff>> loadStaff({
    String? excludingUid,
    String? excludingEmail,
  }) async {
    final snapshot = await _db.collection('users').get();
    final byIdentity = <String, Staff>{};
    final canonicalIdentity = <String, bool>{};
    final excludedEmail = excludingEmail?.trim().toLowerCase();
    for (final document in snapshot.docs) {
      final data = document.data();
      if (!data.containsKey('role')) continue;
      final profileUid = data['uid']?.toString().trim();
      final uid = profileUid == null || profileUid.isEmpty
          ? document.id
          : profileUid;
      final email = (data['email'] ?? '').toString().trim();
      final normalizedEmail = email.toLowerCase();
      final name = (data['name'] ?? data['fullName'] ?? data['email'] ?? '')
          .toString()
          .trim();
      if (uid.isEmpty ||
          name.isEmpty ||
          (excludingUid != null && uid == excludingUid) ||
          (excludedEmail != null &&
              excludedEmail.isNotEmpty &&
              normalizedEmail == excludedEmail)) {
        continue;
      }
      final identity = normalizedEmail.isEmpty ? 'uid:$uid' : normalizedEmail;
      final isCanonical = document.id == uid;
      if (!byIdentity.containsKey(identity) ||
          (isCanonical && canonicalIdentity[identity] != true)) {
        byIdentity[identity] = Staff(uid, name, email);
        canonicalIdentity[identity] = isCanonical;
      }
    }
    final staff = byIdentity.values.toList()
      ..sort(
        (first, second) =>
            first.name.toLowerCase().compareTo(second.name.toLowerCase()),
      );
    return staff;
  }

  static Future<List<FlashTemplate>> loadTemplates() async {
    try {
      final snapshot = await _db.collection('flashTemplates').get();
      final templates = <FlashTemplate>[...defaultTemplates];
      final existingTexts = defaultTemplates
          .map((template) => template.text.toLowerCase())
          .toSet();
      for (final document in snapshot.docs) {
        final data = document.data();
        final text = data['text']?.toString().trim() ?? '';
        if (text.isEmpty || !existingTexts.add(text.toLowerCase())) continue;
        final label = (data['label'] ?? data['title'] ?? text)
            .toString()
            .trim();
        templates.add(
          FlashTemplate(label: label.isEmpty ? text : label, text: text),
        );
      }
      return templates;
    } on FirebaseException catch (error) {
      debugPrint('Could not load flash message templates: $error');
      return defaultTemplates;
    }
  }

  static Future<void> send(
    FlashDraft draft, {
    required String senderUid,
    required String senderName,
  }) async {
    final text = draft.text.trim();
    if (senderUid.trim().isEmpty) {
      throw StateError('Sign in before sending a flash message.');
    }
    if (draft.recipient.uid.trim().isEmpty || text.isEmpty) {
      throw ArgumentError('A recipient and message are required.');
    }

    final sendAt = draft.sendAt;
    final scheduled = sendAt != null && sendAt.isAfter(DateTime.now());
    await _db.collection('flashMessages').add({
      'senderUid': senderUid,
      'senderName': senderName,
      'recipientUid': draft.recipient.uid,
      'recipientName': draft.recipient.name,
      'recipientEmail': draft.recipient.email,
      'text': text,
      'taskId': draft.taskId,
      'sendAt': scheduled
          ? Timestamp.fromDate(sendAt)
          : FieldValue.serverTimestamp(),
      'status': scheduled ? 'scheduled' : 'delivered',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static void start(String uid) {
    stop(clearPendingNotificationIds: false);
    if (uid.trim().isEmpty) return;
    _activeUid = uid;
    for (final flashId in _pendingNotificationIds.toList()) {
      unawaited(_enqueueFlashFromNotification(flashId, uid));
    }

    _deliveredSubscription = _db
        .collection('flashMessages')
        .where('recipientUid', isEqualTo: uid)
        .where('status', isEqualTo: 'delivered')
        .snapshots()
        .listen(
          (snapshot) {
            for (final change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.removed) continue;
              final data = change.doc.data();
              if (data == null) continue;
              _enqueueIncoming(
                _IncomingFlash(
                  change.doc.id,
                  (data['senderName'] ?? 'Someone').toString(),
                  (data['text'] ?? '').toString(),
                ),
              );
            }
          },
          onError: (Object error) {
            debugPrint('Delivered flash listener failed for $uid: $error');
          },
        );

    _scheduledSubscription = _db
        .collection('flashMessages')
        .where('recipientUid', isEqualTo: uid)
        .where('status', isEqualTo: 'scheduled')
        .snapshots()
        .listen(
          (snapshot) {
            for (final change in snapshot.docChanges) {
              final id = change.doc.id;
              if (change.type == DocumentChangeType.removed) {
                _cancelScheduledTimer(id);
                continue;
              }
              final sendAt = change.doc.data()?['sendAt'];
              if (sendAt is! Timestamp) {
                debugPrint(
                  'Scheduled flash $id has no valid sendAt timestamp.',
                );
                _cancelScheduledTimer(id);
                continue;
              }
              _scheduleDelivery(id, sendAt);
            }
          },
          onError: (Object error) {
            debugPrint('Scheduled flash listener failed for $uid: $error');
          },
        );
  }

  static void stop({bool clearPendingNotificationIds = true}) {
    unawaited(_deliveredSubscription?.cancel());
    unawaited(_scheduledSubscription?.cancel());
    _deliveredSubscription = null;
    _scheduledSubscription = null;
    for (final timer in _scheduledTimers.values) {
      timer.cancel();
    }
    _scheduledTimers.clear();
    _scheduledTimes.clear();
    _overlayRetryTimer?.cancel();
    _overlayRetryTimer = null;
    if (clearPendingNotificationIds) _pendingNotificationIds.clear();
    _activeUid = null;
    _currentEntry?.remove();
    _currentEntry = null;
    _queue.clear();
    _showing = false;
    _currentId = null;
  }

  static void _scheduleDelivery(String id, Timestamp sendAt) {
    final sendAtMillis = sendAt.millisecondsSinceEpoch;
    if (_scheduledTimes[id] == sendAtMillis &&
        _scheduledTimers.containsKey(id)) {
      return;
    }

    _scheduledTimers.remove(id)?.cancel();
    _scheduledTimes[id] = sendAtMillis;
    final remaining = sendAtMillis - DateTime.now().millisecondsSinceEpoch;
    final delay = remaining <= 0
        ? Duration.zero
        : remaining > _maxTimerDelay.inMilliseconds
        ? _maxTimerDelay
        : Duration(milliseconds: remaining);

    late final Timer timer;
    timer = Timer(delay, () {
      if (identical(_scheduledTimers[id], timer)) {
        _scheduledTimers.remove(id);
      }
      unawaited(_deliverScheduled(id, sendAtMillis));
    });
    _scheduledTimers[id] = timer;
  }

  static Future<void> _deliverScheduled(String id, int expectedSendAt) async {
    final activeUid = _activeUid;
    if (activeUid == null || _scheduledTimes[id] != expectedSendAt) return;

    try {
      final document = await _db.collection('flashMessages').doc(id).get();
      if (_activeUid != activeUid || _scheduledTimes[id] != expectedSendAt) {
        return;
      }
      if (!document.exists) {
        _cancelScheduledTimer(id);
        return;
      }

      final data = document.data();
      final sendAt = data?['sendAt'];
      if (data?['status'] != 'scheduled' ||
          data?['recipientUid'] != activeUid ||
          sendAt is! Timestamp) {
        _cancelScheduledTimer(id);
        return;
      }

      if (sendAt.millisecondsSinceEpoch != expectedSendAt) {
        _scheduleDelivery(id, sendAt);
        return;
      }
      if (sendAt.toDate().isAfter(DateTime.now())) {
        _scheduleDelivery(id, sendAt);
        return;
      }

      _scheduledTimers.remove(id)?.cancel();
      await document.reference.update({'status': 'delivered'});
      _scheduledTimes.remove(id);
    } on FirebaseException catch (error) {
      debugPrint('Could not deliver scheduled flash $id: $error');
      _scheduleRetry(id, expectedSendAt);
    } catch (error) {
      debugPrint('Unexpected error delivering scheduled flash $id: $error');
      _scheduleRetry(id, expectedSendAt);
    }
  }

  static void _scheduleRetry(String id, int expectedSendAt) {
    if (_activeUid == null || _scheduledTimes[id] != expectedSendAt) return;
    _scheduledTimers.remove(id)?.cancel();

    late final Timer timer;
    timer = Timer(const Duration(minutes: 1), () {
      if (identical(_scheduledTimers[id], timer)) {
        _scheduledTimers.remove(id);
      }
      unawaited(_deliverScheduled(id, expectedSendAt));
    });
    _scheduledTimers[id] = timer;
  }

  static void _cancelScheduledTimer(String id) {
    _scheduledTimers.remove(id)?.cancel();
    _scheduledTimes.remove(id);
  }

  static Future<void> openFlashNotification(String flashId) async {
    final id = flashId.trim();
    if (id.isEmpty) return;
    final activeUid = _activeUid;
    if (activeUid == null) {
      _pendingNotificationIds.add(id);
      return;
    }
    await _enqueueFlashFromNotification(id, activeUid);
  }

  static Future<void> _enqueueFlashFromNotification(
    String flashId,
    String activeUid,
  ) async {
    _pendingNotificationIds.remove(flashId);
    final document = await _db.collection('flashMessages').doc(flashId).get();
    if (_activeUid != activeUid || !document.exists) return;
    final data = document.data();
    if (data == null ||
        data['recipientUid'] != activeUid ||
        data['status'] != 'delivered') {
      return;
    }
    _enqueueIncoming(
      _IncomingFlash(
        document.id,
        (data['senderName'] ?? 'Someone').toString(),
        (data['text'] ?? '').toString(),
      ),
    );
  }

  static void _enqueueIncoming(_IncomingFlash message) async {
    if (message.id == _currentId ||
        _queue.any((item) => item.id == message.id)) {
      return;
    }

    final isLocked = await FlashNativeBridge.isDeviceLocked();
    if (isLocked) {
      await FlashNativeBridge.showNativeFlashAlert(
        flashId: message.id,
        senderName: message.senderName,
        text: message.text,
      );
      return;
    }

    _queue.add(message);
    _showNext();
  }

  static void _showNext() {
    if (_showing || _queue.isEmpty) return;
    final overlay = AppRouter.rootNavigatorKey.currentState?.overlay;
    if (overlay == null) {
      _overlayRetryTimer ??= Timer(const Duration(milliseconds: 250), () {
        _overlayRetryTimer = null;
        _showNext();
      });
      return;
    }

    final message = _queue.removeAt(0);
    _showing = true;
    _currentId = message.id;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => FlashAlertScreen(
        senderName: message.senderName,
        text: message.text,
        onRespond: ({response, responseText}) async {
          final update = <String, Object>{
            'status': 'seen',
            'seenAt': FieldValue.serverTimestamp(),
          };
          if (response != null) {
            update['response'] = response;
            update['respondedAt'] = FieldValue.serverTimestamp();
            if (responseText != null) update['responseText'] = responseText;
          }
          await _db.collection('flashMessages').doc(message.id).update(update);
          entry.remove();
          _currentEntry = null;
          _showing = false;
          _currentId = null;
          _showNext();
        },
      ),
    );
    _currentEntry = entry;
    overlay.insert(entry);
  }
}
