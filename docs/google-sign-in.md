# Google Sign-In

This document describes the Google sign-in flow currently implemented in the
Task Manager app.

## Where it is implemented

- `lib/main.dart` initializes Firebase and the Google Sign-In SDK before
  creating the app.
- `lib/services/auth_service.dart` handles Google account authentication and
  exchanges the Google ID token for a Firebase credential.
- `lib/viewmodels/auth_viewmodel.dart` signs the user into the app, creates a
  Firestore user profile if needed, and maps sign-in errors to user-facing
  messages.
- `lib/features/auth/login_page.dart` and
  `lib/features/auth/signup_page.dart` both show a **Continue with Google**
  button.

## Sign-in flow

1. The user taps **Continue with Google** on either auth screen.
2. The screen calls `AuthViewModel.signInWithGoogle()`. The button is disabled
   while the operation is in progress.
3. `AuthService.signInWithGoogle()` calls
   `GoogleSignIn.instance.authenticate()`, obtains the Google ID token, creates
   a `GoogleAuthProvider` credential, and signs in with Firebase Authentication.
4. The view model checks Firestore at `users/{uid}`. If that document does not
   exist, it creates one with the user's UID, display name, email, phone number,
   photo URL, and the default `employee` role.
5. The view model loads the profile and registers the device for notifications.
   The auth-state listener and app router then handle the signed-in state.

If a profile already exists, Google sign-in leaves it in place and loads it;
it does not overwrite that profile with Google account fields.

On the signup screen the button is labelled **Sign up with Google**. Google
provides the account's name and email automatically; Firebase creates the
authentication account on the first sign-in. A later Google sign-in uses that
same Firebase account. A phone number may not be provided by Google, so new
profiles store an empty contact number when it is unavailable.

## Cancellation and errors

`AuthViewModel.signInWithGoogle()` returns `true` on success and `false` on
failure. The UI shows a SnackBar for a failure with a non-empty message. When
the user cancels the Google account chooser, the message is empty, so no error
SnackBar is shown.

Other Google sign-in errors display a general failure message. Firebase
network and account-provider errors receive more specific messages. A
Firestore profile-save failure is also reported to the user.

## Firebase and platform setup

- Enable the **Google** provider in Firebase Authentication for the Firebase
  project used by this app.
- Firestore rules allow a signed-in user to create only their own
  `users/{uid}` profile with the `employee` role and the expected profile
  fields. This is required for first-time Google signup and email signup; users
  cannot assign themselves an elevated role. Existing-user profile reads and
  updates remain governed by the normal user-profile rules.
- Keep the Google OAuth client configuration consistent with the Firebase
  project and app identifiers.
- Android builds use `android/app/google-services.json` and the Google
  Services Gradle plugin. If signing configuration changes, ensure the
  appropriate Android signing certificate fingerprints are registered in
  Firebase.
- `google_sign_in` is a direct dependency in `pubspec.yaml`; its resolved
  package version is recorded in `pubspec.lock`.
- The app initializes `GoogleSignIn.instance` in `lib/main.dart`, before the
  auth service attempts authentication.

OAuth client IDs and signing fingerprints are environment configuration. Do
not copy credentials from another Firebase project into this repository.

## Tests

The auth widget tests check that both auth screens expose the Google sign-in
button. `test/signup_page_test.dart` also checks that a canceled Google sign-in
maps to an empty message and other Google sign-in exceptions map to an error
message. These widget tests do not contact Firebase or perform a real Google
login.
