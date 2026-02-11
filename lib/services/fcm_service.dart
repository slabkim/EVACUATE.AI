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
      _localNotifService.showForegroundNotification(
        title: message.notification?.title ?? 'Peringatan Gempa',
        body: message.notification?.body ??
            'Terdapat pembaruan gempa di sekitar Anda.',
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

  Future<String?> getToken() async {
    return FirebaseMessaging.instance.getToken();
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedAppSubscription?.cancel();
  }
}
