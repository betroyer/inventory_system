import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'settings_service.dart';

class NotificationService {
  NotificationService(this._settings);

  final SettingsService _settings;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      await _plugin.initialize(initSettings);
      _initialized = true;
    } catch (_) {
      // Notifications may be unavailable in tests or unsupported platforms.
    }
  }

  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_settings.phoneNotifications) return;
    if (!_initialized) await initialize();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'sari_sari_alerts',
        'Store Alerts',
        channelDescription: 'Low stock and expiration alerts',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _plugin.show(id, title, body, details);
  }
}
