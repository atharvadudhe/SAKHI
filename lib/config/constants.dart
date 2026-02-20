class AppConstants {
  AppConstants._();

  // ── App Info ──
  static const String appName = 'SAKHI';
  static const String tagline = 'Your Trusted Companion';

  // ── Location Settings ──
  static const int locationUpdateIntervalSec = 15;
  static const int heartbeatIntervalSec = 30;
  static const int heartbeatTimeoutSec = 120;

  // ── Session Settings ──
  static const int sessionSearchTimeoutMin = 5;
  static const int defaultSessionDurationMin = 30;

  // ── Broadcast Settings ──
  static const double broadcastRadiusKm = 2.0;
  static const double volunteerSearchRadiusKm = 5.0;

  // ── Firestore Collections ──
  static const String usersCollection = 'users';
  static const String sessionsCollection = 'sessions';
  static const String locationUpdatesSubcollection = 'locationUpdates';
  static const String broadcastsCollection = 'broadcasts';
}
