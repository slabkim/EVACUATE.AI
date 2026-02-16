import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

typedef NotificationTapCallback = void Function(Map<String, dynamic> payload);

class LocalNotifService {
  static const String _alertChannelId = 'evacuate_alert_channel_v3';
  static const String _alertChannelName = 'Peringatan Gempa';
  static const String _alertChannelDescription =
      'Notifikasi peringatan gempa EVACUATE.AI';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  NotificationTapCallback? _onTap;

  Future<void> initialize(NotificationTapCallback onTap) async {
    _onTap = onTap;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final rawPayload = response.payload;
        if (rawPayload == null || rawPayload.isEmpty) {
          return;
        }
        try {
          final parsed = jsonDecode(rawPayload) as Map<String, dynamic>;
          _onTap?.call(parsed);
        } catch (_) {
          _onTap?.call(<String, dynamic>{});
        }
      },
    );

    const alertChannel = AndroidNotificationChannel(
      _alertChannelId,
      _alertChannelName,
      description: _alertChannelDescription,
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('sirene'),
      enableVibration: true,
    );

    final androidPlatform = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlatform?.createNotificationChannel(alertChannel);
  }

  Future<void> showForegroundNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _alertChannelId,
      _alertChannelName,
      channelDescription: _alertChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('sirene'),
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'sirene.mp3',
    );

    final details = const NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: jsonEncode(payload ?? const <String, dynamic>{}),
    );
  }
}
