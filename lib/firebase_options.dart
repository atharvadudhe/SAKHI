// File generated based on Firebase project: sakhi-dc3e3
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
//
// Pass credentials at build time with --dart-define or --dart-define-from-file:
//   flutter run \
//     --dart-define=FIREBASE_API_KEY=AIzaSy... \
//     --dart-define=FIREBASE_APP_ID=1:... \
//     --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
//     --dart-define=FIREBASE_PROJECT_ID=... \
//     --dart-define=FIREBASE_STORAGE_BUCKET=...

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Web FirebaseOptions have not been configured. '
        'Add your web app in Firebase Console and update this file.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'iOS FirebaseOptions have not been configured. '
          'Add your iOS app in Firebase Console and update this file.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
    appId: String.fromEnvironment('FIREBASE_APP_ID'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
  );
}
