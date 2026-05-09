import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../الشاشات/courier_order_details_screen.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const String _channelId = 'speedstar_alerts';
  static const String _ordersChannelId = 'speedstar_orders_incoming_v1';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<RemoteMessage>? _messageSub;
  StreamSubscription<String>? _tokenRefreshSub;
  bool _initialized = false;
  String _boundDriverId = '';

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('ic_stat_speedstar');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationPayload(response.payload);
      },
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      'SpeedStar Alerts',
      description: 'تنبيهات الطلبات والتحديثات',
      importance: Importance.max,
      playSound: true,
    );
    const ordersChannel = AndroidNotificationChannel(
      _ordersChannelId,
      'SpeedStar Orders',
      description: 'تنبيهات الطلبات الجديدة والعروض الفورية',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('incoming_order'),
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(ordersChannel);

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
    FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteMessageTap);
    unawaited(_messaging.getInitialMessage().then((message) {
      if (message != null) _handleRemoteMessageTap(message);
    }));
    _initialized = true;
  }

  Future<void> bindDriver(String driverId) async {
    final id = driverId.trim();
    if (id.isEmpty || id == _boundDriverId) return;

    _boundDriverId = id;
    await _saveToken(id);

    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) {
      _updateDriverToken(id, token);
    });
  }

  Future<void> _saveToken(String driverId) async {
    final token = await _messaging.getToken();
    if (token == null || token.trim().isEmpty) return;
    await _updateDriverToken(driverId, token);
  }

  Future<void> _updateDriverToken(String driverId, String token) async {
    await FirebaseFirestore.instance.collection('drivers').doc(driverId).set({
      'fcmToken': token,
      'messagingToken': token,
      'fcmTokens': FieldValue.arrayUnion([token]),
      'deviceTokens': FieldValue.arrayUnion([token]),
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _showForegroundAlert(RemoteMessage message) async {
    final title =
        (message.notification?.title ?? message.data['title'] ?? 'إشعار جديد')
            .toString();
    final body =
        (message.notification?.body ?? message.data['body'] ?? '').toString();
    final type = (message.data['type'] ?? '').toString().toLowerCase();
    final isPickupReadyNotice = type == 'courier_pickup_ready';
    final isOrderAlert = type.contains('order') ||
        type.contains('offer') ||
        (!isPickupReadyNotice && type.contains('pickup')) ||
        (!isPickupReadyNotice && type.contains('courier'));
    final androidChannelId = isOrderAlert ? _ordersChannelId : _channelId;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        androidChannelId,
        isOrderAlert ? 'SpeedStar Orders' : 'SpeedStar Alerts',
        channelDescription: isOrderAlert
            ? 'تنبيهات الطلبات الجديدة والعروض الفورية'
            : 'تنبيهات الطلبات والتحديثات',
        icon: 'ic_stat_speedstar',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        sound: isOrderAlert
            ? const RawResourceAndroidNotificationSound('incoming_order')
            : null,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final notificationId =
        DateTime.now().millisecondsSinceEpoch.remainder(2147483647);

    await _localNotifications.show(
      notificationId,
      title,
      body,
      details,
      payload: jsonEncode({
        ...message.data,
        'title': title,
        'body': body,
      }),
    );
  }

  void _handleRemoteMessageTap(RemoteMessage message) {
    _openFromData(message.data);
  }

  void _handleNotificationPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        _openFromData(
          decoded.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ),
        );
      }
    } catch (_) {}
  }

  void _openFromData(Map<String, dynamic> rawData) {
    final data = rawData.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
    final orderId = (data['orderId'] ?? data['orderDocId'] ?? '')
        .toString()
        .trim();
    final driverId =
        (data['driverId'] ?? data['userId'] ?? _boundDriverId).toString().trim();
    if (orderId.isEmpty || driverId.isEmpty) return;

    void push() {
      final navigator = navigatorKey.currentState;
      if (navigator == null) return;
      navigator.push(
        MaterialPageRoute(
          builder: (_) => CourierOrderDetailsScreen(
            orderId: orderId,
            driverId: driverId,
          ),
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => push());
  }
}
