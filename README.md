# SAKHI

An app made for women and their safety - built with Flutter.

## About

SAKHI is a comprehensive women's safety application that provides:

- 🚨 Emergency SOS button with one-tap calling to emergency services
- 📍 Real-time location tracking and sharing
- 👥 Emergency contacts management
- 🗺️ Safe route planning
- 📞 Quick dial to police, ambulance, and other emergency services
- 🎤 Audio recording during emergencies

## Features

### Emergency SOS
A prominent emergency button that:
- Calls emergency services (112/911)
- Sends your current location to emergency contacts
- Starts recording audio for evidence

### Location Services
- Real-time GPS tracking
- Location sharing with trusted contacts
- Safe route suggestions based on well-lit, populated areas

### Emergency Contacts
- Add and manage trusted emergency contacts
- Automatic alerts sent to contacts in emergency situations

### Quick Actions
- Fast dial to police (100)
- Fast dial to ambulance (102)
- Access to women's helpline numbers

## Getting Started

### Prerequisites

- Flutter SDK (3.0.0 or higher)
- Dart SDK
- Android Studio / Xcode (for respective platform development)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/dhairyajangir/SAKHI.git
cd SAKHI
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
# For development
flutter run

# For Android
flutter run -d android

# For iOS
flutter run -d ios
```

### Building for Production

#### Android
```bash
flutter build apk --release
# or for app bundle
flutter build appbundle --release
```

#### iOS
```bash
flutter build ios --release
```

## Project Structure

```
lib/
├── main.dart                 # Application entry point
├── models/                   # Data models
├── screens/                  # UI screens
│   ├── home_screen.dart
│   ├── emergency_contacts_screen.dart
│   └── safe_routes_screen.dart
├── widgets/                  # Reusable widgets
│   ├── emergency_button.dart
│   └── quick_dial_card.dart
├── services/                 # Business logic and services
│   └── location_service.dart
└── utils/                    # Utility functions and constants
```

## Permissions

The app requires the following permissions:

### Android
- Location (Fine and Coarse)
- Phone (for making emergency calls)
- Contacts (for emergency contact management)
- Microphone (for audio recording)
- Vibrate

### iOS
- Location When In Use
- Location Always
- Contacts
- Microphone

## Dependencies

Key dependencies used in this project:
- `geolocator` - Location services
- `permission_handler` - Runtime permissions
- `flutter_phone_direct_caller` - Direct phone calling
- `contacts_service` - Contact management
- `provider` - State management
- `shake` - Shake detection for emergency trigger

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

See the [LICENSE](LICENSE) file for details.

## Safety Disclaimer

This app is designed to assist in emergency situations but should not be relied upon as the sole means of protection. Always follow local safety guidelines and contact local emergency services when needed.
