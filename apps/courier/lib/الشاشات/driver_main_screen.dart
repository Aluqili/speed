import '../helpers/location_utils.dart';
import 'dart:async';
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

import 'courier_order_history_screen.dart';
import 'courier_account_tab.dart';
import 'courier_earnings_screen.dart';
import 'courier_order_details_screen.dart';
import 'courier_order_process_screen.dart';
import 'courier_wallet_screen.dart';
import 'manual_location_picker.dart';
import 'chat_screen.dart';

const Color primaryColor = AppThemeArabic.clientPrimary;
const Color backgroundColor = AppThemeArabic.clientBackground;

class CourierDashboardScreen extends StatefulWidget {
  final String driverId;
  const CourierDashboardScreen({Key? key, required this.driverId})
      : super(key: key);

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
  Set<Marker> _allMarkers = {};
  bool _showManualLocation = false;
  bool _isManualLocation = false;
  int _gpsFailCount = 0;
  static const int _maxGpsTries = 3;

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
          .update({'fcmToken': token});
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
    } catch (e) {
      _gpsFailCount++;
      if (_gpsFailCount >= _maxGpsTries) {
        setState(() => _showManualLocation = true);
      }
    }
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    ).listen(_handleGpsLocation);
  }

  void _handleGpsLocation(Position position) async {
    // تحقق من المناطق غير المأهولة باستخدام geocoding
    final bool uninhabited =
        await isUninhabitedByGeocoding(position.latitude, position.longitude);
    debugPrint(
        'موقع المندوب: lat=${position.latitude}, lng=${position.longitude}, uninhabited=$uninhabited');
    if (uninhabited) {
      setState(() {
        _showManualLocation = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'تم اكتشاف أنك في منطقة غير مأهولة أو غير معروفة، يمكنك تحديد الموقع يدويًا.')),
      );
      return;
    }
    // إذا كان المستخدم في وضع الموقع اليدوي، لا تحدث الموقع إلا إذا عاد الموقع طبيعيًا
    if (_isManualLocation) {
      // إذا تحسن الموقع (دقة أقل من 50 متر مثلاً)، أعد التتبع التلقائي
      if (position.accuracy < 50) {
        setState(() {
          _isManualLocation = false;
          _showManualLocation = false;
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
        if (_mapCreated) {
          _mapController
              ?.animateCamera(CameraUpdate.newLatLng(_currentLocation));
        }
        FirebaseFirestore.instance
            .collection('drivers')
            .doc(widget.driverId)
            .update({
          'location': GeoPoint(position.latitude, position.longitude),
          'lastLocationUpdate': FieldValue.serverTimestamp(),
        });
      }
      return;
    }
    // إذا كان الموقع غير دقيق أو فيه تشويش (accuracy > 100 متر)
    if (position.accuracy > 100) {
      _gpsFailCount++;
      if (_gpsFailCount >= _maxGpsTries) {
        setState(() => _showManualLocation = true);
      }
    } else {
      _gpsFailCount = 0;
      setState(() => _showManualLocation = false);
    }
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
      setState(
          () => isAvailable = (doc.data()?['available'] as bool?) ?? false);
    }
  }

  Future<void> _toggleAvailability(bool v) async {
    setState(() => isAvailable = v);
    await FirebaseFirestore.instance
        .collection('drivers')
        .doc(widget.driverId)
        .update({'available': v, 'currentOrderId': null});
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
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(widget.driverId)
          .update({'available': false});
    } catch (e) {
      // إذا لم يوجد المستند، أنشئه مع available=false
      if (e.toString().contains('not-found')) {
        await FirebaseFirestore.instance
            .collection('drivers')
            .doc(widget.driverId)
            .set({'available': false}, SetOptions(merge: true));
      } else {
        debugPrint('Firestore logout update error: ' + e.toString());
      }
    }
    await FirebaseAuth.instance.signOut();
    await prefs.remove('userType');
    Navigator.of(context)
        .pushNamedAndRemoveUntil('/roleSelection', (_) => false);
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

  Future<void> _loadAllLocations() async {
    setState(() {
      _allMarkers = {};
    });
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
                DrawerHeader(
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
                    leading: const Icon(Icons.history, color: AppThemeArabic.clientPrimary),
                    title: Text('سجل الطلبات',
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
                    leading: const Icon(Icons.person, color: AppThemeArabic.clientTextPrimary),
                    title:
                        Text('الحساب', style: TextStyle(fontFamily: 'Tajawal')),
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
                    leading: const Icon(Icons.monetization_on, color: AppThemeArabic.clientAccent),
                    title:
                        Text('أرباحي', style: TextStyle(fontFamily: 'Tajawal')),
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
                    leading: const Icon(Icons.assignment_turned_in, color: AppThemeArabic.clientPrimary),
                    title: Text('عرض الطلب الحالي',
                        style: TextStyle(fontFamily: 'Tajawal')),
                    onTap: () async {
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
                    leading: const Icon(Icons.account_balance_wallet, color: AppThemeArabic.clientAccent),
                    title:
                        Text('محفظتي', style: TextStyle(fontFamily: 'Tajawal')),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => CourierWalletScreen(
                                driverId: widget.driverId))),
                  ),
                ),
                const SizedBox(height: 8),
                Divider(),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Chip(
                        label: Text(isAvailable ? 'متاح للطلبات' : 'غير متاح',
                            style: TextStyle(
                                color: Colors.white, fontFamily: 'Tajawal')),
                        backgroundColor:
                          isAvailable ? AppThemeArabic.clientSuccess : AppThemeArabic.clientError,
                        avatar: Icon(
                            isAvailable ? Icons.check_circle : Icons.cancel,
                            color: Colors.white),
                      ),
                      const Spacer(),
                      Switch(
                        value: isAvailable,
                        onChanged: _toggleAvailability,
                        activeColor: AppThemeArabic.clientSuccess,
                      ),
                    ],
                  ),
                ),
                Divider(),
                Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const Icon(Icons.logout, color: AppThemeArabic.clientError),
                    title: Text('تسجيل الخروج',
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
            iconTheme: const IconThemeData(color: AppThemeArabic.clientPrimary),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
            leading: IconButton(
                icon: const Icon(Icons.menu, color: AppThemeArabic.clientPrimary),
                onPressed: () => _scaffoldKey.currentState!.openDrawer()),
            title: Row(children: [
              const Icon(Icons.delivery_dining, color: AppThemeArabic.clientPrimary),
              const SizedBox(width: 8),
              Text(isAvailable ? 'أنت متاح ✅' : 'غير متاح ',
                  style: const TextStyle(
                      color: AppThemeArabic.clientTextPrimary, fontWeight: FontWeight.bold)),
            ]),
            actions: [
              IconButton(
                icon: const Icon(Icons.support_agent, color: AppThemeArabic.clientPrimary),
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
                  boxShadow: [
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
                    markers: _allMarkers,
                  ),
                ),
              ),
              if (_showManualLocation)
                Positioned(
                  bottom: 24,
                  right: 24,
                  left: 24,
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.location_on),
                        label: const Text('تحديد الموقع يدويًا'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppThemeArabic.clientPrimary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('تنبيه هام'),
                              content: const Text(
                                  'تحديد الموقع يدويًا هو لضمان وصول الطلب إليك وتجنب التشويش. إذا علمنا أنك استخدمت موقعًا خاطئًا أو وهميًا سيتم إغلاق حسابك نهائيًا.'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('إلغاء'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('متابعة'),
                                ),
                              ],
                            ),
                          );
                          if (confirm != true) return;
                          final LatLng? picked = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ManualLocationPicker(
                                  initialLocation: _currentLocation),
                            ),
                          );
                          if (picked != null) {
                            setState(() {
                              _currentLocation = picked;
                              _isManualLocation = true;
                            });
                            _mapController
                                ?.animateCamera(CameraUpdate.newLatLng(picked));
                            FirebaseFirestore.instance
                                .collection('drivers')
                                .doc(widget.driverId)
                                .update({
                              'location':
                                  GeoPoint(picked.latitude, picked.longitude),
                              'lastLocationUpdate':
                                  FieldValue.serverTimestamp(),
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('تم تحديث الموقع يدويًا')));
                          }
                        },
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
