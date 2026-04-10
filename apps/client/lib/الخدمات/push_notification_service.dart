import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static const String _channelId = 'speedstar_alerts';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<RemoteMessage>? _messageSub;
  StreamSubscription<String>? _tokenRefreshSub;
  bool _initialized = false;
  String _boundClientId = '';

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(
      settings: initSettings,
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      'SpeedStar Alerts',
      description: 'تنبيهات الطلبات والتحديثات',
      importance: Importance.max,
      playSound: true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _messageSub?.cancel();
    _messageSub = FirebaseMessaging.onMessage.listen(_showForegroundAlert);
    _initialized = true;
  }

  Future<void> bindClient(String clientId) async {
    final id = clientId.trim();
    if (id.isEmpty || id == _boundClientId) return;

    _boundClientId = id;
    await _saveToken(id);

    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) {
      _updateClientToken(id, token);
    });
  }

  Future<void> _saveToken(String clientId) async {
    final token = await _messaging.getToken();
    if (token == null || token.trim().isEmpty) return;
    await _updateClientToken(clientId, token);
  }

  Future<void> _updateClientToken(String clientId, String token) async {
    await FirebaseFirestore.instance.collection('clients').doc(clientId).set({
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _showForegroundAlert(RemoteMessage message) async {
    final title =
        (message.notification?.title ?? message.data['title'] ?? 'إشعار جديد')
            .toString();
    final body =
        (message.notification?.body ?? message.data['body'] ?? '').toString();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'SpeedStar Alerts',
        channelDescription: 'تنبيهات الطلبات والتحديثات',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final notificationId =
        DateTime.now().millisecondsSinceEpoch.remainder(2147483647);

    await _localNotifications.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}