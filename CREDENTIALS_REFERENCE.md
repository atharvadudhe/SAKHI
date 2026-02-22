# SAKHI – Credential Reference

> **NEVER commit real API keys or credentials to version control.**
> All secrets belong in the files listed below, which are git-ignored.

---

## Where credentials go

| Credential | File | Notes |
|---|---|---|
| Firebase config (Android) | `lib/firebase_options.dart` | Uses `--dart-define` env vars at build time |
| Firebase config (Android) | `android/app/google-services.json` | Downloaded from Firebase Console |
| Firebase config (iOS) | `ios/Runner/GoogleService-Info.plist` | Downloaded from Firebase Console |
| Google Maps key (Android) | `android/app/src/main/AndroidManifest.xml` | `com.google.android.geo.API_KEY` meta-data |
| Google Maps key (iOS) | `ios/Runner/AppDelegate.swift` | `GMSServices.provideAPIKey(...)` |

---

## 1. Firebase

Values come from **Firebase Console → Project Settings → General → Your Apps**.

Run `flutterfire configure` to auto-generate `lib/firebase_options.dart`:

```
dart pub global activate flutterfire_cli
flutterfire configure
```

### Required Firebase services

- **Authentication** → enable Phone and/or Email/Password provider
- **Cloud Firestore** → create database (start in test or production mode)
- **Firebase Cloud Messaging** → enabled by default with the SDK

### Credential placeholders

```
FIREBASE_PROJECT_ID        = your-firebase-project-id
FIREBASE_ANDROID_API_KEY   = AIzaSy-xxxxx
FIREBASE_ANDROID_APP_ID    = 1:000000000000:android:xxxxxxxxxxxxxxxx
FIREBASE_MESSAGING_SENDER_ID = 000000000000
FIREBASE_STORAGE_BUCKET    = your-project-id.appspot.com
```

---

## 2. Google Maps

Obtain a key at <https://console.cloud.google.com/apis/credentials>.

Enable these APIs in Google Cloud Console:

- Maps SDK for Android
- Maps SDK for iOS

| Platform | Location |
|---|---|
| Android | `android/app/src/main/AndroidManifest.xml` → `com.google.android.geo.API_KEY` |
| iOS | `ios/Runner/AppDelegate.swift` → `GMSServices.provideAPIKey("KEY")` |

---

## 3. Phone Authentication (Firebase)

No separate API key. Steps:

1. Firebase Console → Authentication → Sign-in method → Phone → **Enable**
2. (Optional) Add test phone numbers for development
3. Register SHA-1 & SHA-256 fingerprints for Android:
   ```
   cd android && ./gradlew signingReport
   ```
   Then add fingerprints in Firebase Console → Project Settings → Android App

---

## 4. `.gitignore` verification

Ensure these entries exist in `.gitignore`:

```
**/google-services.json
**/GoogleService-Info.plist
lib/firebase_options.dart
.env
```

---

## Setup checklist

- [ ] Create Firebase project at <https://console.firebase.google.com>
- [ ] Add Android app (`com.example.sakhi`) → download `google-services.json` → place at `android/app/google-services.json`
- [ ] Add iOS app (`com.example.sakhi`) → download `GoogleService-Info.plist` → place at `ios/Runner/GoogleService-Info.plist`
- [ ] Enable Phone Authentication
- [ ] Enable Cloud Firestore and deploy security rules (`firestore.rules`)
- [ ] Enable Firebase Cloud Messaging
- [ ] Get Google Maps API key → set in `AndroidManifest.xml` and `AppDelegate.swift`
- [ ] Run `flutterfire configure` (generates `lib/firebase_options.dart`)
- [ ] Build: `flutter run --dart-define-from-file=.env` or pass `--dart-define` flags
