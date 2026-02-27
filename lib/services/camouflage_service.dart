import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages dynamic launcher-icon switching (camouflage mode).
///
/// On **Android** this works via activity-alias toggling through a
/// MethodChannel to the native side.  On **iOS** it uses the
/// `UIApplication.setAlternateIconName` API exposed by the
/// `flutter_dynamic_icon` plugin.
///
/// Icon names recognised by the native layers:
///   • `null` / `"default"` → original Sakhi icon
///   • `"calculator"`       → Calculator disguise
///   • `"calendar"`         → Calendar disguise
///   • `"notes"`            → Notes disguise
class CamouflageService {
  CamouflageService._();
  static final CamouflageService instance = CamouflageService._();

  // ── Persistence key ──
  static const _prefKey = 'camouflage_active_icon';

  // ── Platform channel (Android only) ──
  static const _channel = MethodChannel('com.example.sakhi/icon');

  /// All available disguise options.  The key is the icon name passed
  /// to the native layer; `null` means "revert to the default icon".
  static const Map<String?, CamouflageOption> options = {
    null: CamouflageOption(
      label: 'Default (Sakhi)',
      description: 'The original safety shield',
      nativeName: null,
      previewIcon: 'assets/images/sakhi-logo-3.png',
    ),
    'calculator': CamouflageOption(
      label: 'Calculator',
      description: 'Looks like a calculator app',
      nativeName: 'calculator',
      previewIcon: 'assets/images/calculator.png',
    ),
    'calendar': CamouflageOption(
      label: 'Calendar',
      description: 'Looks like a calendar app',
      nativeName: 'calendar',
      previewIcon: 'assets/images/calendar.png',
    ),
    'notes': CamouflageOption(
      label: 'Notes',
      description: 'Looks like a notes app',
      nativeName: 'notes',
      previewIcon: 'assets/images/notes.png',
    ),
    'lotus': CamouflageOption(
      label: 'Sakhi Lotus',
      description: 'Lotus shield icon',
      nativeName: 'lotus',
      previewIcon: 'assets/images/Lotus.png',
    ),
    'sakhi': CamouflageOption(
      label: 'Sakhi Shield',
      description: 'Purple & coral shield',
      nativeName: 'sakhi',
      previewIcon: 'assets/images/Sakhi.png',
    ),
    'sakhi_hindi': CamouflageOption(
      label: 'Sakhi सखी',
      description: 'Shield with Hindi text',
      nativeName: 'sakhi_hindi',
      previewIcon: 'assets/images/सखी.png',
    ),
  };

  // ── Public API ──

  /// Returns the name of the currently-active icon (or `null` for the
  /// default Sakhi icon).
  Future<String?> get currentIcon async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefKey);
    return (stored == 'default' || stored == null) ? null : stored;
  }

  /// Changes the launcher icon.
  ///
  /// * [iconName] — one of `"calculator"`, `"calendar"`, `"notes"`, or
  ///   `null` to revert to the default.
  ///
  /// **Android caveat:** the system will briefly kill the launcher
  /// activity, which may return the user to the home screen.
  ///
  /// Throws [PlatformException] if the native call fails.  Callers
  /// should wrap this in a try-catch for graceful degradation.
  Future<void> changeAppIcon(String? iconName) async {
    if (kIsWeb) {
      debugPrint('CamouflageService: icon change not supported on web');
      return;
    }

    if (Platform.isAndroid) {
      await _changeAndroidIcon(iconName);
    } else if (Platform.isIOS) {
      await _changeIOSIcon(iconName);
    }

    // Persist selection
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, iconName ?? 'default');
  }

  // ── Android implementation ──

  /// Uses a MethodChannel into `MainActivity.kt` to enable/disable
  /// activity-aliases.
  Future<void> _changeAndroidIcon(String? iconName) async {
    try {
      await _channel.invokeMethod('setIcon', {'iconName': iconName});
    } on PlatformException catch (e) {
      debugPrint('CamouflageService [Android]: $e');
      rethrow;
    }
  }

  // ── iOS implementation ──

  /// Uses our own MethodChannel to call
  /// `UIApplication.setAlternateIconName` via AppDelegate.
  Future<void> _changeIOSIcon(String? iconName) async {
    try {
      await _channel.invokeMethod('setIcon', {'iconName': iconName});
    } on PlatformException catch (e) {
      debugPrint('CamouflageService [iOS]: $e');
      rethrow;
    }
  }
}

/// Metadata for a single camouflage option.
class CamouflageOption {
  final String label;
  final String description;

  /// The icon name passed to the native layer.
  /// `null` means "revert to default".
  final String? nativeName;

  /// Path to an asset preview image (for the UI grid).
  /// If `null`, the UI should show a Material icon placeholder.
  final String? previewIcon;

  const CamouflageOption({
    required this.label,
    required this.description,
    required this.nativeName,
    required this.previewIcon,
  });
}
