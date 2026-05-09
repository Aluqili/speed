import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get_storage/get_storage.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:speedstar_core/src/config/ops_runtime_config.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'package:speedstar_core/src/auth/login_screen_ar.dart';

import 'courier_order_history_screen.dart';
import 'courier_account_tab.dart';
import 'courier_earnings_screen.dart';
import 'courier_order_details_screen.dart';
import 'courier_order_process_screen.dart';
import 'courier_wallet_screen.dart';
import 'chat_screen.dart';
import 'courier_notifications_screen.dart';

const Color primaryColor = AppThemeArabic.courierPrimary;
const Color backgroundColor = AppThemeArabic.courierBackground;

class CourierDashboardScreen extends StatefulWidget {
  final String driverId;
  const CourierDashboardScreen({super.key, required this.driverId});

  @override
  State<CourierDashboardScreen> createState() => _CourierDashboardScreenState();
}

class _CourierDashboardScreenState extends State<CourierDashboardScreen> {
  static const Set<String> _activeOrderStatuses = {
    'courier_assigned',
    'pickup_ready',
    'picked_up',
    'arrived_to_client',
    'جاهز للتوصيل',
    'قيد التوصيل',
    'وصل إلى العميل',
  };

  GoogleMapController? _mapController;
  LatLng _currentLocation = const LatLng(15.5007, 32.5599);
  bool _mapCreated = false;
  bool isAvailable = false;
  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription<QuerySnapshot>? _ordersListener;
  String? _lastOfferOrderId;
  bool _ringtoneEnabled = true;
  double _ringtoneVolume = 1.0;
  Timer? _offerRingtoneTimer;
  bool _hasPendingOffer = false;
  final Set<String> _notifiedOfferOrderIds = <String>{};
  final AudioPlayer _ringtonePlayer = AudioPlayer();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  DateTime? _lastBackPressed;
  Set<Circle> _restaurantCircles = {};

