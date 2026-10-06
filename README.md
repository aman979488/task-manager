# task_manager

## Mobile push notifications

The task screen opens without requiring a staff login. Mobile push notifications are registered for a Firebase-authenticated staff account. To configure staff push on a device:

1. In Firebase Console for `task-14733`, enable **Authentication > Sign-in method > Email/Password**.
2. Staff accounts must be created and managed through Firebase Authentication and the `users` collection.
3. On the staff phone, allow notifications when prompted. The app saves the FCM token to that staff's `users` document.
4. Install and sign in to the Firebase CLI (`npm install -g firebase-tools`, then `firebase login`) and deploy the notification sender from the repository root:

   ```powershell
   cd functions
   npm install
   cd ..
   firebase deploy --only functions --project task-14733
   ```

   Cloud Functions deployment requires the Firebase project to use the Blaze plan.
5. For iOS devices, add an APNs authentication key in Firebase Console and enable Push Notifications for the iOS app in Xcode.

The scheduled Cloud Function checks task reminders every minute, including when the app is closed. It writes due reminders and deadline alerts to `notifications`; the document trigger sends them through FCM. The app displays notifications in the system tray when backgrounded and as local notifications while open.

## Android home-screen task widget

Install the Android app, then long-press an empty area of the home screen, open **Widgets**, and add **Task Manager**. The widget shows the pending-task count and up to three pending task titles. It refreshes when tasks are loaded, added, completed, edited, or deleted in the app. Tap the widget to open Task Manager.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
