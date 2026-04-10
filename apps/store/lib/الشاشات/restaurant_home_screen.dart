import 'dart:async';
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
import 'chat_screen.dart';
import 'store_current_orders_screen.dart';
import 'store_notifications_screen.dart';

const Color primaryColor = AppThemeArabic.clientPrimary;
const Color backgroundColor = AppThemeArabic.clientBackground;
const _statusPriority = [
  'store_pending',
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
};

class StoreDashboardScreen extends StatefulWidget {
  final String restaurantId;
  const StoreDashboardScreen({Key? key, required this.restaurantId})
      : super(key: key);

  @override
  State<StoreDashboardScreen> createState() => _StoreDashboardScreenState();
}

class _StoreDashboardScreenState extends State<StoreDashboardScreen> {
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

  String _getOrderStatus(Map<String, dynamic> data) {
    return (data['orderStatus'] ?? data['status'] ?? '').toString().trim();
  }

  String _displayOrderStatus(String status) {
    switch (status) {
      case 'store_pending':
        return 'قيد المراجعة';
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
        return AppThemeArabic.clientTextSecondary;
    }
  }

  Color _orderStatusBackground(String status) {
    return _orderStatusColor(status).withOpacity(0.12);
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
    _storeRingtoneTimer ??= Timer.periodic(const Duration(seconds: 6), (_) {
      if (!_hasPendingStoreOrders || !_ringtoneEnabled) return;
      _playIncomingOrderTone();
    });
  }