  String _todayAvailabilityKey([DateTime? value]) {
    final now = value ?? DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  int _timestampMillis(dynamic value) {
    if (value is Timestamp) return value.toDate().millisecondsSinceEpoch;
    if (value is DateTime) return value.millisecondsSinceEpoch;
    if (value is int) return value;
    return 0;
  }

  Map<String, dynamic> _buildAvailabilityPatch(Map<String, dynamic> data, bool nextAvailable) {
    final now = DateTime.now();
    final todayKey = _todayAvailabilityKey(now);
    final todayStartMs = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final currentDayKey = (data['availabilityDayKey'] ?? '').toString();
    final currentStartedMs = _timestampMillis(data['availabilityCurrentStartedAt']);
    var totalTodayMs = currentDayKey == todayKey
        ? ((data['availabilityTodayMs'] as num?)?.round() ?? 0)
        : 0;

    if (!nextAvailable && currentStartedMs > 0) {
      final effectiveStartMs = math.max(currentStartedMs, todayStartMs);
      totalTodayMs += now.millisecondsSinceEpoch - effectiveStartMs;
    }

    return {
      'available': nextAvailable,
      'availabilityDayKey': todayKey,
      'availabilityTodayMs': totalTodayMs < 0 ? 0 : totalTodayMs,
      'availabilityCurrentStartedAt': nextAvailable ? Timestamp.now() : null,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<void> _ensureAvailabilityTrackingSeed(Map<String, dynamic> data) async {
    if (data['available'] == true && data['availabilityCurrentStartedAt'] == null) {
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(widget.driverId)
          .update(_buildAvailabilityPatch(data, true));
    }
  }

  @override
  void initState() {
    super.initState();
    _initLocation();
    _loadAvailability();
    _saveFcmToken();
    _loadOpsRuntimeConfig();
    _listenForOrders();
    _checkCurrentOrder();
    _loadAllLocations();
  }

  Future<void> _loadOpsRuntimeConfig() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.fetchAndActivate();
      final ops = OpsRuntimeConfig.fromRemoteConfig(rc, appKey: 'courier');
      if (!mounted) return;
      setState(() {
        _ringtoneEnabled = ops.ringtoneEnabled;
        _ringtoneVolume = ops.ringtoneVolume;
      });
      if (!_ringtoneEnabled) {
        _stopOfferRingtoneLoop();
      }
    } catch (_) {
      // Keep defaults
    }
  }

  Future<void> _playIncomingOfferTone() async {
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

  void _startOfferRingtoneLoop() {
    if (!_ringtoneEnabled) return;
    _offerRingtoneTimer ??= Timer.periodic(const Duration(seconds: 6), (_) {
      if (!_hasPendingOffer || !_ringtoneEnabled) return;
      _playIncomingOfferTone();
    });
  }

  void _stopOfferRingtoneLoop() {
    _offerRingtoneTimer?.cancel();
    _offerRingtoneTimer = null;
    _ringtonePlayer.stop();
  }

  void _updateOfferRingtoneLoop(bool hasPendingOffer) {
    _hasPendingOffer = hasPendingOffer;
    if (_hasPendingOffer) {
      _startOfferRingtoneLoop();
    } else {
      _stopOfferRingtoneLoop();
    }
  }

  Future<void> _checkCurrentOrder() async {
    final box = GetStorage();
    final currentAssignedOrder = await _findCurrentAssignedOrder();
    if (currentAssignedOrder != null && mounted) {
      final orderId = currentAssignedOrder['orderId']!;
      final status = currentAssignedOrder['status'] ?? '';
      final stage = _stageFromStatus(status);
      box.write('current_order', {
        'orderId': orderId,
        'stage': stage,
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CourierOrderProcessScreen(
              orderId: orderId,
              stage: stage,
            ),
          ),
        );
      });
      return;
    }

    final currentOrder = box.read('current_order');
    if (currentOrder != null && mounted && currentOrder['orderId'] != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CourierOrderProcessScreen(
              orderId: currentOrder['orderId'],
              stage: currentOrder['stage'] ?? 'going_to_restaurant',
            ),
          ),
        );
      });
    }
  }

  bool _isActiveOrderStatus(Map<String, dynamic> data) {
    final status = (data['orderStatus'] ?? data['status'] ?? '').toString();
    return _activeOrderStatuses.contains(status);
  }

  String _stageFromStatus(String status) {
    switch (status) {
      case 'courier_assigned':
      case 'pickup_ready':
      case 'جاهز للتوصيل':
        return 'going_to_restaurant';
      case 'picked_up':
      case 'قيد التوصيل':
        return 'going_to_client';
      case 'arrived_to_client':
      case 'وصل إلى العميل':
        return 'arrived_to_client';
      default:
        return 'going_to_restaurant';
    }
  }

  Future<Map<String, String>?> _findCurrentAssignedOrder() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('assignedDriverId', isEqualTo: widget.driverId)
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (_isActiveOrderStatus(data)) {
        final status = (data['orderStatus'] ?? data['status'] ?? '').toString();
        return {
          'orderId': doc.id,
          'status': status,
        };
      }
    }
    return null;
  }

  void _listenForOrders() {
    _ordersListener?.cancel();
    _ordersListener = FirebaseFirestore.instance
        .collection('orders')
        .where('orderStatus', isEqualTo: 'courier_offer_pending')
        .where('offeredDriverId', isEqualTo: widget.driverId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty) {
        _lastOfferOrderId = null;
        _updateOfferRingtoneLoop(false);
        return;
      }

      _updateOfferRingtoneLoop(true);
      for (final doc in snapshot.docs) {
        if (_notifiedOfferOrderIds.contains(doc.id)) continue;
        _notifiedOfferOrderIds.add(doc.id);
        _playIncomingOfferTone();
      }

      final doc = snapshot.docs.first;
      final orderId = doc.id;
      if (_lastOfferOrderId == orderId) return;
      _lastOfferOrderId = orderId;

      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CourierOrderDetailsScreen(
              orderId: orderId,
              driverId: widget.driverId,
            ),
          ),
        );
      });
    });
  }

  Future<void> _saveFcmToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(widget.driverId)
          .set({
        'fcmToken': token,
        'messagingToken': token,
        'fcmTokens': FieldValue.arrayUnion([token]),
        'deviceTokens': FieldValue.arrayUnion([token]),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _initLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await _showLocationDialog();
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        (permission != LocationPermission.always &&
            permission != LocationPermission.whileInUse)) {
      await _showLocationDialog();
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _handleGpsLocation(pos);
    } catch (_) {}
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    ).listen(_handleGpsLocation);
  }

  void _handleGpsLocation(Position position) async {
    setState(
        () => _currentLocation = LatLng(position.latitude, position.longitude));
    if (_mapCreated) {
      _mapController?.animateCamera(CameraUpdate.newLatLng(_currentLocation));
    }
    FirebaseFirestore.instance
        .collection('drivers')
        .doc(widget.driverId)
        .update({
      'location': GeoPoint(position.latitude, position.longitude),
      'lastLocationUpdate': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _showLocationDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('تشغيل الموقع مطلوب'),
        content:
            const Text('يرجى تفعيل خدمة الموقع GPS لاستخدام التطبيق كمندوب.'),
        actions: [
          TextButton(
            onPressed: () async {
              await Geolocator.openLocationSettings();
              Navigator.pop(context);
            },
            child: const Text('فتح الإعدادات'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadAvailability() async {
    final doc = await FirebaseFirestore.instance
        .collection('drivers')
        .doc(widget.driverId)
        .get();
    if (doc.exists) {
      final data = doc.data() ?? <String, dynamic>{};
      _ensureAvailabilityTrackingSeed(data);
      setState(
          () => isAvailable = (data['available'] as bool?) ?? false);
    }
  }

  Future<void> _toggleAvailability(bool v) async {
    setState(() => isAvailable = v);
    final driverRef = FirebaseFirestore.instance.collection('drivers').doc(widget.driverId);
    final snapshot = await driverRef.get();
    final data = snapshot.data() ?? <String, dynamic>{};
    final patch = _buildAvailabilityPatch(data, v);
    if (!v) {
      patch['currentOrderId'] = null;
    }
    await driverRef.update(patch);
  }

  Future<void> _confirmAndLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد تسجيل الخروج'),
        content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _logout();
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final driverRef = FirebaseFirestore.instance.collection('drivers').doc(widget.driverId);
      final snapshot = await driverRef.get();
      final data = snapshot.data() ?? <String, dynamic>{};
      final patch = _buildAvailabilityPatch(data, false);
      patch['currentOrderId'] = null;
      await driverRef.update(patch);
    } catch (e) {
      // إذا لم يوجد المستند، أنشئه مع available=false
      if (e.toString().contains('not-found')) {
        await FirebaseFirestore.instance
            .collection('drivers')
            .doc(widget.driverId)
            .set({
          'available': false,
          'availabilityDayKey': _todayAvailabilityKey(),
          'availabilityTodayMs': 0,
          'availabilityCurrentStartedAt': null,
        }, SetOptions(merge: true));
      } else {
        debugPrint('Firestore logout update error: $e');
      }
    }
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
      (_) => false,
    );
  }

  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('اضغط مرة أخرى للخروج'),
          behavior: SnackBarBehavior.floating));
      return false;
    }
    return true;
  }

  LatLng? _extractMapLocation(Map<String, dynamic> data) {
    final rawLocation = data['location'];
    if (rawLocation is GeoPoint) {
      return LatLng(rawLocation.latitude, rawLocation.longitude);
    }
    if (rawLocation is Map<String, dynamic>) {
      final lat = (rawLocation['lat'] as num?)?.toDouble() ??
          (rawLocation['latitude'] as num?)?.toDouble();
      final lng = (rawLocation['lng'] as num?)?.toDouble() ??
          (rawLocation['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) return LatLng(lat, lng);
    }

    final lat = (data['lat'] as num?)?.toDouble() ??
        (data['latitude'] as num?)?.toDouble() ??
        (data['restaurantLat'] as num?)?.toDouble();
    final lng = (data['lng'] as num?)?.toDouble() ??
        (data['longitude'] as num?)?.toDouble() ??
        (data['restaurantLng'] as num?)?.toDouble();

    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  bool _isRestaurantOpen(Map<String, dynamic> data) {
    final temporarilyClosed = data['temporarilyClosed'] == true;
    final approvalStatus = (data['approvalStatus'] ?? '').toString().trim();
    final isActive = data['active'] != false;
    return !temporarilyClosed &&
        isActive &&
        (approvalStatus.isEmpty || approvalStatus == 'approved');
  }

  Future<Map<String, int>> _loadRestaurantDemandMap() async {
    QuerySnapshot<Map<String, dynamic>> ordersSnapshot;
    try {
      ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .limit(250)
          .get();
    } catch (_) {
      ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .limit(250)
          .get();
    }

    final counts = <String, int>{};
    for (final doc in ordersSnapshot.docs) {
      final data = doc.data();
      final restaurantId = (data['restaurantId'] ?? '').toString().trim();
      final status = (data['orderStatus'] ?? data['status'] ?? '').toString();
      if (restaurantId.isEmpty || status == 'cancelled' || status == 'ملغي') {
        continue;
      }
      counts.update(restaurantId, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  Future<void> _loadAllLocations() async {
    try {
      final restaurantsSnapshot =
          await FirebaseFirestore.instance.collection('restaurants').get();
      final demandMap = await _loadRestaurantDemandMap();

      final circles = <Circle>{};

      final maxDemand =
          demandMap.values.isEmpty ? 0 : demandMap.values.reduce(math.max);
      final popularThreshold =
          maxDemand <= 0 ? 999999 : math.max(3, (maxDemand * 0.5).ceil());

      for (final doc in restaurantsSnapshot.docs) {
        final data = doc.data();
        if (!_isRestaurantOpen(data)) continue;

        final position = _extractMapLocation(data);
        if (position == null) continue;

        final restaurantId = doc.id;
        final demandCount = demandMap[restaurantId] ?? 0;
        final isPopular = demandCount >= popularThreshold;

        circles.add(
          Circle(
            circleId: CircleId('restaurant_open_$restaurantId'),
            center: position,
            radius: isPopular ? 240 : 180,
            fillColor: (isPopular
                    ? AppThemeArabic.courierPrimary
                    : AppThemeArabic.courierAccent)
                .withValues(alpha: isPopular ? 0.28 : 0.14),
            strokeColor: (isPopular
                    ? AppThemeArabic.courierPrimary
                    : AppThemeArabic.courierAccent)
                .withValues(alpha: isPopular ? 0.7 : 0.38),
            strokeWidth: isPopular ? 2 : 1,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _restaurantCircles = circles;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _restaurantCircles = {};
      });
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _locationSubscription?.cancel();
    _ordersListener?.cancel();
    _stopOfferRingtoneLoop();
    _ringtonePlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // في build:
    return Directionality(
      textDirection: TextDirection.rtl,
      child: WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: backgroundColor,
          drawer: Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const DrawerHeader(
                  decoration: BoxDecoration(color: primaryColor),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.delivery_dining,
                          color: Colors.white, size: 48),
                      SizedBox(height: 8),
                      Text('قائمة المندوب',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Tajawal')),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const Icon(Icons.history,
                        color: AppThemeArabic.courierPrimary),
                    title: const Text('سجل الطلبات',
                        style: TextStyle(fontFamily: 'Tajawal')),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => CourierOrderHistoryScreen(
                                driverId: widget.driverId))),
                  ),
                ),
                Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const Icon(Icons.person,
                        color: AppThemeArabic.courierTextPrimary),
                    title:
                        const Text('الحساب', style: TextStyle(fontFamily: 'Tajawal')),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                CourierAccountTab(driverId: widget.driverId))),
                  ),
                ),
                Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const Icon(Icons.monetization_on,
                        color: AppThemeArabic.courierAccent),
                    title:
                        const Text('أرباحي', style: TextStyle(fontFamily: 'Tajawal')),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => CourierEarningsScreen(
                                driverId: widget.driverId))),
                  ),
                ),
                Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const Icon(Icons.assignment_turned_in,
                        color: AppThemeArabic.courierPrimary),
                    title: const Text('عرض الطلب الحالي',
                        style: TextStyle(fontFamily: 'Tajawal')),
                    onTap: () async {
                      final box = GetStorage();
                      final currentOrder = box.read('current_order');

                      final currentAssignedOrder =
                          await _findCurrentAssignedOrder();

                      String? orderId;
                      String stage = 'going_to_restaurant';
                      if (currentAssignedOrder != null) {
                        orderId = currentAssignedOrder['orderId'];
                        final status = currentAssignedOrder['status'] ?? '';
                        stage = _stageFromStatus(status);
                        box.write('current_order', {
                          'orderId': orderId,
                          'stage': stage,
                        });
                      } else if (currentOrder != null &&
                          currentOrder['orderId'] != null) {
                        orderId = currentOrder['orderId'].toString();
                        stage = (currentOrder['stage'] ?? 'going_to_restaurant')
                            .toString();
                      }

                      if (!mounted) return;
                      if (orderId != null && orderId.isNotEmpty) {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CourierOrderProcessScreen(
                              orderId: orderId!,
                              stage: stage,
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'لا يوجد طلب حالي - لم يتم تعيين أي طلب بعد'),
                          ),
                        );
                      }
                    },
                  ),
                ),
                Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const Icon(Icons.account_balance_wallet,
                        color: AppThemeArabic.courierAccent),
                    title:
                        const Text('محفظتي', style: TextStyle(fontFamily: 'Tajawal')),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => CourierWalletScreen(
                                driverId: widget.driverId))),
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Chip(
                        label: Text(isAvailable ? 'متاح للطلبات' : 'غير متاح',
                            style: const TextStyle(
                                color: Colors.white, fontFamily: 'Tajawal')),
                        backgroundColor: isAvailable
                            ? AppThemeArabic.courierAccent
                            : AppThemeArabic.clientError,
                        avatar: Icon(
                            isAvailable ? Icons.check_circle : Icons.cancel,
                            color: Colors.white),
                      ),
                      const Spacer(),
                      Switch(
                        value: isAvailable,
                        onChanged: _toggleAvailability,
                        activeColor: AppThemeArabic.courierAccent,
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const Icon(Icons.logout,
                        color: AppThemeArabic.clientError),
                    title: const Text('تسجيل الخروج',
                        style: TextStyle(fontFamily: 'Tajawal')),
                    onTap: _confirmAndLogout,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 1,
            centerTitle: true,
            iconTheme:
                const IconThemeData(color: AppThemeArabic.courierPrimary),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
            leading: IconButton(
                icon: const Icon(Icons.menu,
                    color: AppThemeArabic.courierPrimary),
                onPressed: () => _scaffoldKey.currentState!.openDrawer()),
            title: Row(children: [
              const Icon(Icons.delivery_dining,
                  color: AppThemeArabic.courierPrimary),
              const SizedBox(width: 8),
              Text(isAvailable ? 'أنت متاح ✅' : 'غير متاح ',
                  style: const TextStyle(
                      color: AppThemeArabic.courierTextPrimary,
                      fontWeight: FontWeight.bold)),
            ]),
            actions: [
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('notifications')
                    .where('driverId', isEqualTo: widget.driverId)
                    .snapshots(),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? const [];
                  final unreadCount = docs.where((doc) {
                    final data = doc.data();
                    final isRead =
                        data['read'] == true || data['isRead'] == true;
                    return !isRead;
                  }).length;

                  return IconButton(
                    tooltip: 'الإشعارات',
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.notifications_none,
                            color: AppThemeArabic.courierPrimary),
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
                                unreadCount > 99
                                    ? '99+'
                                    : unreadCount.toString(),
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
                          builder: (_) => CourierNotificationsScreen(
                              driverId: widget.driverId),
                        ),
                      );
                    },
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.support_agent,
                    color: AppThemeArabic.courierPrimary),
                tooltip: 'الدعم',
                onPressed: () async {
                  final doc = await FirebaseFirestore.instance
                      .collection('drivers')
                      .doc(widget.driverId)
                      .get();
                  final driverName = doc.data()?['name'] ?? 'مندوب';
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        currentUserId: widget.driverId,
                        otherUserId: 'support',
                        currentUserRole: 'driver',
                        chatId: '${widget.driverId}-support',
                        currentUserName: driverName,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Stack(
            children: [
              // خلفية خريطة مع ظل خفيف
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 12,
                        offset: Offset(0, 4)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: GoogleMap(
                    initialCameraPosition:
                        CameraPosition(target: _currentLocation, zoom: 15),
                    onMapCreated: (c) => setState(() {
                      _mapController = c;
                      _mapCreated = true;
                    }),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: true,
                    compassEnabled: true,
                    rotateGesturesEnabled: true,
                    tiltGesturesEnabled: true,
                    circles: _restaurantCircles,
                    markers: const <Marker>{},
                  ),
                ),
              ),
              Positioned(
                top: 18,
                left: 18,
                right: 18,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppThemeArabic.courierPrimary
                                .withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.near_me_rounded,
                            color: AppThemeArabic.courierPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'لوحة المندوب',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Tajawal',
                                  color: AppThemeArabic.courierTextPrimary,
                                ),
                              ),
                              Text(
                                'الخريطة تعرض موقعك الحالي وطبقات المطاعم المفتوحة والأكثر نشاطًا.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Tajawal',
                                  color: AppThemeArabic.courierTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
