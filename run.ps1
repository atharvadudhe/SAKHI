# Run SAKHI on Android (emulator — use run-device.ps1 for physical device)
flutter run `
  --dart-define=FIREBASE_API_KEY=AIzaSyDQ5E-P4eCkC2YRR7W1M4bMRYcLuecVMgE `
  --dart-define=FIREBASE_APP_ID=1:809644915762:android:0faafd6ea6fba055c2902b `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=809644915762 `
  --dart-define=FIREBASE_PROJECT_ID=sakhi-dc3e3 `
  --dart-define=FIREBASE_STORAGE_BUCKET=sakhi-dc3e3.firebasestorage.app `
  --dart-define=EMULATOR_HOST=10.0.2.2
