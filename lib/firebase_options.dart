// File generated based on Firebase project: sakhi-dc3e3
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members

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
    apiKey: 'AIzaSyDQ5E-P4eCkC2YRR7W1M4bMRYcLuecVMgE',
    appId: '1:809644915762:android:0faafd6ea6fba055c2902b',
    messagingSenderId: '809644915762',
    projectId: 'sakhi-dc3e3',
    storageBucket: 'sakhi-dc3e3.firebasestorage.app',
  );
}
