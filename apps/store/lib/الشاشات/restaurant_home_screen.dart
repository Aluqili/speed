import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:speedstar_core/src/config/ops_runtime_config.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'package:speedstar_core/src/auth/login_screen_ar.dart';
import 'package:speedstar_core/speedstar_core.dart' show formatUnifiedOrderCode;

import 'store_settings_screen.dart';
import 'store_add_menu_item_screen.dart';
import 'store_full_menu_screen.dart';
import 'store_working_hours_screen.dart';
import 'store_wallet_screen.dart';
import 'store_change_requests_screen.dart';
import 'store_current_orders_screen.dart';
import 'store_notifications_screen.dart';
import 'store_order_details_screen.dart';
import 'store_promocode_screen.dart';
import 'chat_screen.dart';
import '../الخدمات/push_notification_service.dart';

const Color primaryColor = AppThemeArabic.storePrimary;
const Color backgroundColor = AppThemeArabic.storeBackground;
const _statusPriority = [
  'store_pending',
  'payment_review',
  'courier_searching',
  'courier_offer_pending',
  'courier_assigned',
  'pickup_ready',
  'picked_up',
  'arrived_to_client',
  'delivered',
  'store_rejected',
  'cancelled',
  'قيد المراجعة',
  'قيد التجهيز',
  'قيد التوصيل',
  'بانتظار المطعم',
  'تم التوصيل',
  'ملغي',
  'انتظار الدفع',
];

const Set<String> _dashboardNewStatuses = {
  'store_pending',
  'courier_searching',
  'courier_offer_pending',
  'courier_assigned',
  'pickup_ready',
  'قيد المراجعة',
  'قيد التجهيز',
  'بانتظار المطعم',
  'جاهز للتوصيل',
  'انتظار الدفع',
  'payment_review',
};

class StoreDashboardScreen extends StatefulWidget {
  final String restaurantId;
  const StoreDashboardScreen({super.key, required this.restaurantId});

  @override
  State<StoreDashboardScreen> createState() => _StoreDashboardScreenState();
}

class _StoreDashboardScreenState extends State<StoreDashboardScreen> {
  bool get _usesNativePersistentAlert {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }

  // إعادة تحميل بيانات المطعم عند فتح القائمة الجانبية
  void _onDrawerChanged(bool isOpened) {
    if (isOpened) {
      _loadRestaurantInfo();
    }
  }

  bool temporarilyClosed = false;
  bool autoAcceptOrders = false;
  bool _ringtoneEnabled = true;
  double _ringtoneVolume = 1.0;
  final Set<String> _notifiedOrders = <String>{};
  StreamSubscription<QuerySnapshot>? _ordersSubscription;
  StreamSubscription<Map<String, dynamic>>? _pushOrderAlertSubscription;
  Timer? _storeRingtoneTimer;
  bool _hasPendingStoreOrders = false;
  final AudioPlayer _ringtonePlayer = AudioPlayer();

