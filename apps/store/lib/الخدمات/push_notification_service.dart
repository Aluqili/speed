import 'dart:convert';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static const String _channelId = 'speedstar_alerts';
  static const String _ordersChannelId = 'speedstar_store_orders_incoming_v6';
  static const MethodChannel _alertServiceChannel =
      MethodChannel('speedstar/store_alert_service');

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<RemoteMessage>? _messageSub;
  StreamSubscription<RemoteMessage>? _messageOpenedSub;
  StreamSubscription<String>? _tokenRefreshSub;
  final StreamController<Map<String, dynamic>> _tapPayloadController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _orderAlertController =
      StreamController<Map<String, dynamic>>.broadcast();
  bool _initialized = false;
  String _boundStoreId = '';
  Map<String, dynamic>? _pendingTapPayload;
  bool _localNotificationsReady = false;

  Stream<Map<String, dynamic>> get notificationTapStream =>
      _tapPayloadController.stream;
  Stream<Map<String, dynamic>> get orderAlertStream =>
      _orderAlertController.stream;

  bool get _supportsPersistentOrderAlert {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }

  Map<String, dynamic>? consumePendingTapPayload() {
    final payload = _pendingTapPayload;
    _pendingTapPayload = null;
    return payload;
  }

  Future<void> initialize() async {
    if (_initialized) return;

    await _ensureLocalNotificationsInitialized(withTapHandler: true);

    await requestPermission();

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

    final launchDetails =
        await _localNotifications.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final payload = _decodePayload(
        launchDetails?.notificationResponse?.payload,
      );
      if (payload != null) {
        _emitTapPayload(payload);
      }
    }

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleRemoteMessageTap(initialMessage);
    }
    _initialized = true;
  }

  Future<NotificationSettings> requestPermission() {
    return _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  Future<NotificationSettings> getNotificationSettings() {
    return _messaging.getNotificationSettings();
  }

  Future<void> _ensureLocalNotificationsInitialized({
    required bool withTapHandler,
  }) async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: withTapHandler
          ? (response) {
              final payload = _decodePayload(response.payload);
              if (payload != null) {
                _emitTapPayload(payload);
              }
            }
          : null,
    );

    if (_localNotificationsReady) {
      return;
    }

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
    _localNotificationsReady = true;
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
      'body':
          (message.notification?.body ?? message.data['body'] ?? '').toString(),
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
      'fcmTokens': FieldValue.arrayUnion([token]),
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> showRemoteMessageAsLocal(RemoteMessage message) async {
    final payload = _payloadFromRemoteMessage(message);
    _emitOrderAlert(payload);
    if (_isOrderAlert(payload)) {
      await startPersistentOrderAlert(
        title: payload['title']?.toString(),
        body: payload['body']?.toString(),
        orderId: payload['orderId']?.toString(),
      );
    }
    if (message.notification != null) {
      return;
    }
    await _ensureLocalNotificationsInitialized(withTapHandler: false);
    await _showLocalAlert(payload);
  }

  Future<void> _showForegroundAlert(RemoteMessage message) async {
    final payload = _payloadFromRemoteMessage(message);
    _emitOrderAlert(payload);
    if (_isOrderAlert(payload)) {
      await startPersistentOrderAlert(
        title: payload['title']?.toString(),
        body: payload['body']?.toString(),
        orderId: payload['orderId']?.toString(),
      );
    }
    await _ensureLocalNotificationsInitialized(withTapHandler: false);
    await _showLocalAlert(payload);
  }

  Future<void> startPersistentOrderAlert({
    String? title,
    String? body,
    String? orderId,
  }) async {
    if (!_supportsPersistentOrderAlert) return;
    try {
      await _alertServiceChannel.invokeMethod('startOrderAlert', {
        'title':
            (title == null || title.trim().isEmpty) ? 'طلب جديد' : title.trim(),
        'body': (body == null || body.trim().isEmpty)
            ? 'لديك طلب جديد بانتظار القبول أو الرفض.'
            : body.trim(),
        'orderId': (orderId ?? '').trim(),
      });
    } catch (_) {
      // Ignore native alert service failures and keep local notification path.
    }
  }

  Future<void> stopPersistentOrderAlert() async {
    if (!_supportsPersistentOrderAlert) return;
    try {
      await _alertServiceChannel.invokeMethod('stopOrderAlert');
    } catch (_) {
      // Ignore stop failures.
    }
  }

  bool _isOrderAlert(Map<String, dynamic> payload) {
    final type = (payload['type'] ?? '').toString().toLowerCase();
    final explicitChannel =
        (payload['channelId'] ?? payload['androidChannelId'] ?? '')
            .toString()
            .toLowerCase();
    final urgentFlag = (payload['urgent'] ?? payload['playSound'] ?? '')
        .toString()
        .toLowerCase();
    return explicitChannel == _ordersChannelId.toLowerCase() ||
        urgentFlag == '1' ||
        urgentFlag == 'true' ||
        type.contains('order') ||
        type.contains('offer') ||
        type.contains('pickup') ||
        type.contains('courier');
  }

  Future<void> _showLocalAlert(Map<String, dynamic> payload) async {
    final title = (payload['title'] ?? 'إشعار جديد').toString();
    final body = (payload['body'] ?? '').toString();
    final isOrderAlert = _isOrderAlert(payload);
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

  void _emitOrderAlert(Map<String, dynamic> payload) {
    if (!_isOrderAlert(payload) || _orderAlertController.isClosed) {
      return;
    }
    _orderAlertController.add(payload);
  }
}
