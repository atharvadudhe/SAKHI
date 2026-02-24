import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/theme.dart';
import 'config/router.dart';
import 'config/constants.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait mode (skip on web)
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  // Initialize Firebase
  bool firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // ── Local Emulator (only in debug builds) ────────────────────────────
    if (kDebugMode) {
      // Override with: --dart-define=EMULATOR_HOST=192.168.x.x
      // Default '10.0.2.2' works for Android emulator → host machine.
      const String host = String.fromEnvironment(
        'EMULATOR_HOST',
        defaultValue: kIsWeb ? 'localhost' : '10.0.2.2',
      );
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    }
    // ─────────────────────────────────────────────────────────────────────

    // Initialize push notifications
    await NotificationService.instance.initialize();
    firebaseReady = true;
  } catch (e, st) {
    debugPrint('Firebase init error: $e\n$st');
  }

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