  String? restaurantName;
  String? logoUrl;

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openPage(Widget page) async {
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _openOrderDetails(String orderId, Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoreOrderDetailsScreen(orderData: {
          'docId': orderId,
          ...data,
        }),
      ),
    );
  }

  String _getOrderStatus(Map<String, dynamic> data) {
    return (data['orderStatus'] ?? data['status'] ?? '').toString().trim();
  }

  String _displayOrderStatus(String status) {
    switch (status) {
      case 'store_pending':
        return 'قيد المراجعة';
      case 'payment_review':
        return 'بانتظار مراجعة الدفع';
      case 'courier_searching':
        return 'جاري البحث عن مندوب';
      case 'courier_offer_pending':
        return 'بانتظار رد المندوب';
      case 'courier_assigned':
        return 'تم تعيين مندوب';
      case 'pickup_ready':
        return 'جاهز للاستلام';
      case 'picked_up':
      case 'arrived_to_client':
      case 'delivered':
      case 'وصل إلى العميل':
      case 'تم التوصيل':
        return 'تم الاستلام من المطعم';
      case 'store_rejected':
        return 'مرفوض من المتجر';
      case 'cancelled':
      case 'ملغي':
        return 'ملغي';
      default:
        return status.isEmpty ? '—' : status;
    }
  }

  Color _orderStatusColor(String status) {
    switch (status) {
      case 'انتظار الدفع':
      case 'payment_review':
      case 'store_pending':
      case 'قيد المراجعة':
      case 'بانتظار المطعم':
        return Colors.orange;
      case 'courier_searching':
      case 'courier_offer_pending':
      case 'courier_assigned':
        return const Color(0xFF2563EB);
      case 'pickup_ready':
      case 'جاهز للتوصيل':
      case 'picked_up':
      case 'arrived_to_client':
      case 'قيد التجهيز':
      case 'قيد التوصيل':
        return const Color(0xFF0F766E);
      case 'delivered':
      case 'تم التوصيل':
      case 'وصل إلى العميل':
        return AppThemeArabic.clientSuccess;
      case 'store_rejected':
      case 'cancelled':
      case 'ملغي':
        return AppThemeArabic.clientError;
      default:
        return AppThemeArabic.storeTextSecondary;
    }
  }

  String _formatAmount(num value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
  }

  Map<String, dynamic> _promoDetails(Map<String, dynamic> data) {
    final promo = data['promocode'];
    if (promo is Map<String, dynamic>) return promo;
    if (promo is Map) {
      return promo.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  num _resolveStoreDiscount(Map<String, dynamic> data) {
    final restaurantId = (data['restaurantId'] ?? '').toString().trim();
    final promo = _promoDetails(data);
    final promoRestaurantId = (promo['restaurantId'] ?? '').toString().trim();
    final discountScope = (promo['discountScope'] ?? '').toString().trim();
    final discountAmount = (data['discountAmount'] as num?) ?? 0;
    if (restaurantId.isEmpty || promoRestaurantId != restaurantId) return 0;
    if (discountScope == 'delivery_fee' || discountAmount <= 0) return 0;
    return discountAmount;
  }

  bool _hasStoreAppliedDiscount(Map<String, dynamic> data) {
    return _resolveStoreDiscount(data) > 0;
  }

  num _resolveStoreReceivable(Map<String, dynamic> data) {
    final subtotal = (data['total'] as num?) ?? 0;
    final storeDiscount = _resolveStoreDiscount(data);
    final receivable = subtotal - storeDiscount;
    return receivable < 0 ? 0 : receivable;
  }

  Future<void> _setOrderStatus(String orderId, String status,
      {Map<String, dynamic>? extra}) async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
        'orderStatus': status,
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        ...?extra,
      });
    } on FirebaseException catch (e) {
      _showErrorMessage('تعذر تحديث حالة الطلب: ${e.message ?? e.code}');
      rethrow;
    }
  }

  @override
  void initState() {
    super.initState();
    _saveRestaurantId();
    _checkUserRole();
    _loadTemporaryStatus();
    _loadAutoAccept();
    _loadOpsRuntimeConfig();
    _loadRestaurantInfo();
    _listenForPushOrderAlerts();
    _listenForIncomingStoreOrders();
  }

  Future<void> _loadOpsRuntimeConfig() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.fetchAndActivate();
      final ops = OpsRuntimeConfig.fromRemoteConfig(rc, appKey: 'store');
      if (!mounted) return;
      setState(() {
        _ringtoneEnabled = ops.ringtoneEnabled;
        _ringtoneVolume = ops.ringtoneVolume;
      });
    } catch (_) {
      // Keep defaults
    }
  }

  Future<void> _saveRestaurantId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('restaurantId', widget.restaurantId);
  }

  Future<void> _checkUserRole() async {
    if (FirebaseAuth.instance.currentUser == null) {
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  Future<void> _loadTemporaryStatus() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .get();
      if (!mounted) return;
      final data = doc.data() ?? {};
      setState(() => temporarilyClosed = data['temporarilyClosed'] == true);
    } on FirebaseException catch (e) {
      _showErrorMessage('تعذر تحميل حالة الإغلاق: ${e.message ?? e.code}');
    }
  }

  Future<void> _toggleTemporaryClosure(bool value) async {
    final previous = temporarilyClosed;
    setState(() => temporarilyClosed = value);
    try {
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .update({'temporarilyClosed': value});
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() => temporarilyClosed = previous);
      _showErrorMessage(
          'لا تملك صلاحية تعديل حالة الإغلاق: ${e.message ?? e.code}');
    }
  }

  Future<void> _loadAutoAccept() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .get();
      if (!mounted) return;
      final data = doc.data() ?? {};
      setState(() {
        autoAcceptOrders = data['autoAcceptOrders'] == true;
      });
      FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .snapshots()
          .listen((doc) {
        if (!mounted) return;
        final liveData = doc.data() ?? {};
        setState(() {
          autoAcceptOrders = liveData['autoAcceptOrders'] == true;
        });
      }, onError: (error) {
        if (error is FirebaseException) {
          _showErrorMessage(
              'تعذر متابعة إعدادات القبول التلقائي: ${error.message ?? error.code}');
        }
      });
    } on FirebaseException catch (e) {
      _showErrorMessage(
          'تعذر تحميل إعدادات القبول التلقائي: ${e.message ?? e.code}');
    }
  }

  Future<void> _loadRestaurantInfo() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .get();
      if (!mounted) return;
      if (doc.exists) {
        final data = doc.data() ?? {};
        setState(() {
          restaurantName = (data['name'] ?? '').toString();
          logoUrl = (data['logoImageUrl'] ?? '').toString();
        });
      }
    } on FirebaseException catch (e) {
      _showErrorMessage('تعذر تحميل بيانات المتجر: ${e.message ?? e.code}');
    }
  }

  bool _isStorePendingStatus(String status) {
    return status == 'store_pending' ||
        status == 'قيد المراجعة' ||
        status == 'بانتظار المطعم';
  }

  Future<void> _playIncomingOrderTone() async {
    if (!_ringtoneEnabled) return;
    try {
      await _ringtonePlayer.setVolume(_ringtoneVolume);
      await _ringtonePlayer.setPlayerMode(PlayerMode.lowLatency);
      await _ringtonePlayer.play(
        AssetSource('sounds/incoming_order.mp3'),
        volume: _ringtoneVolume,
      );
      return;
    } catch (_) {
      // Fallback to system sound if custom file is missing.
    }

    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {
      // Ignore tone errors on unsupported devices.
    }
  }

  void _startStoreRingtoneLoop() {
    if (!_ringtoneEnabled) return;
    if (_usesNativePersistentAlert) {
      unawaited(
        PushNotificationService.instance.startPersistentOrderAlert(),
      );
      return;
    }
    _storeRingtoneTimer ??= Timer.periodic(const Duration(seconds: 6), (_) {
      if (!_hasPendingStoreOrders || !_ringtoneEnabled) return;
      _playIncomingOrderTone();
    });
  }

  void _stopStoreRingtoneLoop() {
    if (_usesNativePersistentAlert) {
      unawaited(PushNotificationService.instance.stopPersistentOrderAlert());
    }
    _storeRingtoneTimer?.cancel();
    _storeRingtoneTimer = null;
    _ringtonePlayer.stop();
  }

  void _updateStoreRingtoneLoop(bool hasPendingOrders) {
    _hasPendingStoreOrders = hasPendingOrders;
    if (_hasPendingStoreOrders) {
      _startStoreRingtoneLoop();
    } else {
      _stopStoreRingtoneLoop();
    }
  }

  void _listenForIncomingStoreOrders() {
    _ordersSubscription?.cancel();
    _ordersSubscription = FirebaseFirestore.instance
        .collection('orders')
        .where('restaurantId', isEqualTo: widget.restaurantId)
        .snapshots()
        .listen((snapshot) {
      final pendingDocs = snapshot.docs.where((doc) {
        final data = doc.data();
        return _isStorePendingStatus(_getOrderStatus(data));
      }).toList();

      _updateStoreRingtoneLoop(pendingDocs.isNotEmpty);

      for (final doc in pendingDocs) {
        final orderId = doc.id;
        if (_notifiedOrders.contains(orderId)) continue;
        _notifiedOrders.add(orderId);
        if (!_usesNativePersistentAlert) {
          _playIncomingOrderTone();
        }

        if (autoAcceptOrders && !temporarilyClosed) {
          _setOrderStatus(orderId, 'courier_searching');
        }
      }
    }, onError: (error) {
      if (error is FirebaseException) {
        _showErrorMessage(
            'تعذر متابعة الطلبات الجديدة: ${error.message ?? error.code}');
      }
    });
  }

  void _listenForPushOrderAlerts() {
    _pushOrderAlertSubscription?.cancel();
    _pushOrderAlertSubscription =
        PushNotificationService.instance.orderAlertStream.listen((payload) {
      final orderId = (payload['orderId'] ?? '').toString().trim();
      if (orderId.isNotEmpty && _notifiedOrders.contains(orderId)) {
        return;
      }
      if (orderId.isNotEmpty) {
        _notifiedOrders.add(orderId);
      }
      if (_usesNativePersistentAlert) {
        unawaited(
          PushNotificationService.instance.startPersistentOrderAlert(
            title: payload['title']?.toString(),
            body: payload['body']?.toString(),
            orderId: orderId,
          ),
        );
      } else {
        _playIncomingOrderTone();
      }
    });
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _pushOrderAlertSubscription?.cancel();
    _stopStoreRingtoneLoop();
    _ringtonePlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: backgroundColor,
        onDrawerChanged: _onDrawerChanged,
        appBar: AppBar(
          title: const Text('لوحة تحكم المطعم'),
          centerTitle: true,
          actions: [
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('restaurantId', isEqualTo: widget.restaurantId)
                  .snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? const [];
                final unreadCount = docs.where((doc) {
                  final data = doc.data();
                  final isRead = data['read'] == true || data['isRead'] == true;
                  return !isRead;
                }).length;

                return IconButton(
                  tooltip: 'الإشعارات',
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.notifications_none, color: primaryColor),
                      if (unreadCount > 0)
                        Positioned(
                          right: -3,
                          top: -3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            constraints: const BoxConstraints(minWidth: 18),
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  onPressed: () async {
                    final unreadDocs = docs.where((doc) {
                      final data = doc.data();
                      final isRead =
                          data['read'] == true || data['isRead'] == true;
                      return !isRead;
                    });

                    if (unreadDocs.isNotEmpty) {
                      final batch = FirebaseFirestore.instance.batch();
                      for (final doc in unreadDocs) {
                        batch.update(doc.reference, {
                          'read': true,
                          'isRead': true,
                          'readAt': FieldValue.serverTimestamp(),
                        });
                      }
                      try {
                        await batch.commit();
                      } catch (_) {}
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StoreNotificationsScreen(
                          restaurantId: widget.restaurantId,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.support_agent, color: primaryColor),
              tooltip: 'الدعم',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(userId: widget.restaurantId),
                  ),
                );
              },
            ),
          ],
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
        ),
        drawer: Drawer(
          backgroundColor: AppThemeArabic.storeBackground,
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppThemeArabic.storePrimary, Color(0xFF14B8A6)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppThemeArabic.storePrimary.withOpacity(0.18),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          logoUrl != null && logoUrl!.isNotEmpty
                              ? CircleAvatar(
                                  radius: 34,
                                  backgroundColor: Colors.white,
                                  backgroundImage: NetworkImage(logoUrl!),
                                )
                              : Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  child: const Icon(
                                    Icons.storefront_rounded,
                                    color: Colors.white,
                                    size: 34,
                                  ),
                                ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  restaurantName != null &&
                                          restaurantName!.isNotEmpty
                                      ? restaurantName!
                                      : 'اسم المطعم غير متوفر',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'Tajawal',
                                    fontSize: 20,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  temporarilyClosed
                                      ? 'التطبيق في وضع الإيقاف المؤقت'
                                      : 'جاهز لاستقبال الطلبات وإدارتها',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontFamily: 'Tajawal',
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.badge_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'معرف المتجر: ${widget.restaurantId}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Tajawal',
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _drawerSectionLabel('التشغيل اليومي'),
                _drawerTile(
                  icon: Icons.add,
                  iconBg: Colors.orange.shade50,
                  text: 'إضافة عنصر جديد',
                  onTap: () async {
                    Navigator.pop(context);
                    await _openPage(StoreAddMenuItemScreen(
                        restaurantId: widget.restaurantId));
                  },
                ),
                _drawerTile(
                  icon: Icons.menu_book,
                  iconBg: Colors.blue.shade50,
                  text: 'القائمة الكاملة',
                  onTap: () async {
                    Navigator.pop(context);
                    await _openPage(
                        StoreFullMenuScreen(restaurantId: widget.restaurantId));
                  },
                ),
                _drawerTile(
                  icon: Icons.receipt_long,
                  iconBg: Colors.purple.shade50,
                  text: 'الطلبات الحالية',
                  onTap: () async {
                    Navigator.pop(context);
                    await _openPage(StoreCurrentOrdersScreen(
                        restaurantId: widget.restaurantId));
                  },
                ),
                _drawerTile(
                  icon: Icons.access_time,
                  iconBg: Colors.green.shade50,
                  text: 'أوقات الدوام',
                  onTap: () async {
                    Navigator.pop(context);
                    await _openPage(StoreWorkingHoursScreen(
                        restaurantId: widget.restaurantId));
                  },
                ),
                _drawerTile(
                  icon: Icons.account_balance_wallet,
                  iconBg: Colors.amber.shade50,
                  text: 'محفظتي',
                  onTap: () async {
                    Navigator.pop(context);
                    await _openPage(
                        StoreWalletScreen(restaurantId: widget.restaurantId));
                  },
                ),
                _drawerTile(
                  icon: Icons.local_offer_outlined,
                  iconBg: Colors.deepOrange.shade50,
                  iconColor: Colors.deepOrange,
                  text: 'العروض والخصومات',
                  onTap: () async {
                    Navigator.pop(context);
                    await _openPage(StorePromocodeScreen(
                        restaurantId: widget.restaurantId));
                  },
                ),
                Card(
                  elevation: 0,
                  color: Colors.red.shade50,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: Colors.red.shade100),
                  ),
                  child: SwitchListTile(
                    title: const Text('إيقاف مؤقت لاستقبال الطلبات',
                        style: TextStyle(fontFamily: 'Tajawal')),
                    value: temporarilyClosed,
                    onChanged: _toggleTemporaryClosure,
                    secondary: const Icon(Icons.pause_circle_filled,
                        color: Colors.red),
                    activeColor: primaryColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                ),
                const SizedBox(height: 8),
                _drawerSectionLabel('الإدارة والإعدادات'),
                _drawerTile(
                  icon: Icons.settings,
                  iconBg: Colors.grey.shade200,
                  text: 'الإعدادات',
                  iconColor: Colors.grey,
                  onTap: () async {
                    Navigator.pop(context);
                    await _openPage(
                        StoreSettingsScreen(restaurantId: widget.restaurantId));
                  },
                ),
                const SizedBox(height: 2),
                _drawerTile(
                  icon: Icons.approval,
                  iconBg: Colors.indigo.shade50,
                  text: 'طلبات تعديل الإدارة',
                  iconColor: Colors.indigo,
                  onTap: () async {
                    Navigator.pop(context);
                    await _openPage(StoreChangeRequestsScreen(
                        restaurantId: widget.restaurantId));
                  },
                ),
                const SizedBox(height: 14),
                _drawerTile(
                  icon: Icons.logout,
                  iconBg: Colors.red.shade100,
                  text: 'تسجيل الخروج',
                  iconColor: Colors.red,
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await FirebaseAuth.instance.signOut();
                    await prefs.remove('userType');
                    if (!mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const LoginScreenArabic(
                          allowRegister: false,
                          allowGoogleSignIn: false,
                          allowPhoneSignIn: false,
                          allowGuestSignIn: false,
                        ),
                      ),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('restaurantId', isEqualTo: widget.restaurantId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: primaryColor));
            }
            if (snapshot.hasError) {
              return const Center(
                child: Text('تعذر تحميل الطلبات حالياً',
                    style: TextStyle(fontFamily: 'Tajawal', color: Colors.red)),
              );
            }
            var docs = snapshot.data?.docs ?? [];
            docs = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              return _statusPriority.contains(_getOrderStatus(data));
            }).toList();

            // رتب حسب أولوية الحالة ثم الإنشاء
            docs.sort((a, b) {
              final da = a.data() as Map<String, dynamic>;
              final db = b.data() as Map<String, dynamic>;
              final sa = _statusPriority.indexOf(_getOrderStatus(da));
              final sb = _statusPriority.indexOf(_getOrderStatus(db));
              if (sa != sb) return sa.compareTo(sb);
              final ta = (a['createdAt'] as Timestamp?);
              final tb = (b['createdAt'] as Timestamp?);
              if (ta != null && tb != null) return tb.compareTo(ta);
              return 0;
            });

            if (docs.isEmpty) {
              return const Center(
                child: Text('🕒 لا توجد طلبات حالياً',
                    style:
                        TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
              );
            }

            final newDocs = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final status = _getOrderStatus(data);
              return _dashboardNewStatuses.contains(status);
            }).toList();

            final finishedDocs = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final status = _getOrderStatus(data);
              return !_dashboardNewStatuses.contains(status);
            }).toList();

            final showNewHeader = newDocs.isNotEmpty;
            final showFinishedHeader = finishedDocs.isNotEmpty;
            return ListView(
              padding: const EdgeInsets.all(14),
              children: [
                _buildStoreHeroCard(
                  restaurantName: restaurantName,
                  totalCount: docs.length,
                  newCount: newDocs.length,
                  finishedCount: finishedDocs.length,
                ),
                const SizedBox(height: 14),
                _buildQuickActionsPanel(),
                const SizedBox(height: 16),
                if (showNewHeader) ...[
                  _buildSectionTitle(
                      'الطلبات الجديدة', Icons.local_fire_department_outlined),
                  const SizedBox(height: 10),
                  ...newDocs.map((doc) => _buildOrderPreviewCard(
                        doc.id,
                        doc.data() as Map<String, dynamic>,
                        highlight: true,
                      )),
                  const SizedBox(height: 12),
                ],
                if (showFinishedHeader) ...[
                  _buildSectionTitle(
                      'متابعة الطلبات', Icons.track_changes_outlined),
                  const SizedBox(height: 10),
                  ...finishedDocs.map((doc) => _buildOrderPreviewCard(
                        doc.id,
                        doc.data() as Map<String, dynamic>,
                      )),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _drawerTile({
    required IconData icon,
    required String text,
    Color? iconColor,
    Color? iconBg,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          splashColor: primaryColor.withOpacity(0.10),
          highlightColor: primaryColor.withOpacity(0.06),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: primaryColor.withOpacity(0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.025),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: iconBg ?? primaryColor.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Icon(icon, color: iconColor ?? primaryColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_left_rounded,
                  color: Colors.black.withOpacity(0.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _drawerSectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppThemeArabic.storeTextSecondary,
        ),
      ),
    );
  }

  Widget _buildDashboardStatsCard({
    required int totalCount,
    required int newCount,
    required int finishedCount,
  }) {
    Widget statItem({
      required IconData icon,
      required String label,
      required int value,
      required Color color,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 6),
              Text(
                '$value',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          statItem(
            icon: Icons.receipt_long_rounded,
            label: 'إجمالي الطلبات',
            value: totalCount,
            color: primaryColor,
          ),
          const SizedBox(width: 8),
          statItem(
            icon: Icons.fiber_new_rounded,
            label: 'طلبات جديدة',
            value: newCount,
            color: Colors.orange,
          ),
          const SizedBox(width: 8),
          statItem(
            icon: Icons.check_circle_rounded,
            label: 'منتهية',
            value: finishedCount,
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildStoreHeroCard({
    required String? restaurantName,
    required int totalCount,
    required int newCount,
    required int finishedCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppThemeArabic.storePrimary, Color(0xFF14B8A6)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white.withOpacity(0.16),
                backgroundImage:
                    (logoUrl ?? '').isNotEmpty ? NetworkImage(logoUrl!) : null,
                child: (logoUrl ?? '').isEmpty
                    ? const Icon(Icons.storefront_rounded, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (restaurantName ?? '').trim().isEmpty
                          ? 'لوحة المطعم'
                          : restaurantName!.trim(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      temporarilyClosed
                          ? 'استقبال الطلبات متوقف مؤقتًا'
                          : 'جاهز لمتابعة الطلبات والعمليات اليومية',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDashboardStatsCard(
            totalCount: totalCount,
            newCount: newCount,
            finishedCount: finishedCount,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsPanel() {
    Widget quickAction({
      required String label,
      required IconData icon,
      required VoidCallback onTap,
      Color? color,
    }) {
      final resolvedColor = color ?? AppThemeArabic.storePrimary;
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            decoration: BoxDecoration(
              color: resolvedColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Icon(icon, color: resolvedColor),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('إجراءات سريعة', Icons.dashboard_customize_outlined),
        const SizedBox(height: 10),
        Row(
          children: [
            quickAction(
              label: 'إضافة صنف',
              icon: Icons.add_box_outlined,
              onTap: () => _openPage(
                  StoreAddMenuItemScreen(restaurantId: widget.restaurantId)),
            ),
            const SizedBox(width: 10),
            quickAction(
              label: 'القائمة الكاملة',
              icon: Icons.menu_book_outlined,
              onTap: () => _openPage(
                  StoreFullMenuScreen(restaurantId: widget.restaurantId)),
            ),
            const SizedBox(width: 10),
            quickAction(
              label: 'الطلبات',
              icon: Icons.receipt_long_outlined,
              onTap: () => _openPage(
                  StoreCurrentOrdersScreen(restaurantId: widget.restaurantId)),
            ),
            const SizedBox(width: 10),
            quickAction(
              label: 'المحفظة',
              icon: Icons.account_balance_wallet_outlined,
              onTap: () => _openPage(
                  StoreWalletScreen(restaurantId: widget.restaurantId)),
              color: Colors.orange,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppThemeArabic.storePrimary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppThemeArabic.storePrimary),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _buildOrderPreviewCard(
    String docId,
    Map<String, dynamic> data, {
    bool highlight = false,
  }) {
    final status = _getOrderStatus(data);
    final unifiedOrderCode = formatUnifiedOrderCode(
      orderNumber: data['orderNumber'],
      orderId: data['orderId'],
      docId: docId,
    );
    final receivable = _resolveStoreReceivable(data);
    final itemCount =
        (data['items'] is List) ? (data['items'] as List).length : 0;
    final statusColor = _orderStatusColor(status);
    final isAwaitingStoreDecision =
        status == 'store_pending' || status == 'قيد المراجعة';
    final hasStoreDiscount = _hasStoreAppliedDiscount(data);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border:
            Border.all(color: statusColor.withOpacity(highlight ? 0.24 : 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _openOrderDetails(docId, data),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      highlight
                          ? Icons.priority_high_rounded
                          : Icons.receipt_long_rounded,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          unifiedOrderCode,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasStoreDiscount
                              ? 'صافي المتجر بعد خصم ممول من المتجر'
                              : 'مستحق المتجر من الطلب',
                          style: const TextStyle(
                              color: AppThemeArabic.storeTextSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _displayOrderStatus(status),
                      style: TextStyle(
                          color: statusColor, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _buildOrderMetaChip(
                          Icons.shopping_bag_outlined, '$itemCount أصناف')),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _buildOrderMetaChip(Icons.payments_outlined,
                          '${_formatAmount(receivable)} ج.س')),
                ],
              ),
              if (isAwaitingStoreDecision) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            await _setOrderStatus(docId, 'courier_searching',
                                extra: {
                                  'assignedDriverId': null,
                                  'candidateDrivers': [],
                                  'driverResponded': false,
                                  'driverResponseTime': null,
                                });
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0F9D58),
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.check_circle_outline_rounded),
                          label: const Text('قبول'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await _setOrderStatus(docId, 'store_rejected');
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            backgroundColor: Colors.red.shade50,
                            side: BorderSide(color: Colors.red.shade200),
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('رفض'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderMetaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppThemeArabic.storeBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppThemeArabic.storePrimary),
          const SizedBox(width: 8),
          Expanded(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
