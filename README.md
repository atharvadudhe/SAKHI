# SAKHI — Flutter + Firebase starter

This repo contains a minimal Flutter app scaffold configured for Firebase services (Auth, Firestore, Functions, FCM) and Google Maps. It includes placeholders and instructions to finish platform-specific configuration.

Quick steps

1. Install Flutter and the FlutterFire CLI.

```bash
dart pub global activate flutterfire_cli
```

2. Generate `lib/firebase_options.dart` for your Firebase project:

```bash
flutterfire configure
```

3. Add platform files:
- Android: replace `android/app/google-services.json` with the file downloaded from Firebase Console.
- iOS: replace `ios/Runner/GoogleService-Info.plist` with the file from Firebase Console.

4. Get Dart packages:

```bash
flutter pub get
```

5. Cloud Functions (optional):

```bash
cd functions
npm install
# deploy
firebase deploy --only functions
```

Notes
- The `lib/main.dart` initializes Firebase and sets up a basic FCM background handler. Run `flutterfire configure` to generate the real `DefaultFirebaseOptions` used at startup.
- Replace placeholders with real config files before running on devices.
