import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../routes/app_router.dart';
import 'flash_alert_screen.dart';

const kFlashOption = '⚡ Flash message';

class Staff {
  const Staff(this.uid, this.name, this.email);

  final String uid;
  final String name;
  final String email;
}

class FlashDraft {
  const FlashDraft({
    required this.recipient,
    required this.text,
    this.sendAt,
    this.taskId,
  });

  final Staff recipient;
  final String text;
  final DateTime? sendAt;
  final String? taskId;

  FlashDraft copyWith({String? taskId}) => FlashDraft(
    recipient: recipient,
    text: text,
    sendAt: sendAt,
    taskId: taskId ?? this.taskId,
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
    "I'll be there in 5 minutes.",
    'Have you called the client? Please send me an update.',
  ];

  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _deliveredSubscription;
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _scheduledSubscription;
  static final List<_IncomingFlash> _queue = [];
  static final Map<String, Timer> _scheduledTimers = {};
  static final Map<String, int> _scheduledTimes = {};
  static bool _showing = false;
  static String? _currentId;
  static OverlayEntry? _currentEntry;
  static String? _activeUid;
  static const Duration _maxTimerDelay = Duration(days: 20);

  static Future<List<Staff>> loadStaff({String? excludingUid}) async {
    final snapshot = await _db.collection('users').get();
    final byUid = <String, Staff>{};
    for (final document in snapshot.docs) {
      final data = document.data();
      if (!data.containsKey('role')) continue;
      final uid = (data['uid'] ?? document.id).toString().trim();
      final name = (data['name'] ?? data['fullName'] ?? data['email'] ?? '')
          .toString()
          .trim();
      if (uid.isEmpty ||
          name.isEmpty ||
          (excludingUid != null && uid == excludingUid)) {
        continue;
      }
      byUid.putIfAbsent(
        uid,
        () => Staff(uid, name, (data['email'] ?? '').toString().trim()),
      );
    }
    final staff = byUid.values.toList()
      ..sort(
        (first, second) =>
            first.name.toLowerCase().compareTo(second.name.toLowerCase()),
      );
    return staff;
  }

  static Future<List<String>> loadTemplates() async {
    try {
      final snapshot = await _db.collection('flashTemplates').get();
      final templates = snapshot.docs
          .map((document) => document.data()['text']?.toString().trim() ?? '')
          .where((text) => text.isNotEmpty)
          .toList();
      return templates.isEmpty ? defaultTemplates : templates;
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
    stop();
    if (uid.trim().isEmpty) return;
    _activeUid = uid;

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
              if (change.doc.id == _currentId ||
                  _queue.any((item) => item.id == change.doc.id)) {
                continue;
              }
              _queue.add(
                _IncomingFlash(
                  change.doc.id,
                  (data['senderName'] ?? 'Someone').toString(),
                  (data['text'] ?? '').toString(),
                ),
              );
            }
            _showNext();
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

  static void stop() {
    unawaited(_deliveredSubscription?.cancel());
    unawaited(_scheduledSubscription?.cancel());
    _deliveredSubscription = null;
    _scheduledSubscription = null;
    for (final timer in _scheduledTimers.values) {
      timer.cancel();
    }
    _scheduledTimers.clear();
    _scheduledTimes.clear();
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

  static void _showNext() {
    if (_showing || _queue.isEmpty) return;
    final overlay = AppRouter.rootNavigatorKey.currentState?.overlay;
    if (overlay == null) return;

    final message = _queue.removeAt(0);
    _showing = true;
    _currentId = message.id;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => FlashAlertScreen(
        senderName: message.senderName,
        text: message.text,
        onDismiss: () async {
          entry.remove();
          _currentEntry = null;
          _showing = false;
          _currentId = null;
          try {
            await _db.collection('flashMessages').doc(message.id).update({
              'status': 'seen',
              'seenAt': FieldValue.serverTimestamp(),
            });
          } on FirebaseException catch (error) {
            debugPrint('Could not mark flash message seen: $error');
          }
          _showNext();
        },
      ),
    );
    _currentEntry = entry;
    overlay.insert(entry);
  }
}
