import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Displays real mobile system push notifications when live alerts arrive.
class LocalPushService {
  LocalPushService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings();
      const settings = InitializationSettings(android: android, iOS: darwin);
      await _plugin.initialize(settings);

      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
      _initialized = true;
    } catch (_) {
      // Safe no-op in unsupported test/desktop environments.
    }
  }

  static Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    try {
      if (!_initialized) await initialize();
      const androidDetails = AndroidNotificationDetails(
        'pocketyaar_alerts',
        'PocketYaar Alerts',
        channelDescription:
            'Notifications for loans, group expenses, and friend requests',
        importance: Importance.high,
        priority: Priority.high,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );
      await _plugin.show(id, title, body, details);
    } catch (_) {
      // Ignore in test/unsupported platforms.
    }
  }
}
