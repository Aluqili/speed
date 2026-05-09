import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../الشاشات/chat_screen.dart';
import '../الشاشات/client_notifications_screen.dart';
import '../الشاشات/client_order_details_screen.dart';
import '../الشاشات/client_support_screen.dart';
import '../الشاشات/restaurant_detail_screen.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const String _channelId = 'speedstar_client_alerts_v3';
  static const String _channelName = 'Speedstar';
  static const String _channelDescription =
      'تنبيهات الطلبات والدعم الفني والعروض';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<RemoteMessage>? _messageSub;
  StreamSubscription<String>? _tokenRefreshSub;
  bool _initialized = false;
  String _boundClientId = '';
  DateTime? _lastTokenSaveAt;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('ic_notification');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationPayload(response.payload);
      },
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      playSound: true,
      showBadge: true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    await requestPermissions();

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _messageSub?.cancel();
    _messageSub = FirebaseMessaging.onMessage.listen(_showForegroundAlert);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteMessageTap);
    unawaited(
      _messaging.getInitialMessage().then((message) {
        if (message != null) _handleRemoteMessageTap(message);
      }),
    );
    unawaited(
      _localNotifications.getNotificationAppLaunchDetails().then((details) {
        final response = details?.notificationResponse;
        if (details?.didNotificationLaunchApp == true && response != null) {
          _handleNotificationPayload(response.payload);
        }
      }),
    );
    _initialized = true;
  }

  Future<void> bindClient(String clientId) async {
    final id = clientId.trim();
    if (id.isEmpty) return;

    if (!_initialized) {
      await initialize();
    }
    await requestPermissions();

    if (id == _boundClientId) {
      final lastSaved = _lastTokenSaveAt;
      if (lastSaved == null ||
          DateTime.now().difference(lastSaved) > const Duration(minutes: 30)) {
        unawaited(_saveToken(id));
      }
      return;
    }

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
    _lastTokenSaveAt = DateTime.now();
  }

  Future<void> requestPermissions() async {
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  Future<void> _updateClientToken(String clientId, String token) async {
    await FirebaseFirestore.instance.collection('clients').doc(clientId).set({
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

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        icon: 'ic_notification',
        color: Color(0xFFFF6B00),
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        visibility: NotificationVisibility.public,
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
      payload: jsonEncode({
        ...message.data,
        'title': title,
        'body': body,
      }),
    );
  }

  void _handleRemoteMessageTap(RemoteMessage message) {
    openFromNotificationData(message.data);
  }

  void _handleNotificationPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) {
      _openNotificationsScreen();
      return;
    }
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        openFromNotificationData(
          decoded.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ),
        );
        return;
      }
    } catch (_) {}
    _openNotificationsScreen();
  }

  void openFromNotificationData(Map<String, dynamic> rawData) {
    final data = rawData.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
    final type = (data['type'] ?? '').toString().trim().toLowerCase();
    final source = (data['source'] ?? '').toString().trim().toLowerCase();
    final clientId = _notificationClientId(data);
    final orderId = _readFirst(data, const [
      'orderId',
      'orderDocId',
      'order_id',
      'id',
    ]);
    final restaurantId = _notificationRestaurantId(data);
    final conversationId =
        (data['conversationId'] ?? data['chatId'] ?? '').toString().trim();
    final senderId = (data['senderId'] ?? '').toString().trim();

    if (clientId.isEmpty) {
      _openNotificationsScreen();
      return;
    }

    if (type == 'support_message' || source == 'support') {
      _pushWhenReady(
        ClientSupportScreen(userId: clientId),
      );
      return;
    }

    if (type == 'courier_chat_message' ||
        type == 'chat_message' ||
        source == 'direct-chat') {
      if (conversationId.isNotEmpty && senderId.isNotEmpty) {
        _pushWhenReady(
          ChatScreen(
            currentUserId: clientId,
            otherUserId: senderId,
            currentUserRole: 'client',
            chatId: conversationId,
            currentUserName: '',
          ),
        );
        return;
      }
    }

    if (orderId.isNotEmpty && _looksLikeOrderNotification(data)) {
      _pushWhenReady(ClientOrderDetailsScreen(orderId: orderId));
      return;
    }

    if (restaurantId.isNotEmpty && _looksLikeRestaurantNotification(data)) {
      unawaited(_openRestaurantFromNotification(data, restaurantId, clientId));
      return;
    }

    _openNotificationsScreen(clientId: clientId);
  }

  String _readFirst(Map<String, String> data, List<String> keys) {
    for (final key in keys) {
      final value = (data[key] ?? '').trim();
      if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
    }
    return '';
  }

  bool _containsAny(Map<String, String> data, List<String> needles) {
    final haystack = [
      data['type'],
      data['source'],
      data['category'],
      data['title'],
      data['body'],
      data['message'],
    ].map((value) => (value ?? '').toLowerCase()).join(' ');
    return needles.any(haystack.contains);
  }

  bool _looksLikeOrderNotification(Map<String, String> data) {
    return _containsAny(data, const [
      'order',
      'طلب',
      'payment',
      'دفع',
      'courier',
      'مندوب',
      'pickup',
    ]);
  }

  bool _looksLikeRestaurantNotification(Map<String, String> data) {
    return _containsAny(data, const [
      'offer',
      'promo',
      'restaurant',
      'store',
      'عرض',
      'مطعم',
      'متجر',
    ]);
  }

  String _notificationRestaurantId(Map<String, String> data) {
    return _readFirst(data, const [
      'restaurantId',
      'restaurantUid',
      'storeId',
      'storeUid',
      'merchantId',
      'vendorId',
      'shopId',
      'targetRestaurantId',
    ]);
  }

  Future<void> _openRestaurantFromNotification(
    Map<String, String> data,
    String restaurantId,
    String clientId,
  ) async {
    Map<String, dynamic> restaurant = const {};
    try {
      final doc = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(restaurantId)
          .get();
      restaurant = doc.data() ?? const {};
    } catch (_) {}

    String firstText(List<dynamic> values) {
      for (final value in values) {
        final text = (value ?? '').toString().trim();
        if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
      }
      return '';
    }

    _pushWhenReady(
      RestaurantDetailScreen(
        restaurantId: restaurantId,
        name: firstText([
          data['restaurantName'],
          data['storeName'],
          restaurant['name'],
          data['title'],
        ]),
        image: firstText([
          data['image'],
          data['imageUrl'],
          data['restaurantImage'],
          restaurant['coverImage'],
          restaurant['logoImageUrl'],
          restaurant['imageUrl'],
          restaurant['image'],
        ]),
        offers: firstText([
          data['offers'],
          data['offerText'],
          data['body'],
          restaurant['offers'],
        ]),
        clientId: clientId,
      ),
    );
  }

  String _notificationClientId(Map<String, String> data) {
    final fromPayload = (data['userId'] ??
            data['receiverId'] ??
            data['recipientId'] ??
            data['clientId'] ??
            data['clientUid'] ??
            data['targetUserId'] ??
            '')
        .trim();
    if (fromPayload.isNotEmpty) return fromPayload;
    if (_boundClientId.trim().isNotEmpty) return _boundClientId.trim();
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  void _openNotificationsScreen({String? clientId}) {
    final id = (clientId ?? _boundClientId).trim().isNotEmpty
        ? (clientId ?? _boundClientId).trim()
        : (FirebaseAuth.instance.currentUser?.uid ?? '');
    if (id.isEmpty) return;
    _pushWhenReady(ClientNotificationsScreen(clientId: id));
  }

  void _pushWhenReady(Widget screen, {int attempt = 0}) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      if (attempt > 40) return;
      Future.delayed(const Duration(milliseconds: 250), () {
        _pushWhenReady(screen, attempt: attempt + 1);
      });
      return;
    }
    navigator.push(MaterialPageRoute(builder: (_) => screen));
  }
}
