# SAKHI — Community Safety App

> **Your Trusted Companion** — a cross-platform women's safety application built with Flutter & Firebase that protects users through real-time monitoring, volunteer assistance, covert SOS triggers, and anti-coercion safeguards.

---

## Features

### 🛡️ Walking Buddy System
- Start a safety session before travelling alone.
- Nearby verified volunteers are notified and can accept as your virtual companion.
- Real-time Google Maps location monitoring throughout the session.
- Heartbeat every 30 seconds — if the user becomes unresponsive, SOS triggers automatically.

### 🆘 Multi-Mode SOS
- **Long-Press SOS Button** — persistent floating button on every screen; 1.5-second hold with haptic feedback prevents accidental triggers.
- **Hardware SOS (Volume Buttons)** — 3 rapid volume-button presses within 3 seconds fires automatic SOS + location broadcast. Works without unlocking the screen.
- **Virtual Companion Auto-SOS** — countdown timer with destination; if the user doesn't confirm arrival, SOS fires at 00:00.

### 📞 Fake Call
- Schedule a realistic fake incoming call (5s / 15s / 1 min delay).
- Full Android dialer UI: ringtone, pulsing avatar, accept/decline, in-call controls (mute, keypad, speaker), live call timer.
- Configurable caller name & label.

### 🔐 Duress PIN (Anti-Coercion)
- Configure a **Safe PIN** (genuinely cancels SOS) and a **Duress PIN** (appears to cancel but silently escalates).
- Duress PIN marks broadcasts as duress-active, keeps the session in SOS state, and continues covert recording — coercion protection.

### 🎙️ Evidence Vault
- Covert audio recording activates automatically during SOS.
- Recordings are SHA-256 hashed for tamper-proofing.
- Uploaded to Firebase Storage; metadata (hash, URL, timestamp) saved in Firestore for chain-of-custody.

### 🚶 Walk With Me (Virtual Companion)
- Set a destination and expected travel duration (15 / 30 / 45 / 60 / 90 min).
- Live countdown with circular progress ring.
- "I've Arrived Safely" button or automatic SOS when the timer expires.

### 📡 Community Safety Broadcast
- Send geo-located safety alerts within a 2 km radius.
- Alert types: Unsafe Area, Suspicious Activity, Need Help, Road Issue.
- Real-time broadcast feed on the home screen.

### 📍 Time-Bound Location Sharing
- Share live GPS location for 15 min / 30 min / 1 hour / 2 hours.
- Auto-expires — no manual cleanup needed.
- Throttled updates (every 15 seconds) to minimize battery drain.

### 👥 Volunteer System
- Role-based onboarding: users choose "Stay Safe" or "Volunteer" at signup.
- **KYC Verification** — government ID upload (front + back) to Firebase Storage; pending/verified/rejected status gates dashboard access.
- Volunteer dashboard with availability toggle, live map of help requests, and accept/decline controls.

### 🖥️ Admin Dashboard (Web-Only)
- **God-Mode Live Map** — all active users, volunteers, and SOS markers color-coded in real time.
- **Live Alerts** — data tables of active sessions and community broadcasts.
- **User Management** — view all users, promote roles (user → volunteer → admin).

### 📇 Emergency Contacts
- CRUD management of trusted contacts (name, phone, relationship).
- Stored in Firestore subcollection under each user profile.

---

## Tech Stack

| Layer          | Technology                                                |
| -------------- | --------------------------------------------------------- |
| Frontend       | Flutter (Dart)                                            |
| State Mgmt     | Riverpod 3.x                                             |
| Navigation     | GoRouter                                                  |
| Backend        | Firebase (Auth, Firestore, Cloud Messaging, Storage)      |
| Maps & Location| Geolocator + Google Maps Flutter                          |
| Notifications  | Firebase Cloud Messaging (FCM)                            |
| Audio Recording| record (AAC-LC via platform codecs)                       |
| Tamper-Proof   | crypto (SHA-256 hashing)                                  |
| Safety Tools   | flutter_ringtone_player, flutter_volume_controller        |

---

## Project Structure

```
lib/
├── main.dart                              # App entry + Firebase init
├── firebase_options.dart                  # Firebase config (build-time env vars)
├── config/
│   ├── theme.dart                         # Material 3 light/dark themes
│   ├── constants.dart                     # App-wide constants & Firestore collection names
│   └── router.dart                        # GoRouter (17 routes)
├── models/
│   ├── user_model.dart                    # User profile (roles, pins, KYC status)
│   ├── session_model.dart                 # Safety session (status, timer, companion)
│   ├── location_update.dart               # GPS coordinate update
│   ├── emergency_contact.dart             # Emergency contact
│   ├── broadcast_model.dart               # Community broadcast alert
│   └── live_location_model.dart           # Real-time tracker (admin map)
├── services/
│   ├── auth_service.dart                  # Phone OTP + Email auth, retry-enabled profile check
│   ├── firestore_service.dart             # All Firestore CRUD (users, sessions, broadcasts, etc.)
│   ├── location_service.dart              # GPS tracking, live Firestore writes, permissions
│   ├── notification_service.dart          # FCM push notifications
│   ├── hardware_trigger_service.dart      # Volume-button SOS detection
│   └── evidence_service.dart              # Covert audio recording + SHA-256 + upload
├── providers/
│   └── providers.dart                     # Riverpod providers + SessionController
├── widgets/
│   ├── sos_button.dart                    # Animated long-press SOS with pulse + progress ring
│   ├── session_status_card.dart           # Color-coded session status card
│   └── animated_gradient_bg.dart          # Animated gradient (splash screen)
└── screens/
    ├── splash_screen.dart                 # Animated splash + role-based routing
    ├── auth/
    │   ├── login_screen.dart              # Phone number login + demo skip
    │   ├── otp_screen.dart                # 6-digit OTP verification
    │   ├── email_login_screen.dart        # Email sign-in / sign-up
    │   └── profile_setup_screen.dart      # Name + role selection
    ├── home/
    │   └── home_screen.dart               # Dashboard, quick actions, alerts feed
    ├── session/
    │   ├── active_session_screen.dart     # Live map + timer + SOS + duress PIN
    │   └── volunteer_dashboard_screen.dart# Volunteer requests + availability
    ├── broadcast/
    │   └── broadcast_screen.dart          # Community alert form
    ├── contacts/
    │   └── emergency_contacts_screen.dart # Emergency contacts CRUD
    ├── location/
    │   └── location_sharing_screen.dart   # Time-bound location sharing
    ├── notifications/
    │   └── notifications_screen.dart      # Broadcast alert feed
    ├── profile/
    │   ├── profile_screen.dart            # User profile + settings
    │   └── volunteer_verification_screen.dart # KYC ID upload
    ├── safety_tools/
    │   ├── fake_call_screen.dart          # Realistic fake call UI
    │   ├── virtual_companion_setup.dart   # Walk With Me setup
    │   ├── active_companion_screen.dart   # Countdown timer + auto-SOS
    │   └── pin_setup_screen.dart          # Safe PIN + Duress PIN config
    └── admin/
        └── admin_dashboard_screen.dart    # Web-only: live map, alerts, user mgmt
```

