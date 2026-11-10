# Developer guide

This guide summarizes how to run the Flutter app and where its main features
are implemented.

## Requirements and local setup

Install Flutter with the Dart SDK version allowed by
[`pubspec.yaml`](../pubspec.yaml), then from the repository root run:

```powershell
flutter pub get
flutter run
```

Select an available device when prompted or pass its ID with
`flutter run -d <device-id>`. Firebase configuration is required for Firebase-backed
features; use the project's approved local configuration and do not commit
credentials.

## Main areas

| Area | Entry point / implementation |
|---|---|
| Authentication | [`login_page.dart`](../lib/features/auth/login_page.dart), `AuthViewModel` |
| Tasks and goals | [`map_screen.dart`](../lib/features/map_screen/screens/map_screen.dart), task and weekly-goal repositories |
| Contacts and calls | [`all_calls_view.dart`](../lib/features/call_history/screens/all_calls_view.dart), contact and call-log controllers |
| Flash messages | [`flash_alert_service.dart`](../lib/features/flash/flash_alert_service.dart) |
| Navigation | [`app_router.dart`](../lib/routes/app_router.dart), [`app_routes.dart`](../lib/routes/app_routes.dart) |
| Scheduled push delivery | [`functions/index.js`](../functions/index.js) |

Navigation uses `go_router`; the home route provides the task and goals
view-models, and the call-history route provides its call-log controller.
Firestore-backed tasks and goals use repositories under
`lib/features/map_screen/repositories`.

## Validation

Run the relevant tests after a change, or the full Flutter suite when needed:

```powershell
flutter test
flutter analyze
```

Feature-specific tests are under `test/`. Android contacts and call-history
permissions and the platform channel are part of the call-history feature;
verify those changes on an Android device as well as with Dart tests.

For push configuration and deployment instructions, see
[notifications and flash messages](notifications-and-flash-messages.md).
For user-facing task and contacts instructions, see
[tasks and weekly goals](tasks-and-goals.md) and
[contacts and call history](contacts-and-call-history.md).
