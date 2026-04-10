import 'dart:convert';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static const String _channelId = 'speedstar_alerts';
  static const String _ordersChannelId = 'speedstar_store_orders_incoming_v2';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<RemoteMessage>? _messageSub;
  StreamSubscription<RemoteMessage>? _messageOpenedSub;
  StreamSubscription<String>? _tokenRefreshSub;
  final StreamController<Map<String, dynamic>> _tapPayloadController =
      StreamController<Map<String, dynamic>>.broadcast();
  bool _initialized = false;
  String _boundStoreId = '';
  Map<String, dynamic>? _pendingTapPayload;

  Stream<Map<String, dynamic>> get notificationTapStream =>
      _tapPayloadController.stream;

  Map<String, dynamic>? consumePendingTapPayload() {
    final payload = _pendingTapPayload;
    _pendingTapPayload = null;
    return payload;
  }

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
      onDidReceiveNotificationResponse: (response) {
        final payload = _decodePayload(response.payload);
        if (payload != null) {
          _emitTapPayload(payload);
        }
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
    _messageOpenedSub?.cancel();
    _messageOpenedSub =
        FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteMessageTap);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleRemoteMessageTap(initialMessage);
    }
    _initialized = true;
  }

  Map<String, dynamic>? _decodePayload(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Map<String, dynamic> _payloadFromRemoteMessage(RemoteMessage message) {
    return {
      ...message.data,
      'title':
          (message.notification?.title ?? message.data['title'] ?? 'إشعار جديد')
              .toString(),
      'body': (message.notification?.body ?? message.data['body'] ?? '')
          .toString(),
    };
  }

  void _emitTapPayload(Map<String, dynamic> payload) {
    _pendingTapPayload = payload;
    if (!_tapPayloadController.isClosed) {
      _tapPayloadController.add(payload);
    }
  }

  void _handleRemoteMessageTap(RemoteMessage message) {
    _emitTapPayload(_payloadFromRemoteMessage(message));
  }

  Future<void> bindStore(String storeId) async {
    final id = storeId.trim();
    if (id.isEmpty || id == _boundStoreId) return;

    _boundStoreId = id;
    await _saveToken(id);

    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) {
      _updateStoreToken(id, token);
    });
  }

  Future<void> _saveToken(String storeId) async {
    final token = await _messaging.getToken();
    if (token == null || token.trim().isEmpty) return;
    await _updateStoreToken(storeId, token);
  }

  Future<void> _updateStoreToken(String storeId, String token) async {
    await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(storeId)
        .set({
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _showForegroundAlert(RemoteMessage message) async {
    final payload = _payloadFromRemoteMessage(message);
    final title = (payload['title'] ?? 'إشعار جديد').toString();
    final body = (payload['body'] ?? '').toString();
    final type = (payload['type'] ?? '').toString().toLowerCase();
    final isOrderAlert = type.contains('order') ||
        type.contains('offer') ||
        type.contains('pickup') ||
        type.contains('courier');
    final androidChannelId = isOrderAlert ? _ordersChannelId : _channelId;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        androidChannelId,
        isOrderAlert ? 'SpeedStar Orders' : 'SpeedStar Alerts',
        channelDescription: isOrderAlert
            ? 'تنبيهات الطلبات الجديدة والعروض الفورية'
            : 'تنبيهات الطلبات والتحديثات',
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
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: details,
      payload: jsonEncode(payload),
    );
  }
}
