import 'package:flutter/foundation.dart';

/// Returns `true` when the app is running on Web, Windows, macOS or Linux.
/// Uses only `package:flutter/foundation.dart` so it is safe on all platforms
/// (no `dart:io` import that would crash in web builds).
bool get isWebOrDesktop {
  if (kIsWeb) return true;
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
}
