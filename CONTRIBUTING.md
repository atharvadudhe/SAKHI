# Contributing to SAKHI

Thank you for your interest in contributing to SAKHI! This document provides guidelines for contributing to this women's safety application.

## Code of Conduct

This project is committed to providing a safe, welcoming, and inclusive environment for everyone. We expect all contributors to:
- Be respectful and considerate
- Focus on what's best for the community and users
- Show empathy towards other community members

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates. When creating a bug report, include:

- **Clear title and description**
- **Steps to reproduce** the issue
- **Expected behavior** vs **actual behavior**
- **Screenshots** if applicable
- **Device/OS information** (Flutter version, OS, device model)
- **Error messages** or logs

### Suggesting Enhancements

Enhancement suggestions are welcome! Please provide:
- **Clear description** of the feature
- **Use case**: Why is this feature needed?
- **Proposed solution**: How should it work?
- **Alternatives considered**
- **Mockups or examples** if applicable

### Pull Requests

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make your changes**
4. **Test your changes**
   ```bash
   flutter test
   flutter analyze
   ```
5. **Commit with clear messages**
   ```bash
   git commit -m "Add: feature description"
   ```
6. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```
7. **Open a Pull Request**

## Development Setup

### Prerequisites
- Flutter SDK (3.0.0 or higher)
- Dart SDK (included with Flutter)
- Android Studio or VS Code
- Git

### Setup Steps

1. Clone your fork:
   ```bash
   git clone https://github.com/YOUR-USERNAME/SAKHI.git
   cd SAKHI
   ```

2. Add upstream remote:
   ```bash
   git remote add upstream https://github.com/dhairyajangir/SAKHI.git
   ```

3. Install dependencies:
   ```bash
   flutter pub get
   ```

4. Run the app:
   ```bash
   flutter run
   ```

## Coding Guidelines

### Dart Style Guide

Follow the official [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style):

- Use `dart format` to format code
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions small and focused

### File Organization

```
lib/
├── main.dart              # App entry point only
├── models/                # Data models
├── screens/               # Full-page screens
├── widgets/               # Reusable UI components
├── services/              # Business logic, API calls
└── utils/                 # Helper functions, constants
```

### Widget Naming

- **Screens**: End with `Screen` (e.g., `HomeScreen`)
- **Reusable widgets**: Descriptive names (e.g., `EmergencyButton`)
- **Stateful widgets**: Create State class with `_WidgetNameState`

### Code Example

```dart
class EmergencyButton extends StatefulWidget {
  const EmergencyButton({super.key});

  @override
  State<EmergencyButton> createState() => _EmergencyButtonState();
}

class _EmergencyButtonState extends State<EmergencyButton> {
  // Use meaningful variable names
  bool _isEmergencyActive = false;

  // Add documentation for complex functions
  /// Activates emergency mode and notifies contacts
  Future<void> _activateEmergency() async {
    // Implementation
  }

  @override
  Widget build(BuildContext context) {
    // Use const where possible
    return const Text('Emergency');
  }
}
```

## Testing Guidelines

### Write Tests For
- New widgets
- New services/business logic
- Bug fixes (to prevent regression)

### Test Example

```dart
testWidgets('Emergency button shows dialog on tap', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: EmergencyButton()));
  
  await tester.tap(find.byType(EmergencyButton));
  await tester.pumpAndSettle();
  
  expect(find.text('Emergency SOS'), findsOneWidget);
});
```

### Running Tests

```bash
# All tests
flutter test

# Specific test file
flutter test test/widget_test.dart

# With coverage
flutter test --coverage
```

## Commit Message Guidelines

Use clear, descriptive commit messages:

```
Type: Brief description (50 chars max)

Longer description if needed (wrap at 72 chars)

- Bullet points for multiple changes
- Reference issues: Fixes #123
```

### Types
- **Add**: New feature
- **Fix**: Bug fix
- **Update**: Modify existing feature
- **Remove**: Delete code/feature
- **Docs**: Documentation only
- **Style**: Formatting, no code change
- **Refactor**: Code restructuring
- **Test**: Add/modify tests
- **Chore**: Maintenance tasks

### Examples

```
Add: Emergency contact picker functionality

Implements contact picker using contacts_service package.
Users can now select contacts from their device.

Fixes #42
```

```
Fix: Location permission crash on Android 13

Added runtime permission check for Android 13+
Updated gradle configuration
```

## Feature Priorities

We prioritize features that:
1. **Enhance safety**: Core safety features first
2. **Improve accessibility**: Make app usable for everyone
3. **Increase reliability**: Stability over new features
4. **Protect privacy**: User data protection is critical

## Privacy and Security

When contributing:
- **Never** commit API keys or secrets
- **Always** use environment variables for sensitive data
- **Implement** proper data encryption for user data
- **Follow** OWASP mobile security guidelines
- **Test** permission handling thoroughly

## Documentation

Update documentation when:
- Adding new features
- Changing existing functionality
- Adding new dependencies
- Modifying setup/installation steps

Files to update:
- `README.md` - User-facing documentation
- `FLUTTER_MIGRATION.md` - Technical migration guide
- Code comments - For complex logic
- This file - For contribution guidelines

## Review Process

Pull requests will be reviewed for:
1. **Functionality**: Does it work as expected?
2. **Code quality**: Follows style guide?
3. **Tests**: Are tests included and passing?
4. **Documentation**: Is it documented?
5. **Performance**: Does it impact app performance?
6. **Security**: Does it introduce vulnerabilities?

## Getting Help

- **Discord/Slack**: Join our community (link TBD)
- **GitHub Issues**: Ask questions with `question` label
- **Documentation**: Check Flutter docs and FLUTTER_MIGRATION.md

## Recognition

Contributors will be:
- Listed in CONTRIBUTORS.md
- Mentioned in release notes
- Appreciated in community channels

Thank you for contributing to make SAKHI better for women's safety! 🙏

---

**Note**: This is a safety-critical application. Please test thoroughly and consider the impact of your changes on user safety.
