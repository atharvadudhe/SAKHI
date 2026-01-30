# Flutter Migration Guide

## Overview

This repository has been successfully migrated from React Native to Flutter. This document outlines what was changed and how to work with the new Flutter codebase.

## What Changed

### Before (React Native)
- JavaScript/TypeScript-based mobile framework
- npm/yarn package management
- React components
- Platform-specific code in separate directories

### After (Flutter)
- Dart-based cross-platform framework
- pub package management (pubspec.yaml)
- Flutter widgets
- Unified codebase for iOS, Android, and Web

## Project Structure

```
SAKHI/
├── lib/                          # Main application code
│   ├── main.dart                # App entry point
│   ├── models/                  # Data models (empty, ready for future use)
│   ├── screens/                 # UI screens
│   │   ├── home_screen.dart
│   │   ├── emergency_contacts_screen.dart
│   │   └── safe_routes_screen.dart
│   ├── services/                # Business logic
│   │   └── location_service.dart
│   ├── utils/                   # Utilities (empty, ready for future use)
│   └── widgets/                 # Reusable UI components
│       ├── emergency_button.dart
│       └── quick_dial_card.dart
├── android/                     # Android-specific configuration
├── ios/                         # iOS-specific configuration
├── web/                         # Web-specific configuration
├── test/                        # Unit and widget tests
├── pubspec.yaml                 # Dependencies and project metadata
└── analysis_options.yaml        # Dart linter rules
```

## Key Features Implemented

### 1. Emergency SOS System
- **Location**: `lib/widgets/emergency_button.dart`
- Large, animated emergency button on home screen
- Confirmation dialog before calling emergency services
- Calls emergency number (112) when activated
- Future: Will send location to contacts and start audio recording

### 2. Location Services
- **Location**: `lib/services/location_service.dart`
- Uses Provider pattern for state management
- Real-time GPS tracking
- Displays current coordinates on home screen
- Handles permission requests automatically

### 3. Emergency Contacts
- **Location**: `lib/screens/emergency_contacts_screen.dart`
- Placeholder for managing emergency contacts
- Ready to integrate with device contacts
- UI prepared for adding/removing contacts

### 4. Quick Actions
- **Location**: `lib/widgets/quick_dial_card.dart`
- Quick dial cards for:
  - Police (100)
  - Ambulance (102)
  - Emergency contacts management
  - Safe routes navigation

### 5. Safe Routes
- **Location**: `lib/screens/safe_routes_screen.dart`
- Placeholder for safe route planning feature
- Future: Integration with mapping services

## Dependencies

Key packages used (from `pubspec.yaml`):

```yaml
dependencies:
  geolocator: ^10.1.0              # GPS location
  permission_handler: ^11.0.1      # Runtime permissions
  url_launcher: ^6.2.1             # Open URLs/make calls
  shared_preferences: ^2.2.2       # Local data storage
  provider: ^6.1.1                 # State management
  contacts_service: ^0.6.3         # Contact access
  flutter_phone_direct_caller: ^2.1.1  # Direct phone calls
  shake: ^2.2.0                    # Shake gesture detection
```

## Development Commands

### Setup
```bash
# Install dependencies
flutter pub get

# Analyze code
flutter analyze

# Format code
dart format .
```

### Running
```bash
# Run on connected device
flutter run

# Run on specific platform
flutter run -d android
flutter run -d ios
flutter run -d chrome  # Web

# Run in release mode
flutter run --release
```

### Testing
```bash
# Run all tests
flutter test

# Run specific test
flutter test test/widget_test.dart

# Run with coverage
flutter test --coverage
```

### Building
```bash
# Android APK
flutter build apk

# Android App Bundle (for Play Store)
flutter build appbundle

# iOS
flutter build ios

# Web
flutter build web
```

## Platform-Specific Setup

### Android
1. **Minimum SDK**: API 21 (Android 5.0)
2. **Target SDK**: API 34 (Android 14)
3. **Permissions**: Configured in `android/app/src/main/AndroidManifest.xml`
   - Location (Fine & Coarse)
   - Phone calls
   - Contacts
   - Microphone
   - Vibration

