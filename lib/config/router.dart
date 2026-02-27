import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/platform_helper.dart';
import '../screens/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/otp_screen.dart';
import '../screens/auth/email_login_screen.dart';
import '../screens/auth/profile_setup_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/session/active_session_screen.dart';
import '../screens/session/volunteer_dashboard_screen.dart';
import '../screens/broadcast/broadcast_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/contacts/emergency_contacts_screen.dart';
import '../screens/location/location_sharing_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/safety_tools/fake_call_screen.dart';
import '../screens/safety_tools/virtual_companion_setup.dart';
import '../screens/safety_tools/active_companion_screen.dart';
import '../screens/safety_tools/pin_setup_screen.dart';
import '../screens/safety_tools/camouflage_screen.dart';
import '../screens/profile/volunteer_verification_screen.dart';
import '../screens/walking_buddy/destination_search_screen.dart';
import '../screens/walking_buddy/location_confirmation_screen.dart';
import '../screens/walking_buddy/volunteer_selection_screen.dart';
import '../screens/walking_buddy/active_walking_session_screen.dart';
import '../screens/walking_buddy/volunteer_dashboard_screen.dart';
import '../models/walking_buddy_models.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  debugLogDiagnostics: true,
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/login',
      builder: (context, state) {
        // On Web/Desktop, skip the phone login and show email login directly.
        if (isWebOrDesktop) return const EmailLoginScreen();
        return const LoginScreen();
      },
    ),
    GoRoute(
      path: '/otp',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return OtpScreen(
          verificationId: extra['verificationId'] as String? ?? '',
          phoneNumber: extra['phoneNumber'] as String? ?? '',
        );
      },
    ),
    GoRoute(
      path: '/email-login',
      builder: (context, state) => const EmailLoginScreen(),
    ),
    GoRoute(
      path: '/profile-setup',
      builder: (context, state) => const ProfileSetupScreen(),
    ),
    GoRoute(
      path: '/home',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    ),
    GoRoute(
      path: '/session',
      builder: (context, state) => const ActiveSessionScreen(),
    ),
    GoRoute(
      path: '/volunteer',
      builder: (context, state) => const VolunteerDashboardScreen(),
    ),
    GoRoute(
      path: '/broadcast',
      builder: (context, state) => const BroadcastScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/emergency-contacts',
      builder: (context, state) => const EmergencyContactsScreen(),
    ),
    GoRoute(
      path: '/location-sharing',
      builder: (context, state) => const LocationSharingScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) {
        // Guard: Admin Dashboard is only available on Web / Desktop.
        if (!isWebOrDesktop) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.block_rounded, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Admin Dashboard is only available on Desktop.',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        return const AdminDashboardScreen();
      },
    ),
    GoRoute(
      path: '/fake-call',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return FakeCallScreen(
          callerName: extra['callerName'] as String? ?? 'Mom',
          callerLabel: extra['callerLabel'] as String? ?? 'Mobile',
        );
      },
    ),
    GoRoute(
      path: '/virtual-companion-setup',
      builder: (context, state) => const VirtualCompanionSetupScreen(),
    ),
    GoRoute(
      path: '/active-companion',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return ActiveCompanionScreen(
          destination: extra['destination'] as String? ?? 'Unknown',
          durationMinutes: extra['durationMinutes'] as int? ?? 30,
        );
      },
    ),
    GoRoute(
      path: '/pin-setup',
      builder: (context, state) => const PinSetupScreen(),
    ),
    GoRoute(
      path: '/volunteer-verification',
      builder: (context, state) => const VolunteerVerificationScreen(),
    ),
    GoRoute(
      path: '/camouflage',
      builder: (context, state) => const CamouflageScreen(),
    ),

    // ──────── Walking Buddy Routes ────────
    GoRoute(
      path: '/walking-buddy/search-destination',
      builder: (context, state) => const DestinationSearchScreen(),
    ),
    GoRoute(
      path: '/walking-buddy/location-confirmation',
      builder: (context, state) {
        final extra = state.extra as DestinationModel?;
        if (extra == null) {
          return const Scaffold(
            body: Center(child: Text('No destination provided')),
          );
        }
        return LocationConfirmationScreen(destination: extra);
      },
    ),
    GoRoute(
      path: '/walking-buddy/volunteer-selection',
      builder: (context, state) {
        final extra = state.extra as String?;
        if (extra == null) {
          return const Scaffold(
            body: Center(child: Text('No session ID provided')),
          );
        }
        return VolunteerSelectionScreen(sessionId: extra);
      },
    ),
    GoRoute(
      path: '/walking-buddy/waiting-for-user-confirm',
      builder: (context, state) {
        final extra = state.extra as String?;
        if (extra == null) {
          return const Scaffold(
            body: Center(child: Text('No session ID provided')),
          );
        }
        return WaitingForUserConfirmScreen(sessionId: extra);
      },
    ),
    GoRoute(
      path: '/walking-buddy/active-session',
      builder: (context, state) {
        final extra = state.extra as String?;
        if (extra == null) {
          return const Scaffold(
            body: Center(child: Text('No session ID provided')),
          );
        }
        return ActiveWalkingSessionScreen(sessionId: extra);
      },
    ),
    GoRoute(
      path: '/walking-buddy/volunteer-dashboard',
      builder: (context, state) => const VolunteerDashboardWalkingBuddyScreen(),
    ),
    GoRoute(
      path: '/walking-buddy/volunteer-active',
      builder: (context, state) {
        final extra = state.extra as String?;
        if (extra == null) {
          return const Scaffold(
            body: Center(child: Text('No session ID provided')),
          );
        }
        return VolunteerActiveSessionScreen(sessionId: extra);
      },
    ),
  ],
);
