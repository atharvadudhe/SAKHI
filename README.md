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

### ⚖️ Legal & Compliance

> **Warning — Covert audio recording is subject to strict legal constraints.**
>
> - Many jurisdictions require **all-party (two-party) consent** before recording conversations. Using the Evidence Vault feature without proper consent may violate wiretapping, eavesdropping, or surveillance laws.
> - In **GDPR regions** (EU/EEA/UK), recording individuals constitutes processing of personal data and requires a lawful basis (e.g., legitimate interest for personal safety, explicit consent).
> - **CCPA** and other US state privacy laws may impose additional obligations regarding disclosure and data subject rights.
>
> **Developers and deployers MUST:**
> 1. Consult qualified legal counsel before enabling covert recording in any deployment.
> 2. Implement **user notification and consent flows** appropriate to the target jurisdiction.
> 3. Define and enforce **data-retention policies** — recordings and associated metadata should be retained only as long as legally required and then securely deleted.
> 4. Provide a mechanism for **data deletion requests** (right to erasure) from recorded parties.
> 5. Maintain **audit logs** of recording events for accountability.
>
> The authors of this project provide no legal advice. Compliance is the sole responsibility of the deployer.

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
  - **Encryption**: All uploads are transmitted over TLS and stored with Firebase Storage server-side encryption at rest.
  - **Data Retention & Deletion**: KYC images should be retained only for the duration required for verification. Once verified (or upon account deletion), images must be securely deleted from Firebase Storage. Implement a Cloud Function or admin procedure for periodic purging of expired KYC data.
  - **GDPR / CCPA Compliance**: Users have the right to erasure of their KYC data. The lawful basis for processing government IDs is legitimate interest (volunteer safety vetting). Implement data-minimization by storing only the minimum required information.
  - **Access Control**: KYC images are accessible only to admin-role users via Firebase Storage security rules and role-based Firestore access. No other users or volunteers can view uploaded IDs.
  - **Audit Logging**: All verification status changes (pending → verified/rejected) should be logged with timestamps and the reviewing admin's UID for accountability.
  - **Privacy Contact**: For data access/deletion requests related to KYC data, contact the project administrator.
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
│   └── router.dart                        # GoRouter (19 routes)
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
| `users`                                  | uid, name, phone, role, isAvailable, currentLocation, lastHeartbeat, safePinHash, duressPinHash, verificationStatus |

> **⚠️ PIN Storage**: `safePinHash` and `duressPinHash` must be stored as **cryptographic hashes only** (bcrypt, scrypt, or Argon2 — never SHA-256 alone). PINs must **never** be logged, transmitted, or stored in plaintext. Verification must compare a client-supplied PIN against the stored hash using the chosen hash library's verify function (server-side or client-side with secure transport). Any existing plaintext `safePin`/`duressPin` values must be migrated to hashed values immediately. Compromised PINs should be rotated by the user.
| `users/{uid}/emergencyContacts`          | id, name, phone, relationship                                                               |
| `sessions`                               | sessionId, createdBy, status, startTime, endTime, volunteerId, volunteerName, timeLimit, userLocation, destinationLocation, isVirtualCompanionActive |
| `sessions/{id}/locationUpdates`          | uid, geoPoint, timestamp                                                                    |
| `broadcasts`                             | id, uid, userName, message, alertType, location, timestamp, radiusKm, isDuressActive         |
| `locationShares`                         | id, uid, userName, location, createdAt, expiresAt, durationMinutes, isActive                 |
| `liveLocations`                          | uid, userName, role, latitude, longitude, lastUpdatedAt, isActive, trackingReason, sessionId, batteryLevel |
| `session_evidence`                       | sessionId, downloadUrl, sha256Hash, recordedAt, uploadedAt                                   |

Security rules: [`firestore.rules`](firestore.rules) — role-based access; users update only their own data; volunteers modify only assigned sessions; admin has full access.

