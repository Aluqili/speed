import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get_storage/get_storage.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:speedstar_core/src/config/ops_runtime_config.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'package:speedstar_core/src/auth/login_screen_ar.dart';

import '../الخدمات/location_service.dart';
import 'courier_order_history_screen.dart';
import 'courier_account_tab.dart';
import 'courier_earnings_screen.dart';
import 'courier_new_orders_screen.dart';
import 'courier_order_process_screen.dart';
import 'courier_wallet_screen.dart';
import 'chat_screen.dart';
import 'courier_notifications_screen.dart';
import 'courier_ui.dart';

const Color primaryColor = AppThemeArabic.courierPrimary;
const Color backgroundColor = AppThemeArabic.courierBackground;

class CourierDashboardScreen extends StatefulWidget {
  final String driverId;
  const CourierDashboardScreen({super.key, required this.driverId});

  @override
  State<CourierDashboardScreen> createState() => _CourierDashboardScreenState();
}

class _CourierDashboardScreenState extends State<CourierDashboardScreen>
    with WidgetsBindingObserver {
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
  int _offerRadiusKm = 5;
  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription<QuerySnapshot>? _ordersListener;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _restaurantHeatOrdersListener;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _openRestaurantsListener;
  Timer? _restaurantHeatRefreshTimer;
  bool _ringtoneEnabled = true;
  double _ringtoneVolume = 1.0;
  bool _isOfferRingtoneLooping = false;
  bool _hasPendingOffer = false;
  int _pendingOfferCount = 0;
  Timer? _emptyOffersGraceTimer;
  Timer? _ringtoneWatchdogTimer;
  final Set<String> _notifiedOfferOrderIds = <String>{};
  final AudioPlayer _ringtonePlayer = AudioPlayer();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  DateTime? _lastBackPressed;
  Set<Circle> _restaurantHeatCircles = const <Circle>{};
  Map<String, LatLng> _openRestaurantLocations = const <String, LatLng>{};
  Map<String, int> _recentRestaurantOrderCounts = const <String, int>{};
  bool _openingOrderProcess = false;
  String? _activeOrderProcessKey;

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

  Map<String, dynamic> _buildAvailabilityPatch(
      Map<String, dynamic> data, bool nextAvailable) {
    final now = DateTime.now();
    final todayKey = _todayAvailabilityKey(now);
    final todayStartMs =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final currentDayKey = (data['availabilityDayKey'] ?? '').toString();
    final currentStartedMs =
        _timestampMillis(data['availabilityCurrentStartedAt']);
    var totalTodayMs = currentDayKey == todayKey
        ? ((data['availabilityTodayMs'] as num?)?.round() ?? 0)
        : 0;

    if (!nextAvailable && currentStartedMs > 0) {
      final effectiveStartMs = math.max(currentStartedMs, todayStartMs);
      totalTodayMs += now.millisecondsSinceEpoch - effectiveStartMs;
    }

    return {
      'available': nextAvailable,
      'offerRadiusKm': _offerRadiusKm,
      'availabilityDayKey': todayKey,
      'availabilityTodayMs': totalTodayMs < 0 ? 0 : totalTodayMs,
      'availabilityCurrentStartedAt': nextAvailable ? Timestamp.now() : null,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<void> _ensureAvailabilityTrackingSeed(
      Map<String, dynamic> data) async {
    if (data['available'] == true &&
        data['availabilityCurrentStartedAt'] == null) {
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(widget.driverId)
          .update(_buildAvailabilityPatch(data, true));
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(LocationService.instance.startLocationUpdates(widget.driverId));
    _initLocation();
    _loadAvailability();
    _saveFcmToken();
    _loadOpsRuntimeConfig();
    _listenForOrders();
    _startRestaurantHeatMap();
    _checkCurrentOrder();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _hasPendingOffer) {
      _isOfferRingtoneLooping = false;
      _startOfferRingtoneLoop();
    }
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
      await _ringtonePlayer.setPlayerMode(PlayerMode.mediaPlayer);
      await _ringtonePlayer.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.notificationRingtone,
            audioFocus: AndroidAudioFocus.gain,
            stayAwake: true,
          ),
        ),
      );
      await _ringtonePlayer.setReleaseMode(ReleaseMode.loop);
      await _ringtonePlayer.play(
        AssetSource('sounds/incoming_order.mp3.mpeg'),
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
    _startRingtoneWatchdog();
    if (!_ringtoneEnabled || _isOfferRingtoneLooping) return;
    _isOfferRingtoneLooping = true;
    _playIncomingOfferTone();
  }

  void _stopOfferRingtoneLoop() {
    _isOfferRingtoneLooping = false;
    _stopRingtoneWatchdog();
    _ringtonePlayer.stop();
  }

  // يعيد تشغيل الصوت تلقائيًا إذا توقف (فقدان تركيز الصوت عند سحب الستارة مثلًا)
  // طالما لا يزال هناك عرض معلّق لم يُقبل أو يُرفض بعد.
  void _startRingtoneWatchdog() {
    _ringtoneWatchdogTimer?.cancel();
    _ringtoneWatchdogTimer =
        Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!_hasPendingOffer || !_ringtoneEnabled) return;
      final state = _ringtonePlayer.state;
      if (state != PlayerState.playing) {
        await _playIncomingOfferTone();
      }
    });
  }

  void _stopRingtoneWatchdog() {
    _ringtoneWatchdogTimer?.cancel();
    _ringtoneWatchdogTimer = null;
  }

  void _updateOfferRingtoneLoop(bool hasPendingOffer) {
    _hasPendingOffer = hasPendingOffer;
    if (_hasPendingOffer) {
      _startOfferRingtoneLoop();
    } else {
      _stopOfferRingtoneLoop();
    }
  }

  LatLng? _restaurantLocationFromProfile(Map<String, dynamic> data) {
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
    final approvalStatus = (data['approvalStatus'] ?? '').toString().trim();
    return data['temporarilyClosed'] != true &&
        data['active'] != false &&
        (approvalStatus.isEmpty || approvalStatus == 'approved');
  }

  void _startRestaurantHeatMap() {
    _restaurantHeatRefreshTimer?.cancel();
    _restaurantHeatRefreshTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => _listenToRecentRestaurantOrders(),
    );
    _listenForOpenRestaurants();
    _listenToRecentRestaurantOrders();
  }

  void _listenForOpenRestaurants() {
    _openRestaurantsListener?.cancel();
    _openRestaurantsListener = FirebaseFirestore.instance
        .collection('restaurants')
        .snapshots()
        .listen((snapshot) {
      final locations = <String, LatLng>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (!_isRestaurantOpen(data)) continue;
        final location = _restaurantLocationFromProfile(data);
        if (location != null) locations[doc.id] = location;
      }
      if (!mounted) return;
      setState(() {
        _openRestaurantLocations = locations;
        _rebuildRestaurantHeatCircles();
      });
    }, onError: (_) {
      if (mounted) setState(() => _openRestaurantLocations = const {});
    });
  }

  void _rebuildRestaurantHeatCircles() {
    _restaurantHeatCircles = _openRestaurantLocations.entries.map((entry) {
      final intensity =
          (_recentRestaurantOrderCounts[entry.key] ?? 0).clamp(0, 6).toDouble();
      return Circle(
        circleId: CircleId('restaurant_heat_${entry.key}'),
        center: entry.value,
        radius: 125 + (intensity * 28),
        fillColor: Colors.red.withValues(
          alpha: intensity == 0 ? 0.055 : 0.10 + (intensity * 0.10),
        ),
        strokeColor: Colors.red.withValues(
          alpha: intensity == 0 ? 0.18 : 0.36 + (intensity * 0.09),
        ),
        strokeWidth: intensity >= 4 ? 3 : 2,
      );
    }).toSet();
  }

  void _listenToRecentRestaurantOrders() {
    _restaurantHeatOrdersListener?.cancel();
    final cutoff = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(minutes: 30)),
    );
    _restaurantHeatOrdersListener = FirebaseFirestore.instance
        .collection('orders')
        .where('createdAt', isGreaterThanOrEqualTo: cutoff)
        .snapshots()
        .listen((snapshot) {
      final demandByRestaurant = <String, int>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (!_isActiveOrderStatus(data)) continue;

        final restaurantId = (data['restaurantId'] ?? '').toString().trim();
        if (restaurantId.isEmpty) continue;
        demandByRestaurant.update(
          restaurantId,
          (currentCount) => currentCount + 1,
          ifAbsent: () => 1,
        );
      }

      if (!mounted) return;
      setState(() {
        _recentRestaurantOrderCounts = demandByRestaurant;
        _rebuildRestaurantHeatCircles();
      });
    }, onError: (_) {
      if (!mounted) return;
      setState(() {
        _recentRestaurantOrderCounts = const {};
        _rebuildRestaurantHeatCircles();
      });
    });
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
        unawaited(
          _openOrderProcess(
            orderId: orderId,
            stage: stage,
          ),
        );
      });
      return;
    }

    final currentOrder = box.read('current_order');
    if (currentOrder != null && mounted && currentOrder['orderId'] != null) {
      final orderId = currentOrder['orderId'].toString();
      final stage = (currentOrder['stage'] ?? 'going_to_restaurant').toString();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          _openOrderProcess(
            orderId: orderId,
            stage: stage,
          ),
        );
      });
    }
  }

  Future<void> _openOrderProcess({
    required String orderId,
    required String stage,
    bool closeDrawer = false,
  }) async {
    if (!mounted || orderId.isEmpty) return;
    final key = '$orderId:$stage';
    if (_openingOrderProcess || _activeOrderProcessKey == key) return;
    _openingOrderProcess = true;
    _activeOrderProcessKey = key;

    try {
      if (closeDrawer && Navigator.of(context).canPop()) {
        Navigator.pop(context);
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CourierOrderProcessScreen(
            orderId: orderId,
            stage: stage,
          ),
        ),
      );
    } finally {
      _openingOrderProcess = false;
      if (_activeOrderProcessKey == key) {
        _activeOrderProcessKey = null;
      }
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
    _restaurantHeatOrdersListener?.cancel();
    _openRestaurantsListener?.cancel();
    _restaurantHeatRefreshTimer?.cancel();
    _restaurantHeatOrdersListener?.cancel();
    _restaurantHeatRefreshTimer?.cancel();
    final courierAuthUid =
        FirebaseAuth.instance.currentUser?.uid ?? widget.driverId;
    _ordersListener = FirebaseFirestore.instance
        .collection('orders')
        .where('offerDriverOwnerUids', arrayContains: courierAuthUid)
        .snapshots()
        .listen((snapshot) {
      final offerDocs = snapshot.docs.where((doc) {
        final data = doc.data();
        final status = (data['orderStatus'] ?? data['status'] ?? '').toString();
        return status == 'courier_offer_pending';
      }).toList();

      if (offerDocs.isEmpty) {
        _emptyOffersGraceTimer?.cancel();
        _emptyOffersGraceTimer = Timer(const Duration(seconds: 3), () {
          if (!mounted || _pendingOfferCount == 0) return;
          setState(() => _pendingOfferCount = 0);
          _updateOfferRingtoneLoop(false);
        });
        return;
      }

      _emptyOffersGraceTimer?.cancel();
      if (mounted) setState(() => _pendingOfferCount = offerDocs.length);
      _updateOfferRingtoneLoop(true);
      for (final doc in offerDocs) {
        if (_notifiedOfferOrderIds.contains(doc.id)) continue;
        _notifiedOfferOrderIds.add(doc.id);
      }
    }, onError: (_, __) {
      _emptyOffersGraceTimer?.cancel();
      if (mounted) {
        setState(() => _pendingOfferCount = 0);
      }
      _updateOfferRingtoneLoop(false);
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
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      ),
    ).listen(_handleGpsLocation);
  }

  void _handleGpsLocation(Position position) async {
    setState(
        () => _currentLocation = LatLng(position.latitude, position.longitude));
    if (_mapCreated) {
      _mapController?.animateCamera(CameraUpdate.newLatLng(_currentLocation));
    }
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
    try {
      await FirebaseFunctions.instanceFor(region: 'me-central1')
          .httpsCallable('reconcileCourierOrderLock')
          .call({'driverId': widget.driverId});
    } catch (_) {}

    final doc = await FirebaseFirestore.instance
        .collection('drivers')
        .doc(widget.driverId)
        .get();
    if (doc.exists) {
      final data = doc.data() ?? <String, dynamic>{};
      _ensureAvailabilityTrackingSeed(data);
      setState(() {
        isAvailable = (data['available'] as bool?) ?? false;
        final savedRadius = (data['offerRadiusKm'] as num?)?.round() ?? 5;
        _offerRadiusKm = [5, 10, 15].contains(savedRadius) ? savedRadius : 5;
      });
    }
  }

  Future<void> _toggleAvailability(bool v) async {
    setState(() {
      isAvailable = v;
    });
    final driverRef =
        FirebaseFirestore.instance.collection('drivers').doc(widget.driverId);
    final snapshot = await driverRef.get();
    final data = snapshot.data() ?? <String, dynamic>{};
    final patch = _buildAvailabilityPatch(data, v);
    if (!v) {
      patch['currentOrderId'] = null;
    }
    await driverRef.set(patch, SetOptions(merge: true));
  }

  Future<void> _setOfferRadius(int radiusKm) async {
    if (!isAvailable) return;
    setState(() => _offerRadiusKm = radiusKm);
    await FirebaseFirestore.instance
        .collection('drivers')
        .doc(widget.driverId)
        .set({
      'offerRadiusKm': radiusKm,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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

  Future<void> _openCurrentOrder() async {
    final box = GetStorage();
    final currentOrder = box.read('current_order');
    final currentAssignedOrder = await _findCurrentAssignedOrder();

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
    } else if (currentOrder != null && currentOrder['orderId'] != null) {
      orderId = currentOrder['orderId'].toString();
      stage = (currentOrder['stage'] ?? 'going_to_restaurant').toString();
    }

    if (!mounted) return;
    if (orderId != null && orderId.isNotEmpty) {
      await _openOrderProcess(
        orderId: orderId,
        stage: stage,
        closeDrawer: true,
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('لا يوجد طلب حالي - لم يتم تعيين أي طلب بعد'),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.transparent,
      child: CourierPageBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              children: [
                CourierHeroCard(
                  title: 'لوحة المندوب',
                  subtitle: isAvailable
                      ? 'أنت الآن ظاهر لاستقبال الطلبات ويمكنك متابعة رحلتك بسرعة.'
                      : 'فعّل التوفر عندما تكون جاهزًا لاستقبال الطلبات الجديدة.',
                  icon: Icons.route_rounded,
                  trailing: Switch(
                    value: isAvailable,
                    onChanged: _toggleAvailability,
                    activeColor: Colors.white,
                    activeTrackColor: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  enabled: isAvailable,
                  leading: const Icon(Icons.radar_rounded),
                  title: const Text('نطاق وصول الطلبات'),
                  subtitle: Text(
                    isAvailable
                        ? 'تصل إليك طلبات يكون موقع استلامها ضمن هذا النطاق.'
                        : 'فعّل التوفر أولًا لاختيار النطاق.',
                  ),
                  trailing: DropdownButton<int>(
                    value: _offerRadiusKm,
                    onChanged: isAvailable
                        ? (value) {
                            if (value != null) _setOfferRadius(value);
                          }
                        : null,
                    items: const [
                      DropdownMenuItem(value: 5, child: Text('5 كم')),
                      DropdownMenuItem(value: 10, child: Text('10 كم')),
                      DropdownMenuItem(value: 15, child: Text('15 كم')),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: [
                      CourierMenuTile(
                        title: 'الطلب الحالي',
                        subtitle: 'العودة سريعًا إلى الرحلة الجارية',
                        icon: Icons.assignment_turned_in_rounded,
                        onTap: _openCurrentOrder,
                      ),
                      const SizedBox(height: 10),
                      CourierMenuTile(
                        title: 'سجل الطلبات',
                        subtitle: 'مراجعة الطلبات المكتملة السابقة',
                        icon: Icons.history_rounded,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CourierOrderHistoryScreen(
                                driverId: widget.driverId),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      CourierMenuTile(
                        title: 'الحساب',
                        subtitle: 'البيانات الشخصية والإعدادات الأساسية',
                        icon: Icons.person_outline_rounded,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CourierAccountTab(driverId: widget.driverId),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      CourierMenuTile(
                        title: 'الأرباح',
                        subtitle: 'ملخص الأداء والدخل المنجز',
                        icon: Icons.bar_chart_rounded,
                        iconColor: AppThemeArabic.courierAccent,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CourierEarningsScreen(
                                driverId: widget.driverId),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      CourierMenuTile(
                        title: 'المحفظة',
                        subtitle: 'بيانات التحويلات والمبالغ المستحقة',
                        icon: Icons.account_balance_wallet_outlined,
                        iconColor: AppThemeArabic.courierAccent,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CourierWalletScreen(driverId: widget.driverId),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                CourierSectionCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: (isAvailable
                                    ? AppThemeArabic.courierAccent
                                    : AppThemeArabic.clientError)
                                .withValues(alpha: 0.14),
                            child: Icon(
                              isAvailable
                                  ? Icons.check_circle
                                  : Icons.pause_circle,
                              color: isAvailable
                                  ? AppThemeArabic.courierAccent
                                  : AppThemeArabic.clientError,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isAvailable
                                  ? 'متاح للطلبات الآن'
                                  : 'غير متاح حاليًا',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppThemeArabic.courierTextPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _confirmAndLogout,
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('تسجيل الخروج'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppThemeArabic.clientError,
                          ),
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
    );
  }

  Widget _buildTopMapCard() {
    return CourierSectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppThemeArabic.courierPrimary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
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
                  'منطقة العمل الحالية',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppThemeArabic.courierTextPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'الخريطة تعرض موقعك والمطاعم المفتوحة والأكثر نشاطًا حولك.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppThemeArabic.courierTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomMapPanel() {
    return CourierSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.icon(
            onPressed: () {
              setState(() => _pendingOfferCount = 0);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CourierNewOrdersScreen(
                    driverId: widget.driverId,
                  ),
                ),
              ).whenComplete(_listenForOrders);
            },
            icon: Icon(
              _hasPendingOffer
                  ? Icons.notifications_active_rounded
                  : Icons.local_shipping_outlined,
            ),
            label: Text(
              _pendingOfferCount == 1
                  ? 'لديك عرض جديد - افتح العرض الآن'
                  : _pendingOfferCount > 1
                      ? 'لديك $_pendingOfferCount عروض جديدة - افتح العروض'
                      : 'العروض المتاحة',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _hasPendingOffer
                  ? AppThemeArabic.courierAccent
                  : AppThemeArabic.courierPrimary,
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openCurrentOrder,
                  icon: const Icon(Icons.route_rounded),
                  label: const Text('الرحلة الحالية'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CourierOrderHistoryScreen(
                            driverId: widget.driverId),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('السجل'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final driverRef =
          FirebaseFirestore.instance.collection('drivers').doc(widget.driverId);
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
          'acceptsLongDistance': false,
          'longDistanceEnabledAt': null,
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

  @override
  void dispose() {
    _stopRingtoneWatchdog();
    WidgetsBinding.instance.removeObserver(this);
    _mapController?.dispose();
    _locationSubscription?.cancel();
    unawaited(
      LocationService.instance.stopLocationUpdates(stopNativeService: false),
    );
    _ordersListener?.cancel();
    _emptyOffersGraceTimer?.cancel();
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
                    title: const Text('الحساب',
                        style: TextStyle(fontFamily: 'Tajawal')),
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
                    title: const Text('أرباحي',
                        style: TextStyle(fontFamily: 'Tajawal')),
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
                        await _openOrderProcess(
                          orderId: orderId,
                          stage: stage,
                          closeDrawer: true,
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
                    title: const Text('محفظتي',
                        style: TextStyle(fontFamily: 'Tajawal')),
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
                ListTile(
                  enabled: isAvailable,
                  leading: const Icon(Icons.radar_rounded),
                  title: const Text('نطاق وصول الطلبات'),
                  subtitle: Text(
                    isAvailable
                        ? 'موقع استلام الطلب ضمن النطاق المحدد.'
                        : 'فعّل التوفر أولًا لاختيار النطاق.',
                  ),
                  trailing: DropdownButton<int>(
                    value: _offerRadiusKm,
                    onChanged: isAvailable
                        ? (value) {
                            if (value != null) _setOfferRadius(value);
                          }
                        : null,
                    items: const [
                      DropdownMenuItem(value: 5, child: Text('5 كم')),
                      DropdownMenuItem(value: 10, child: Text('10 كم')),
                      DropdownMenuItem(value: 15, child: Text('15 كم')),
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
            backgroundColor: const Color(0xFF18352B),
            elevation: 0,
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
            leading: IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => _scaffoldKey.currentState!.openDrawer()),
            title: Container(
              padding: const EdgeInsets.only(right: 10, left: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isAvailable
                        ? Icons.check_circle_rounded
                        : Icons.pause_circle_filled_rounded,
                    color: isAvailable
                        ? const Color(0xFF65D6A8)
                        : const Color(0xFFFF8A80),
                    size: 19,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isAvailable ? 'متاح' : 'غير متاح',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  Switch.adaptive(
                    value: isAvailable,
                    onChanged: _toggleAvailability,
                    activeColor: AppThemeArabic.courierAccent,
                  ),
                ],
              ),
            ),
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
                    if ((data['type'] ?? '').toString().toLowerCase() ==
                        'courier_offer_pending') {
                      return false;
                    }
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
                            color: Colors.white),
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
                        if ((data['type'] ?? '').toString().toLowerCase() ==
                            'courier_offer_pending') {
                          return false;
                        }
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
                icon: const Icon(Icons.support_agent, color: Colors.white),
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
              GoogleMap(
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
                circles: _restaurantHeatCircles,
                markers: const <Marker>{},
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: SafeArea(
                  top: false,
                  child: _buildBottomMapPanel(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