  void _stopStoreRingtoneLoop() {
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
        _playIncomingOrderTone();

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

  @override
  void dispose() {
    _ordersSubscription?.cancel();
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
          child: Container(
            color: Colors.white,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: primaryColor,
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(24)),
                  ),
                  child: DrawerHeader(
                    margin: EdgeInsets.zero,
                    padding: EdgeInsets.zero,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        logoUrl != null && logoUrl!.isNotEmpty
                            ? CircleAvatar(
                                radius: 44,
                                backgroundColor: Colors.white,
                                backgroundImage: NetworkImage(logoUrl!),
                              )
                            : CircleAvatar(
                                radius: 44,
                                backgroundColor: Colors.white,
                                child: Icon(Icons.restaurant,
                                    color: primaryColor, size: 48),
                              ),
                        const SizedBox(height: 12),
                        Text(
                          restaurantName != null && restaurantName!.isNotEmpty
                              ? restaurantName!
                              : 'اسم المطعم غير متوفر',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Tajawal',
                            fontSize: 20,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'معرف: ${widget.restaurantId}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontFamily: 'Tajawal',
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _drawerTile(
                  icon: Icons.add,
                  iconBg: Colors.orange.shade50,
                  text: ' إضافة عنصر جديد',
                  onTap: () async {
                    Navigator.pop(context);
                    await _openPage(StoreAddMenuItemScreen(
                        restaurantId: widget.restaurantId));
                  },
                ),
                const SizedBox(height: 2),
                _drawerTile(
                  icon: Icons.menu_book,
                  iconBg: Colors.blue.shade50,
                  text: ' القائمة الكاملة',
                  onTap: () async {
                    Navigator.pop(context);
                    await _openPage(
                        StoreFullMenuScreen(restaurantId: widget.restaurantId));
                  },
                ),
                const SizedBox(height: 2),
                _drawerTile(
                  icon: Icons.receipt_long,
                  iconBg: Colors.purple.shade50,
                  text: ' الطلبات الحالية',
                  onTap: () async {
                    Navigator.pop(context);
                    await _openPage(StoreCurrentOrdersScreen(
                        restaurantId: widget.restaurantId));
                  },
                ),
                const SizedBox(height: 2),
                _drawerTile(
                  icon: Icons.access_time,
                  iconBg: Colors.green.shade50,
                  text: ' أوقات الدوام',
                  onTap: () async {
                    Navigator.pop(context);
                    await _openPage(StoreWorkingHoursScreen(
                        restaurantId: widget.restaurantId));
                  },
                ),
                const SizedBox(height: 2),
                _drawerTile(
                  icon: Icons.account_balance_wallet,
                  iconBg: Colors.amber.shade50,
                  text: ' محفظتي',
                  onTap: () async {
                    Navigator.pop(context);
                    await _openPage(
                        StoreWalletScreen(restaurantId: widget.restaurantId));
                  },
                ),
                const SizedBox(height: 2),
                Card(
                  elevation: 0,
                  color: Colors.red.shade50,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.red.shade100),
                  ),
                  child: SwitchListTile(
                    title: const Text(' إيقاف مؤقت لاستقبال الطلبات',
                        style: TextStyle(fontFamily: 'Tajawal')),
                    value: temporarilyClosed,
                    onChanged: _toggleTemporaryClosure,
                    secondary: const Icon(Icons.pause_circle_filled,
                        color: Colors.red),
                    activeColor: primaryColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const Divider(indent: 18, endIndent: 18, height: 24),
                _drawerTile(
                  icon: Icons.settings,
                  iconBg: Colors.grey.shade200,
                  text: ' الإعدادات',
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
                const SizedBox(height: 10),
                // زر تسجيل الخروج
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
            final totalItems = (showNewHeader ? 1 : 0) +
                newDocs.length +
                (showFinishedHeader ? 1 : 0) +
                finishedDocs.length;

            return ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: totalItems + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildDashboardStatsCard(
                    totalCount: docs.length,
                    newCount: newDocs.length,
                    finishedCount: finishedDocs.length,
                  );
                }

                final effectiveIndex = index - 1;
                var cursor = 0;
                if (showNewHeader) {
                  if (effectiveIndex == cursor) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: const [
                          Icon(Icons.fiber_new, color: primaryColor),
                          SizedBox(width: 8),
                          Text(
                            'الطلبات الجديدة',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  cursor += 1;
                }

                if (effectiveIndex < cursor + newDocs.length) {
                  final doc = newDocs[effectiveIndex - cursor];
                  final data = doc.data() as Map<String, dynamic>;
                  final docId = doc.id;
                  final status = _getOrderStatus(data);
                  final unifiedOrderCode = formatUnifiedOrderCode(
                    orderNumber: data['orderNumber'],
                    orderId: data['orderId'],
                    docId: docId,
                  );

                  Widget orderDetails = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text('👤 العميل: ${data['clientName'] ?? 'غير متوفر'}',
                          style: const TextStyle(fontFamily: 'Tajawal')),
                      Text('💰 الإجمالي: ${data['total'] ?? 0} ج.س',
                          style: const TextStyle(fontFamily: 'Tajawal')),
                      if (data['items'] != null && data['items'] is List)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('تفاصيل الطلب:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Tajawal')),
                              ...List.generate((data['items'] as List).length,
                                  (i) {
                                final item = (data['items'] as List)[i];
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    children: [
                                      if (item['imageUrl'] != null &&
                                          item['imageUrl']
                                              .toString()
                                              .isNotEmpty)
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          child: Image.network(
                                            item['imageUrl'],
                                            width: 32,
                                            height: 32,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${item['name']} × ${item['quantity']}',
                                          style: const TextStyle(
                                              fontFamily: 'Tajawal'),
                                        ),
                                      ),
                                      Text('${item['price']} ج.س',
                                          style: const TextStyle(
                                              fontFamily: 'Tajawal',
                                              color: Colors.grey)),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                    ],
                  );

                  if (status == 'store_pending' || status == 'قيد المراجعة') {
                    return Card(
                      elevation: 1.5,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: primaryColor.withOpacity(0.16)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const SizedBox(width: 8),
                                Text(
                                  '📦 رقم الطلب: $unifiedOrderCode',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Tajawal',
                                      fontSize: 16),
                                ),
                                const SizedBox(width: 10),
                                const Text('🆕 جديد',
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Tajawal')),
                              ],
                            ),
                            orderDetails,
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      await _setOrderStatus(
                                          docId, 'courier_searching',
                                          extra: {
                                            'assignedDriverId': null,
                                            'candidateDrivers': [],
                                            'driverResponded': false,
                                            'driverResponseTime': null
                                          });
                                    },
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green),
                                    child: const Text('قبول الطلب',
                                        style: TextStyle(color: Colors.white)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      await _setOrderStatus(
                                          docId, 'store_rejected');
                                    },
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red),
                                    child: const Text('رفض الطلب',
                                        style: TextStyle(color: Colors.white)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: Colors.grey.withOpacity(0.18)),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.white,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(18)),
                            ),
                            builder: (_) => Padding(
                              padding: const EdgeInsets.all(18),
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (data['items'] != null &&
                                        data['items'] is List)
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text('تفاصيل الطلب:',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'Tajawal',
                                                  fontSize: 16)),
                                          const SizedBox(height: 8),
                                          ...List.generate(
                                              (data['items'] as List).length,
                                              (i) {
                                            final item =
                                                (data['items'] as List)[i];
                                            return Card(
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 4),
                                              elevation: 0,
                                              color: backgroundColor,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 8,
                                                        horizontal: 6),
                                                child: Row(
                                                  children: [
                                                    if (item['imageUrl'] !=
                                                            null &&
                                                        item['imageUrl']
                                                            .toString()
                                                            .isNotEmpty)
                                                      ClipRRect(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                        child: Image.network(
                                                          item['imageUrl'],
                                                          width: 38,
                                                          height: 38,
                                                          fit: BoxFit.cover,
                                                        ),
                                                      ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        '${item['name']} × ${item['quantity']}',
                                                        style: const TextStyle(
                                                            fontFamily:
                                                                'Tajawal',
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color:
                                                                primaryColor),
                                                      ),
                                                    ),
                                                    Text('${item['price']} ج.س',
                                                        style: const TextStyle(
                                                            fontFamily:
                                                                'Tajawal',
                                                            color:
                                                                primaryColor)),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                                    const Divider(height: 24),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('رقم الطلب:',
                                            style: TextStyle(
                                                fontFamily: 'Tajawal',
                                                color: Colors.grey.shade700)),
                                        Text(unifiedOrderCode,
                                            style: TextStyle(
                                                fontFamily: 'Tajawal',
                                                fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('الحالة:',
                                            style: TextStyle(
                                                fontFamily: 'Tajawal',
                                                color: Colors.grey.shade700)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color:
                                                _orderStatusBackground(status),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            _displayOrderStatus(status),
                                            style: TextStyle(
                                              color: _orderStatusColor(status),
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Tajawal',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('الإجمالي:',
                                            style: TextStyle(
                                                fontFamily: 'Tajawal',
                                                color: Colors.grey.shade700)),
                                        Text('${data['total'] ?? 0} ج.س',
                                            style: TextStyle(
                                                fontFamily: 'Tajawal',
                                                fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const Divider(height: 24),
                                    if (status == 'courier_searching' ||
                                        status == 'courier_offer_pending' ||
                                        status == 'courier_assigned' ||
                                        status == 'قيد التجهيز')
                                      _actionButton(' جاهز', () async {
                                        final hasAssignedDriver =
                                            ((data['assignedDriverId'] ?? '')
                                                .toString()
                                                .trim()
                                                .isNotEmpty);
                                        await _setOrderStatus(
                                          docId,
                                          hasAssignedDriver
                                              ? 'pickup_ready'
                                              : 'courier_searching',
                                          extra: {
                                            'readyByRestaurant': true,
                                          },
                                        );
                                        setState(() {});
                                        _showErrorMessage(hasAssignedDriver
                                            ? 'تم تحديث حالة الطلب إلى جاهز للاستلام'
                                            : 'تم تجهيز الطلب وسيتم البحث عن مندوب تلقائيًا');
                                      }),
                                    if (status == 'pickup_ready' ||
                                        status == 'قيد التوصيل')
                                      Padding(
                                        padding: EdgeInsets.only(top: 10),
                                        child: Text('📦 بانتظار استلام المندوب',
                                            style: TextStyle(
                                                color: _orderStatusColor(
                                                    'pickup_ready'),
                                                fontFamily: 'Tajawal',
                                                fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                status == 'courier_searching' ||
                                        status == 'courier_offer_pending' ||
                                        status == 'courier_assigned'
                                    ? Icons.kitchen
                                    : Icons.delivery_dining,
                                color: _orderStatusColor(status),
                                size: 26,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '📦 رقم الطلب: $unifiedOrderCode',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Tajawal',
                                      fontSize: 16),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _displayOrderStatus(status),
                                style: TextStyle(
                                  color: _orderStatusColor(status),
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Tajawal',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                }

                cursor += newDocs.length;
                if (showFinishedHeader) {
                  if (effectiveIndex == cursor) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 10),
                      child: Row(
                        children: const [
                          Icon(Icons.check_circle_outline, color: primaryColor),
                          SizedBox(width: 8),
                          Text(
                            'الطلبات المنتهية من منظور المتجر',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  cursor += 1;
                }

                final doc = finishedDocs[effectiveIndex - cursor];
                final data = doc.data() as Map<String, dynamic>;
                final docId = doc.id;
                final status = _getOrderStatus(data);
                final unifiedOrderCode = formatUnifiedOrderCode(
                  orderNumber: data['orderNumber'],
                  orderId: data['orderId'],
                  docId: docId,
                );

                Widget orderDetails = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text('👤 العميل: ${data['clientName'] ?? 'غير متوفر'}',
                        style: const TextStyle(fontFamily: 'Tajawal')),
                    Text('💰 الإجمالي: ${data['total'] ?? 0} ج.س',
                        style: const TextStyle(fontFamily: 'Tajawal')),
                    if (data['items'] != null && data['items'] is List)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('تفاصيل الطلب:',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Tajawal')),
                            ...List.generate((data['items'] as List).length,
                                (i) {
                              final item = (data['items'] as List)[i];
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    if (item['imageUrl'] != null &&
                                        item['imageUrl'].toString().isNotEmpty)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.network(
                                          item['imageUrl'],
                                          width: 32,
                                          height: 32,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${item['name']} × ${item['quantity']}',
                                        style: const TextStyle(
                                            fontFamily: 'Tajawal'),
                                      ),
                                    ),
                                    Text('${item['price']} ج.س',
                                        style: const TextStyle(
                                            fontFamily: 'Tajawal',
                                            color: Colors.grey)),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                  ],
                );

                if (status == 'store_pending' || status == 'قيد المراجعة') {
                  // الطلب الجديد: التفاصيل تظهر مباشرة
                  return Card(
                    elevation: 1.5,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: primaryColor.withOpacity(0.16)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const SizedBox(width: 8),
                              Text(
                                '📦 رقم الطلب: $unifiedOrderCode',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Tajawal',
                                    fontSize: 16),
                              ),
                              const SizedBox(width: 10),
                              const Text('🆕 جديد',
                                  style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Tajawal')),
                            ],
                          ),
                          orderDetails,
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    await _setOrderStatus(
                                        docId, 'courier_searching',
                                        extra: {
                                          'assignedDriverId': null,
                                          'candidateDrivers': [],
                                          'driverResponded': false,
                                          'driverResponseTime': null
                                        });
                                  },
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green),
                                  child: const Text('قبول الطلب',
                                      style: TextStyle(color: Colors.white)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    await _setOrderStatus(
                                        docId, 'store_rejected');
                                  },
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red),
                                  child: const Text('رفض الطلب',
                                      style: TextStyle(color: Colors.white)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  // الطلبات الأخرى: التفاصيل تظهر عند الضغط
                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.grey.withOpacity(0.18)),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(18)),
                          ),
                          builder: (_) => Padding(
                            padding: const EdgeInsets.all(18),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (data['items'] != null &&
                                      data['items'] is List)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('تفاصيل الطلب:',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'Tajawal',
                                                fontSize: 16)),
                                        const SizedBox(height: 8),
                                        ...List.generate(
                                            (data['items'] as List).length,
                                            (i) {
                                          final item =
                                              (data['items'] as List)[i];
                                          return Card(
                                            margin: const EdgeInsets.symmetric(
                                                vertical: 4),
                                            elevation: 0,
                                            color: backgroundColor,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8,
                                                      horizontal: 6),
                                              child: Row(
                                                children: [
                                                  if (item['imageUrl'] !=
                                                          null &&
                                                      item['imageUrl']
                                                          .toString()
                                                          .isNotEmpty)
                                                    ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                      child: Image.network(
                                                        item['imageUrl'],
                                                        width: 38,
                                                        height: 38,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      '${item['name']} × ${item['quantity']}',
                                                      style: const TextStyle(
                                                          fontFamily: 'Tajawal',
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: primaryColor),
                                                    ),
                                                  ),
                                                  Text('${item['price']} ج.س',
                                                      style: const TextStyle(
                                                          fontFamily: 'Tajawal',
                                                          color: primaryColor)),
                                                ],
                                              ),
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  const Divider(height: 24),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('رقم الطلب:',
                                          style: TextStyle(
                                              fontFamily: 'Tajawal',
                                              color: Colors.grey.shade700)),
                                      Text(unifiedOrderCode,
                                          style: TextStyle(
                                              fontFamily: 'Tajawal',
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('الحالة:',
                                          style: TextStyle(
                                              fontFamily: 'Tajawal',
                                              color: Colors.grey.shade700)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _orderStatusBackground(status),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _displayOrderStatus(status),
                                          style: TextStyle(
                                            color: _orderStatusColor(status),
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Tajawal',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('الإجمالي:',
                                          style: TextStyle(
                                              fontFamily: 'Tajawal',
                                              color: Colors.grey.shade700)),
                                      Text('${data['total'] ?? 0} ج.س',
                                          style: TextStyle(
                                              fontFamily: 'Tajawal',
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                  if (status == 'courier_searching' ||
                                      status == 'courier_offer_pending' ||
                                      status == 'courier_assigned' ||
                                      status == 'قيد التجهيز')
                                    _actionButton(' جاهز', () async {
                                      final hasAssignedDriver =
                                          ((data['assignedDriverId'] ?? '')
                                              .toString()
                                              .trim()
                                              .isNotEmpty);
                                      await _setOrderStatus(
                                        docId,
                                        hasAssignedDriver
                                            ? 'pickup_ready'
                                            : 'courier_searching',
                                        extra: {
                                          'readyByRestaurant': true,
                                        },
                                      );
                                      setState(() {});
                                      _showErrorMessage(hasAssignedDriver
                                          ? 'تم تحديث حالة الطلب إلى جاهز للاستلام'
                                          : 'تم تجهيز الطلب وسيتم البحث عن مندوب تلقائيًا');
                                    }),
                                  if (status == 'pickup_ready' ||
                                      status == 'قيد التوصيل')
                                    Padding(
                                      padding: EdgeInsets.only(top: 10),
                                      child: Text('📦 بانتظار استلام المندوب',
                                          style: TextStyle(
                                              color: _orderStatusColor(
                                                  'pickup_ready'),
                                              fontFamily: 'Tajawal',
                                              fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              status == 'courier_searching' ||
                                      status == 'courier_offer_pending' ||
                                      status == 'courier_assigned'
                                  ? Icons.kitchen
                                  : Icons.delivery_dining,
                              color: _orderStatusColor(status),
                              size: 26,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '📦 رقم الطلب: $unifiedOrderCode',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Tajawal',
                                    fontSize: 16),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _displayOrderStatus(status),
                              style: TextStyle(
                                color: _orderStatusColor(status),
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Tajawal',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
              },
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: AppThemeArabic.clientSurface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          splashColor: primaryColor.withOpacity(0.10),
          highlightColor: primaryColor.withOpacity(0.06),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.14)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: iconBg ?? primaryColor.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(7),
                  child: Icon(icon, color: iconColor ?? primaryColor, size: 24),
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
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton(String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            minimumSize: const Size.fromHeight(48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(label,
              style:
                  const TextStyle(color: Colors.white, fontFamily: 'Tajawal')),
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
}