---

## Firestore Data Model

| Collection                               | Key Fields                                                                                   |
| ---------------------------------------- | -------------------------------------------------------------------------------------------- |
| `users`                                  | uid, name, phone, role, isAvailable, currentLocation, lastHeartbeat, safePin, duressPin, verificationStatus |
| `users/{uid}/emergencyContacts`          | id, name, phone, relationship                                                               |
| `sessions`                               | sessionId, createdBy, status, startTime, endTime, volunteerId, volunteerName, timeLimit, userLocation, destinationLocation, isVirtualCompanionActive |
| `sessions/{id}/locationUpdates`          | uid, geoPoint, timestamp                                                                    |
| `broadcasts`                             | id, uid, userName, message, alertType, location, timestamp, radiusKm, isDuressActive         |
| `locationShares`                         | id, uid, userName, location, createdAt, expiresAt, durationMinutes, isActive                 |
| `liveLocations`                          | uid, userName, role, latitude, longitude, lastUpdatedAt, isActive, trackingReason, sessionId, batteryLevel |
| `session_evidence`                       | sessionId, downloadUrl, sha256Hash, recordedAt, uploadedAt                                   |

Security rules: [`firestore.rules`](firestore.rules) — role-based access; users update only their own data; volunteers modify only assigned sessions; admin has full access.

Composite indexes: [`firestore.indexes.json`](firestore.indexes.json) — 5 indexes for session, broadcast, and location share queries.

---

## Getting Started

### Prerequisites
- Flutter SDK `>=3.35.0`
- Firebase project (Spark plan is sufficient for prototype)
- Google Maps API key
- Firebase CLI (for deploying rules & indexes)

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

3. **Create the Firestore database**
   - Go to Firebase Console → Firestore Database → **Create database**
   - Choose a region and start in **test mode**

4. **Deploy Firestore rules & indexes**
   ```bash
   firebase deploy --only firestore
   ```

5. **Add Google Maps API key**
   - Android: replace `YOUR_API_KEY_HERE` in `android/app/src/main/AndroidManifest.xml`
   - iOS: add key to `ios/Runner/AppDelegate.swift`

6. **Install dependencies**
   ```bash
   flutter pub get
   ```

7. **Run the app**
   ```bash
   flutter run
   ```

---

## Screens Overview (19 screens)

| Category       | Screens |
| -------------- | ------- |
| Auth           | Splash, Login (Phone), OTP, Email Login, Profile Setup |
| Core           | Home Dashboard, Active Session, Volunteer Dashboard, Profile, Notifications |
| Safety Tools   | Fake Call, Walk With Me Setup, Active Companion Timer, Duress PIN Setup |
| Management     | Emergency Contacts, Location Sharing, Community Broadcast |
| Admin          | Admin Dashboard (Web-only: Live Map, Alerts, User Management) |
| Verification   | Volunteer KYC (ID Upload) |

---

## Development Status

| Feature                                                        | Status      |
| -------------------------------------------------------------- | ----------- |
| Phone OTP + Email Auth, Role-Based Routing                     | ✅ Complete |
| Safety Sessions + Volunteer Matching + Live Tracking            | ✅ Complete |
| Long-Press SOS + Community Broadcasts                          | ✅ Complete |
| Hardware SOS (Volume Button Trigger)                           | ✅ Complete |
| Fake Call with Realistic Dialer UI                             | ✅ Complete |
| Virtual Companion (Walk With Me) with Auto-SOS                 | ✅ Complete |
| Duress PIN (Anti-Coercion Protection)                          | ✅ Complete |
| Evidence Vault (Covert Recording + SHA-256 + Cloud Upload)     | ✅ Complete |
| Time-Bound Location Sharing                                    | ✅ Complete |
| Emergency Contacts CRUD                                        | ✅ Complete |
| Volunteer KYC Verification (ID Upload)                         | ✅ Complete |
| Admin Dashboard with God-Mode Map (Web)                        | ✅ Complete |
| Firestore Security Rules + Composite Indexes                   | ✅ Complete |
| Battery Optimization & Background Stability                    | 📋 Planned  |

---

## License

This project is built for hackathon purposes.
