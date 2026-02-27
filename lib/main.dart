import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/theme.dart';
import 'config/router.dart';
import 'config/constants.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/hardware_trigger_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait mode (skip on web)
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  // Initialize Firebase. guard against duplicate initialization which can occur
  // when hot‑restarting in debug or when Firebase auto‑initialises on mobile
  // via the google‑services.json/plugin. `Firebase.apps` will be empty the
  // first time only.
  bool firebaseReady = false;
  print('🚀 APP STARTED');
  // USER printed after auth initialization below
  try {
    if (Firebase.apps.isEmpty) {
      if (kIsWeb) {
        // Web requires explicit options from generated file
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } else {
        // Native platforms pick up configuration from google-services.json
        // / GoogleService-Info.plist automatically, so a plain call is enough.
        await Firebase.initializeApp();
      }
    } else {
      // already initialised (hot restart or prior call), just retrieve it
      Firebase.app();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FIRESTORE EMULATOR SETUP FOR BROADCAST WALKING BUDDY DEBUGGING
    // ═══════════════════════════════════════════════════════════════════════════
    //
    // IMPORTANT: Both emulators (user & volunteer) MUST use the same emulator
    // for proper broadcast testing.
    //
    // ENABLE EMULATORS IN DEBUG MODE:
    // ───────────────────────────────────────────────────────────────────────
    // 1. Uncomment the block below
    // 2. Run: firebase emulators:start --project=YOUR_PROJECT_ID
    // 3. Run both emulators with: flutter run --dart-define=EMULATOR_NEW=true
    //
    // FOR MULTIPLE DEVICES (LAN):
    // ───────────────────────────────────────────────────────────────────────
    // 1. Start emulator on host machine: firebase emulators:start
    // 2. Find your machine's LAN IP: ifconfig | grep inet
    // 3. Run on device: flutter run --dart-define=EMULATOR_HOST=192.168.x.x
    //
    // DEBUGGING BROADCAST REQUESTS:
    // ───────────────────────────────────────────────────────────────────────
    // - User emulator: creates request → should see "Waiting for volunteer..."
    // - Volunteer emulator: enables "Volunteer Mode" → should see request
    // - Both must be authenticated with DIFFERENT Firebase Auth accounts
    // - Both must be using SAME Firebase project/emulator
    // - Check Firestore debugger: should see walkingRequests collection
    // ═══════════════════════════════════════════════════════════════════════════
    
    if (kDebugMode) {
      // UNCOMMENT TO ENABLE EMULATOR
      // const String host = String.fromEnvironment(
      //   'EMULATOR_HOST',
      //   defaultValue: kIsWeb ? 'localhost' : '10.0.2.2',
      // );
      // print('🔥 USING FIREBASE EMULATOR: $host');
      // await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      // FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    }

    // Initialize push notifications
    await NotificationService.instance.initialize();

    // Initialize hardware-button SOS listener (volume-button trigger).
    // This is intentionally fire-and-forget: initialize() is synchronous
    // (void) and sets up an internal stream listener. It handles its own
    // errors internally and does not need to block Firebase readiness.
    HardwareTriggerService.instance.initialize();

    firebaseReady = true;
  } catch (e, st) {
    debugPrint('Firebase init error: $e\n$st');
  }
  print(Firebase.app().options.projectId);
  if (!firebaseReady) {
    // Show a minimal error app so users aren't left on a blank screen
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Failed to initialise Firebase.\nPlease restart the app.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
    return;
  }

  print('🚀 CURRENT USER: ${FirebaseAuth.instance.currentUser?.uid}');
  runApp(const ProviderScope(child: SakhiApp()));
}


class SakhiApp extends StatelessWidget {
  const SakhiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: SakhiTheme.light,
      darkTheme: SakhiTheme.dark,
      themeMode: ThemeMode.light,
      routerConfig: appRouter,
    );
  }
}
