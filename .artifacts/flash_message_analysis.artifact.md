# Flash Messaging System - Architectural Analysis & Review

This document provides a thorough analysis of the Flash Messaging and Alert system implemented in the Task Manager application.

---

## 1. System Architecture Overview
The flash messaging system enables real-time, high-priority emergency or direct alerts between staff members. It spans both client-side Flutter services and server-side Firebase Cloud Functions.

```
[ FlashComposeSheet ] ──(Create)──> [ Firestore: flashMessages ]
                                         │
                   ┌─────────────────────┴─────────────────────┐
                   ▼                                           ▼
      [ Firestore Realtime Stream ]                [ Cloud Functions (v2) ]
                   │                                           │
         (FlashAlertService.start)                ┌────────────┴────────────┐
                   │                              ▼                         ▼
                   ▼                       [ flashScheduler ]        [ flashPush ]
        [ Overlay Alert / Popup ]           (Scheduled delivery)      (FCM Push Alert)
        (FlashAlertScreen)
```

---

## 2. Client-Side Implementation Analysis (`FlashAlertService`)

### A. Core Components
- **`Staff` & `FlashDraft` Data Models**: Encapsulate recipient information, message text, optional schedule timestamp (`sendAt`), and linked task ID (`taskId`).
- **Real-Time Streams (`start` & `stop`)**:
  - Automatically listens to Firestore's `flashMessages` collection filtered by `recipientUid` where `status == 'delivered'`.
  - Maintains an internal FIFO queue (`_queue`) and displays alerts sequentially via an Overlay (`FlashAlertScreen`) to prevent UI overlap.
- **Scheduled Messages Management**:
  - Listens to messages with `status == 'scheduled'`.
  - Uses Dart `Timer` instances (`_scheduledTimers`) with smart delay bounds (`_maxTimerDelay`) to trigger local delivery upon reaching `sendAt`.
  - Includes retry mechanisms (`_scheduleRetry`) for network resilience.
- **Seen Status Tracking**: Upon dismissing an alert (`onDismiss`), the service automatically updates Firestore (`status: 'seen'`, `seenAt: serverTimestamp()`).

---

## 3. Server-Side Cloud Functions (`functions/index.js`)

- **`flashScheduler` (Scheduled Cron)**: Runs every 1 minute to check for pending scheduled flash messages where `status == 'scheduled'` and `sendAt <= now`, batch-updating their status to `delivered`.
- **`flashPush` (Firestore Trigger)**: Triggers on document writes to `flashMessages/{id}` when `status` changes to `delivered`, automatically sending an high-priority FCM push notification to the recipient's registered device token.

---

## 4. UI Layer Analysis

- **`FlashComposeSheet` (`lib/features/flash/flash_compose_sheet.dart`)**:
  - Allows selecting a staff member, choosing from quick templates or typing custom text, and optionally picking a future delivery date/time.
- **`FlashAlertScreen` (`lib/features/flash/flash_alert_screen.dart`)**:
  - Renders an attention-grabbing, immersive alert overlay when a new flash message arrives.

---

## 5. Summary & Recommendations
- **Strengths**: The dual approach (Firestore real-time streams for active app sessions + Cloud Functions/FCM push for background delivery) ensures that staff members never miss critical alerts.
- **Best Practices Observed**: Clean separation of concerns, proper stream subscription cancellation in `stop()`, robust timer management, and automated Firestore status progression (`scheduled` ➔ `delivered` ➔ `seen`).