Composite indexes: [`firestore.indexes.json`](firestore.indexes.json) — 5 indexes for session, broadcast, and location share queries.

### Privacy & Data Governance

| Collection | Retention Policy | Notes |
|---|---|---|
| `users` | Retained until account deletion | Core profile data. `safePinHash`/`duressPinHash` are cryptographic hashes only. |
| `users/{uid}/emergencyContacts` | Retained until user deletes contacts or account | User-managed CRUD. Deleted on account deletion. |
| `sessions` | 90 days after session end | Completed sessions are eligible for automated cleanup via a scheduled Cloud Function. Active sessions are never pruned. |
| `sessions/{id}/locationUpdates` | Same as parent session (90 days) | Purged when parent session document is deleted. |
| `broadcasts` | 30 days after creation | Community alerts auto-expire. A Cloud Function with a TTL field (`expiresAt`) should delete stale documents. |
| `locationShares` | Auto-deactivated on expiry; deleted after 7 days | `expiresAt` field drives automatic cleanup. |
| `liveLocations` | Ephemeral — deactivated on session end | Documents are set to `isActive: false` on stop; a scheduled job should purge inactive entries older than 24 hours. |
| `session_evidence` | 1 year (or per legal-hold requirements) | Audio recordings and hashes. Subject to legal retention. Firebase Storage files purged on the same schedule. |

**User Right to Erasure / Account Deletion:**
- Users may request full account deletion via the profile screen or by contacting the admin.
- The deletion flow must remove: the `users/{uid}` document and all subcollections, all `sessions` created by the user, associated `locationUpdates`, `broadcasts`, `locationShares`, `liveLocations`, `session_evidence` records, and Firebase Storage files (KYC images, audio recordings).
- Implement a Cloud Function (`deleteUserData`) triggered by Firebase Auth user deletion or an admin endpoint to cascade-delete all user-associated data.

**Data Minimization & Automatic Cleanup:**
- Add TTL fields (`expiresAt`) to `broadcasts`, `locationShares`, and `liveLocations`.
- Deploy a scheduled Cloud Function (e.g., daily) to purge expired documents and associated Storage files.
- Location history (`locationUpdates`) should be aggregated or deleted after the retention window.

**Export & Portability:**
- Users may request a data export (JSON) containing their profile, emergency contacts, session history, and broadcast history.
- Implement an admin endpoint or Cloud Function (`exportUserData`) that collects and packages the user's data for download.

**Mapping to Security Rules:**
- `firestore.rules` enforces that users can only read/write their own data, volunteers can only modify assigned sessions, and admins have management access — aligning with data-access minimization requirements.

---

## Getting Started

### Prerequisites
- Flutter SDK (Dart `^3.11.0` — see `pubspec.yaml` environment.sdk)
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

   > ⚠️ **Security Warning**: Test mode allows **unrestricted read/write access** to your entire Firestore database for 30 days. This is suitable only for initial development. **Deploy the project's security rules** (step 4 below) immediately after creating the database, and **switch to production mode** before any public or beta release to prevent unauthorized data access.

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

> **Battery Optimization Notes (Planned):**
> - **Heartbeat loop**: Currently fires every 30 s. Planned: adaptive backoff (30 s → 60 s → 120 s when idle) and suspension when the app is backgrounded and no active session exists.
> - **Location polling**: Currently polls every 15 s via `startLocationUpdates`. Planned: switch to fused location / significant-change APIs and make the interval configurable per session type. Use geofencing for virtual companion instead of continuous polling.
> - **Real-time tracking**: Currently always-on during sessions. Planned: make opt-in and pauseable; suspend writes when the device is stationary (no movement detected).
> - **Background work**: On Android, location updates already run as a foreground service with notification. Planned: use WorkManager / JobScheduler for deferred tasks (evidence upload retries, heartbeat) to avoid being killed by the OS.

---

## License

This project is built for hackathon purposes.
