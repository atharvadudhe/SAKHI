# SAKHI — Community Safety App

> **Your Trusted Companion** — a cross-platform community safety application that helps users feel safer during travel through real-time monitoring, volunteer assistance, and automated safety triggers.

---

## Core Features

### 1. Walking Buddy System
- Start a safety session before travelling alone.
- Nearby verified volunteers are notified and can accept as your virtual companion.
- Real-time location monitoring throughout the session.
- If the user becomes unresponsive, an automatic SOS workflow triggers.

### 2. Time-Bound Location Sharing
- Share live location for a defined duration.
- Location updates automatically stop when the session ends.
- Throttled GPS updates every 15 seconds to minimize battery drain.

### 3. Community Safety Broadcast
- Send safety alerts to volunteers within a 2 km radius.
- Alert types: Unsafe Area, Suspicious Activity, Need Help, Road Issue.
- Server-side radius calculation via Firestore geohash queries.

### 4. Long-Press SOS
- Persistent SOS button accessible from every screen.
- 1.5-second long-press to activate (prevents accidental triggers).
- Alerts emergency contacts and nearby volunteers instantly.

---

## Tech Stack

| Layer          | Technology                                       |
| -------------- | ------------------------------------------------ |
| Frontend       | Flutter (Dart)                                   |
| State Mgmt     | Riverpod 3.x                                    |
| Navigation     | GoRouter                                         |
| Backend        | Firebase (Auth, Firestore, Cloud Messaging)      |
| Location       | Geolocator + Google Maps Flutter                 |
| Notifications  | Firebase Cloud Messaging (FCM)                   |

---

## Project Structure

```
lib/
├── main.dart                              # App entry point + Firebase init
├── config/
│   ├── theme.dart                         # Light/dark Material 3 themes
│   ├── constants.dart                     # App-wide constants
│   └── router.dart                        # GoRouter route definitions
├── models/
│   ├── user_model.dart                    # User profile model
│   ├── session_model.dart                 # Safety session model
│   └── location_update.dart               # GPS coordinate update model
├── services/
│   ├── auth_service.dart                  # Phone OTP authentication
│   ├── firestore_service.dart             # Firestore CRUD operations
│   ├── location_service.dart              # GPS tracking & permissions
│   └── notification_service.dart          # FCM push notifications
├── providers/
│   └── providers.dart                     # Riverpod state providers
├── widgets/
│   ├── sos_button.dart                    # Long-press SOS with haptics
│   ├── session_status_card.dart           # Color-coded session status
│   └── animated_gradient_bg.dart          # Animated gradient background
└── screens/
    ├── splash_screen.dart                 # Animated splash + auth check
    ├── auth/
    │   ├── login_screen.dart              # Phone number input
    │   ├── otp_screen.dart                # 6-digit OTP verification
    │   └── profile_setup_screen.dart      # Name + role selection
    ├── home/
    │   └── home_screen.dart               # Main dashboard
    ├── session/
    │   ├── active_session_screen.dart     # Live map + timer + SOS
    │   └── volunteer_dashboard_screen.dart# Volunteer request list
    └── broadcast/
        └── broadcast_screen.dart          # Community alert form
```

---

## Getting Started

### Prerequisites
- Flutter SDK `^3.11.0`
- Firebase project (Spark plan is sufficient for prototype)
- Google Maps API key

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/dhairyajangir/SAKHI.git
   cd SAKHI
   ```

2. **Configure Firebase**
   ```bash
   flutterfire configure
   ```

3. **Add Google Maps API key**
   - Android: replace `YOUR_API_KEY_HERE` in `android/app/src/main/AndroidManifest.xml`
   - iOS: add key to `ios/Runner/AppDelegate.swift`

4. **Install dependencies**
   ```bash
   flutter pub get
   ```

5. **Run the app**
   ```bash
   flutter run
   ```

---

## Firestore Data Model

| Collection        | Key Fields                                                         |
| ----------------- | ------------------------------------------------------------------ |
| `users`           | uid, name, phone, role, isAvailable, currentLocation, lastHeartbeat |
| `sessions`        | sessionId, createdBy, status, volunteerId, timeLimit, userLocation  |
| `locationUpdates` | uid, geoPoint, timestamp *(subcollection of sessions)*             |
| `broadcasts`      | uid, message, alertType, location, radiusKm, timestamp             |

Security rules are defined in [`firestore.rules`](firestore.rules) — users can only update their own data, and volunteers can only modify sessions they've accepted.

---

## Development Phases

| Phase | Focus                                         | Status       |
| ----- | --------------------------------------------- | ------------ |
| 1     | Login, Sessions, Volunteer Accept, Live Tracking, Manual SOS | ✅ Built |
| 2     | Heartbeat monitoring, Auto SOS, Radius-based matching        | 🔜 Next  |
| 3     | Battery optimization, Background stability, Offline handling | 📋 Planned |

---

## License

This project is built for hackathon purposes.
