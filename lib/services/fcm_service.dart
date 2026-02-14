import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'local_notif_service.dart';

typedef PushPayloadHandler = void Function(Map<String, dynamic> data);

class FcmService {
  FcmService(this._localNotifService);

  final LocalNotifService _localNotifService;

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedAppSubscription;

  Future<void> initialize({
    required PushPayloadHandler onNotificationTap,
  }) async {
    await _localNotifService.initialize(onNotificationTap);

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: true,
      provisional: false,
    );

    _foregroundSubscription?.cancel();
    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      // Handle both notification and data-only messages
      final title = message.notification?.title ?? message.data['title'] ?? 'Peringatan Gempa';
      final body = message.notification?.body ?? message.data['body'] ?? 'Terdapat pembaruan gempa di sekitar Anda.';
      
      _localNotifService.showForegroundNotification(
        title: title,
        body: body,
        payload: message.data,
      );
    });

    _openedAppSubscription?.cancel();
    _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) {
        onNotificationTap(message.data);
      },
    );

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      onNotificationTap(initialMessage.data);
    }
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    await _localNotifService.showForegroundNotification(
      title: title,
      body: body,
      payload: payload,
    );
  }

  Future<String?> getToken() async {
    return FirebaseMessaging.instance.getToken();
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedAppSubscription?.cancel();
  }
}
