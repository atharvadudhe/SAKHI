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
  static const String locationSharesCollection = 'locationShares';
  static const String liveLocationsCollection = 'liveLocations';

  // ── Live Tracking Settings ──
  static const int liveTrackingIntervalSec = 10;
  static const int liveTrackingDistanceFilterM = 15;

  // ── API Keys ──
  // This value is injected at build time via dart-define or other config
  // mechanism. Do **not** hardcode your key here in source control.
  static const String googleMapsApiKey = "AIzaSyDWiIGYva-vunfRSb2jun7hx40lFESydX4";
}
