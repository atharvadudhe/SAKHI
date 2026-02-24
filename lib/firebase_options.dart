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
    if (kIsWeb) return web;
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

  static final FirebaseOptions web = FirebaseOptions(
    apiKey: const String.fromEnvironment('FIREBASE_API_KEY',
        defaultValue: 'AIzaSyDQ5E-P4eCkC2YRR7W1M4bMRYcLuecVMgE'),
    appId: const String.fromEnvironment('FIREBASE_WEB_APP_ID',
        defaultValue: '1:809644915762:android:0faafd6ea6fba055c2902b'),
    messagingSenderId: const String.fromEnvironment(
        'FIREBASE_MESSAGING_SENDER_ID',
        defaultValue: '809644915762'),
    projectId: const String.fromEnvironment('FIREBASE_PROJECT_ID',
        defaultValue: 'sakhi-dc3e3'),
    storageBucket: const String.fromEnvironment('FIREBASE_STORAGE_BUCKET',
        defaultValue: 'sakhi-dc3e3.firebasestorage.app'),
    authDomain: const String.fromEnvironment('FIREBASE_AUTH_DOMAIN',
        defaultValue: 'sakhi-dc3e3.firebaseapp.com'),
  );

  static final FirebaseOptions android = FirebaseOptions(
    apiKey: const String.fromEnvironment('FIREBASE_API_KEY',
        defaultValue: 'AIzaSyDQ5E-P4eCkC2YRR7W1M4bMRYcLuecVMgE'),
    appId: const String.fromEnvironment('FIREBASE_APP_ID',
        defaultValue: '1:809644915762:android:0faafd6ea6fba055c2902b'),
    messagingSenderId: const String.fromEnvironment(
        'FIREBASE_MESSAGING_SENDER_ID',
        defaultValue: '809644915762'),
    projectId: const String.fromEnvironment('FIREBASE_PROJECT_ID',
        defaultValue: 'sakhi-dc3e3'),
    storageBucket: const String.fromEnvironment('FIREBASE_STORAGE_BUCKET',
        defaultValue: 'sakhi-dc3e3.firebasestorage.app'),
  );
}
