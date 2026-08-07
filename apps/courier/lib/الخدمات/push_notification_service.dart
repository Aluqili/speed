import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../الشاشات/courier_notification_details_screen.dart';
import '../الشاشات/courier_new_orders_screen.dart';
import '../الشاشات/courier_order_details_screen.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const String _channelId = 'speedstar_alerts';
  static const String _ordersChannelId = 'speedstar_orders_incoming_v4';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<RemoteMessage>? _messageSub;
  StreamSubscription<String>? _tokenRefreshSub;
  bool _initialized = false;
  bool _localNotificationsReady = false;
  String _boundDriverId = '';

  Future<void> initialize() async {
    if (_initialized) return;

    await _ensureLocalNotificationsInitialized();

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

  Future<void> _ensureLocalNotificationsInitialized() async {
    if (_localNotificationsReady) return;

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
    _localNotificationsReady = true;
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
    await _ensureLocalNotificationsInitialized();
    await _showRemoteMessageAsLocal(message);
  }

  Future<void> showRemoteMessageAsLocal(RemoteMessage message) async {
    if (message.notification != null) return;
    await _ensureLocalNotificationsInitialized();
    await _showRemoteMessageAsLocal(message);
  }

  Future<void> _showRemoteMessageAsLocal(RemoteMessage message) async {
    final title =
        (message.notification?.title ?? message.data['title'] ?? 'إشعار جديد')
            .toString();
    final body =
        (message.notification?.body ?? message.data['body'] ?? '').toString();
    final type = (message.data['type'] ?? '').toString().toLowerCase();
    if (type == 'courier_offer_pending') return;
    final tone = (message.data['tone'] ?? '').toString().toLowerCase();
    // اعتماد الطلب (courier_assigned) تأكيد وليس عرضًا جديدًا، فلا يستخدم نغمة/قناة العروض العاجلة.
    final isOrderAlert = type != 'courier_assigned' &&
        (tone == 'urgent' || type == 'courier_offer_pending');
    final androidChannelId = isOrderAlert ? _ordersChannelId : _channelId;
    final imageUrl = _extractNotificationImageUrl(message.data);
    final bigPicture = await _buildBigPictureStyle(imageUrl);

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
        autoCancel: true,
        sound: isOrderAlert
            ? const RawResourceAndroidNotificationSound('incoming_order')
            : null,
        styleInformation: bigPicture,
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
        if (imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      }),
    );
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _extractFirstUrl(String text) {
    final match =
        RegExp(r'https?:\/\/[^\s]+', caseSensitive: false).firstMatch(text);
    if (match == null) return '';
    return match.group(0)?.replaceAll(RegExp(r'[\]\[\)\(>,،؛!؟.,]+$'), '') ??
        '';
  }

  String _extractNotificationImageUrl(Map<String, dynamic> data) {
    return _firstNonEmpty([
      data['imageUrl'],
      data['image'],
      data['photoUrl'],
      data['proofImageUrl'],
      data['receiptImageUrl'],
    ]);
  }

  String _extractNotificationLink(Map<String, dynamic> data) {
    final body = (data['body'] ?? '').toString();
    return _firstNonEmpty([
      data['receiptUrl'],
      data['url'],
      data['link'],
      _extractFirstUrl(body),
    ]);
  }

  bool _isLikelyImageUrl(String url) {
    final clean = url.trim().toLowerCase();
    if (clean.isEmpty) return false;
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      return false;
    }
    return clean.contains('.jpg') ||
        clean.contains('.jpeg') ||
        clean.contains('.png') ||
        clean.contains('.webp') ||
        clean.contains('.gif') ||
        clean.contains('.avif') ||
        clean.contains('.bmp') ||
        clean.contains('.heic') ||
        clean.contains('.heif') ||
        clean.contains('.tif') ||
        clean.contains('.tiff') ||
        clean.contains('/image/upload/') ||
        clean.contains('firebasestorage.googleapis.com') ||
        clean.contains('storage.googleapis.com');
  }

  Future<BigPictureStyleInformation?> _buildBigPictureStyle(
      String imageUrl) async {
    if (!_isLikelyImageUrl(imageUrl)) return null;
    try {
      final response = await http
          .get(Uri.parse(imageUrl))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.toLowerCase().startsWith('image/')) return null;
      final bytes = response.bodyBytes;
      if (bytes.isEmpty || bytes.length > 6 * 1024 * 1024) return null;
      final image = ByteArrayAndroidBitmap(Uint8List.fromList(bytes));
      return BigPictureStyleInformation(
        image,
        hideExpandedLargeIcon: true,
      );
    } catch (_) {
      return null;
    }
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
    final orderId =
        (data['orderId'] ?? data['orderDocId'] ?? '').toString().trim();
    // Prefer the currently bound courier id from app state to avoid opening
    // order details with a stale/foreign id from push payload.
    final fallbackDriverId =
        (data['driverId'] ?? data['userId'] ?? '').toString().trim();
    final driverId = _boundDriverId.trim().isNotEmpty
        ? _boundDriverId.trim()
        : fallbackDriverId;
    final title = (data['title'] ?? 'إشعار').toString();
    final body = (data['body'] ?? '').toString();
    final type = (data['type'] ?? '').toString();
    final imageUrl = _extractNotificationImageUrl(data);
    final linkUrl = _extractNotificationLink(data);
    final createdAtRaw =
        (data['createdAt'] ?? data['sentAt'] ?? '').toString().trim();
    final createdAt = CourierNotificationDetailsScreen.parseCreatedAt(
      createdAtRaw,
    );
    if (driverId.isEmpty) return;

    void push() {
      final navigator = navigatorKey.currentState;
      if (navigator == null) return;
      if (type.toLowerCase() == 'courier_offer_pending') {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => CourierNewOrdersScreen(driverId: driverId),
          ),
        );
        return;
      }
      if (orderId.isNotEmpty && title.trim().isEmpty && body.trim().isEmpty) {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => CourierOrderDetailsScreen(
              orderId: orderId,
              driverId: driverId,
            ),
          ),
        );
        return;
      }
      navigator.push(
        MaterialPageRoute(
          builder: (_) => CourierNotificationDetailsScreen(
            driverId: driverId,
            title: title,
            body: body,
            type: type,
            orderId: orderId,
            imageUrl: imageUrl,
            linkUrl: linkUrl,
            createdAt: createdAt,
          ),
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => push());
  }
}
