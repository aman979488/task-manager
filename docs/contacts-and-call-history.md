# Contacts and call history

This feature provides contact browsing, call history, and call-history
analytics.

## For app users

Open **Call History** to search recent calls and filter by call type or date.
Available call filters include incoming, outgoing, missed, rejected, and other
call outcomes. The screen also provides analytics and export or copy actions.
Open **Contacts** to search contacts, mark favorites, show favorites only, and
sort the list.

On Android, the feature requests access to contacts and call history. Allow the
requested permissions in order to see device data. On platforms without native
call-log support, including web, the screen uses sample/demo data instead of
the device's call history; the browser contacts screen labels its demo data.

## For developers

- The feature is under [`lib/features/call_history`](../lib/features/call_history).
- `ContactController` requests read access using `flutter_contacts`, then maps
  device contacts to the feature model.
- `CallLogController` reads Android call-log entries through the
  `task_manager/call_history` platform channel. Other platforms use demo data.
- The native Android channel and call-log permission handling are in
  [`MainActivity.kt`](../android/app/src/main/kotlin/com/example/task_manager/MainActivity.kt).
- Android permissions are declared in
  [`AndroidManifest.xml`](../android/app/src/main/AndroidManifest.xml).
  iOS contact access has a usage description in
  [`Info.plist`](../ios/Runner/Info.plist).
- The `/call-history` route is declared in
  [`app_routes.dart`](../lib/routes/app_routes.dart) and wired in
  [`app_router.dart`](../lib/routes/app_router.dart).

When changing platform-channel calls, keep the Dart method name, Android
implementation, permission behavior, and error handling in sync. Do not assume
that a native call log is available on iOS or web.

Related: [developer guide](developer-guide.md).
