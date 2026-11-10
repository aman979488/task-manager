# Notifications and flash messages

The app has two related but distinct features: task notifications and staff
flash messages.

## For app users

### Task notifications

Tasks can have reminders, deadlines, and additional notification timings.
Allow system notifications on the device to receive alerts. Push notifications
can arrive when the app is in the background; while the app is open, local
notifications are used.

### Flash messages

Send a flash message to another staff member immediately or schedule it for a
future time. Choose a built-in or configured template, or write a message.
Recipients can respond with a preset status or a custom response.

## For developers and administrators

- Task notification settings are stored with each task. The scheduled Cloud
  Function checks due reminders and upcoming deadlines, writes notification
  documents, and the notification trigger sends FCM messages.
- Flash messages are stored in the Firestore `flashMessages` collection.
  Immediate and scheduled messages use statuses that the recipient listener
  processes; responses are saved on the message document.
- Flash templates are loaded from `flashTemplates` and combined with built-in
  defaults.
- The app's mobile push setup, Firebase requirements, and deployment command
  are documented in the root [README](../README.md#mobile-push-notifications).
- Flash behavior is implemented in
  [`flash_alert_service.dart`](../lib/features/flash/flash_alert_service.dart);
  the composition UI is in
  [`flash_compose_sheet.dart`](../lib/features/flash/flash_compose_sheet.dart).
- The scheduled notification sender is in
  [`functions/index.js`](../functions/index.js).

Verify Firebase Authentication, Firestore rules, FCM credentials, and platform
notification setup in the target environment before deploying changes. Never
put service-account credentials or private keys in the repository.

Related: [tasks and weekly goals](tasks-and-goals.md),
[developer guide](developer-guide.md).
