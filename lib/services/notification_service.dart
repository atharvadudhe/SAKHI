import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Initialize FCM and request permissions
  Future<void> initialize() async {
    try {
      // Request notification permission
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: true,
      );

      debugPrint('FCM permission: ${settings.authorizationStatus}');

      // Get FCM token
      final token = await _messaging.getToken();
      if (kDebugMode) {
        debugPrint('FCM Token: $token');
      }

      // Listen for foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Listen for background message taps
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessageTap);
    } catch (e) {
      debugPrint('FCM initialization error: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground message: ${message.notification?.title}');
    // TODO: Show in-app notification / snackbar
  }

  void _handleBackgroundMessageTap(RemoteMessage message) {
    debugPrint('Background tap: ${message.data}');
    // TODO: Navigate to relevant screen
  }

  /// Subscribe to a topic (e.g., 'volunteers_nearby')
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }
}