### iOS
1. **Minimum iOS**: 12.0
2. **Permissions**: Configured in `ios/Runner/Info.plist`
   - Location When In Use
   - Location Always
   - Contacts
   - Microphone

### Web
- Basic web support included
- Some features (like direct calling) may have limitations on web

## State Management

The app uses **Provider** for state management:

```dart
// Location service is provided at app level
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LocationService()),
  ],
  child: MaterialApp(...),
)

// Consumed in widgets
Consumer<LocationService>(
  builder: (context, locationService, child) {
    return Text(locationService.getLocationString());
  },
)
```

## Theme

The app uses Material Design 3 with:
- **Primary Color**: Pink (representing women empowerment)
- **Light and Dark themes** supported
- Responsive design that adapts to different screen sizes

## Testing

Basic widget tests are included in `test/widget_test.dart`:
- App initialization test
- Navigation to Emergency Contacts
- Navigation to Safe Routes

To add more tests:
```dart
testWidgets('Test description', (WidgetTester tester) async {
  await tester.pumpWidget(const SakhiApp());
  // Your test code
  expect(find.text('Something'), findsOneWidget);
});
```

## Next Steps for Development

### Immediate Enhancements
1. **Implement Contact Picker**: Use `contacts_service` to actually pick emergency contacts
2. **Add Persistent Storage**: Store emergency contacts using `shared_preferences` or a database
3. **Shake Detection**: Implement shake-to-activate emergency feature
4. **SMS Integration**: Send SMS to emergency contacts with location
5. **Audio Recording**: Implement emergency audio recording

### Future Features
1. **Map Integration**: Add Google Maps/OpenStreetMap for safe routes
2. **Real-time Tracking**: Share live location with trusted contacts
3. **Community Features**: Report unsafe areas, view safety ratings
4. **Push Notifications**: Alert emergency contacts automatically
5. **Women's Resources**: Add helpline numbers, shelters, legal aid info

## Troubleshooting

### Common Issues

**Issue**: `flutter: command not found`
- **Solution**: Install Flutter SDK and add to PATH

**Issue**: Dependency conflicts
- **Solution**: Run `flutter pub get` or `flutter pub upgrade`

**Issue**: Android build fails
- **Solution**: Update Android SDK, check `android/build.gradle` versions

**Issue**: iOS build fails
- **Solution**: Run `pod install` in ios/ directory (requires CocoaPods)

**Issue**: Permission denied on device
- **Solution**: Check platform-specific permission configurations

## Contributing

When adding new features:
1. Follow Dart style guide
2. Add tests for new widgets/services
3. Update README if adding major features
4. Use `flutter analyze` to check for issues
5. Format code with `dart format`

## Migration Notes

### For Developers Familiar with React Native

| React Native | Flutter Equivalent |
|--------------|-------------------|
| npm/yarn | pub |
| package.json | pubspec.yaml |
| JavaScript/TypeScript | Dart |
| Components | Widgets |
| Props | Constructor parameters |
| State | StatefulWidget + setState |
| Redux/MobX | Provider/Riverpod/Bloc |
| StyleSheet | Theme/TextStyle |
| Flexbox | Column/Row/Flex |

### Key Differences
- Flutter uses **widgets** instead of components
- Everything is a widget (even layout)
- Hot reload works similarly but often faster
- Single codebase truly runs everywhere (iOS, Android, Web, Desktop)
- Better performance (compiled to native code)
- Strong typing with Dart

## Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [Flutter Widget Catalog](https://flutter.dev/docs/development/ui/widgets)
- [Provider Package](https://pub.dev/packages/provider)
- [Flutter Cookbook](https://flutter.dev/docs/cookbook)

## Support

For issues or questions:
1. Check Flutter documentation
2. Search existing GitHub issues
3. Create a new issue with details
4. Join Flutter community on Discord/Slack
