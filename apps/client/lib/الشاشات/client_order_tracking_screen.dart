import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../الثيم/client_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:speedstar_core/speedstar_core.dart' show formatUnifiedOrderCode;
import '../الخدمات/route_estimate_service.dart';
import '../الخدمات/map_marker_icon_factory.dart';
import 'order_rating_sheet.dart';
import 'chat_screen.dart';

class ClientOrderTrackingScreen extends StatefulWidget {
  final String orderId;
  const ClientOrderTrackingScreen({super.key, required this.orderId});

  @override
  State<ClientOrderTrackingScreen> createState() =>
      _ClientOrderTrackingScreenState();
}

BoxDecoration _trackingCardDecoration({
  double radius = 18,
  Color color = Colors.white,
  Color borderColor = const Color(0x14FF6B00),
  double shadowOpacity = 0.07,
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderColor),
    boxShadow: ClientColors.softCardShadow(
      opacity: shadowOpacity,
      blur: 18,
      offset: const Offset(0, 8),
    ),
  );
}

class _ClientOrderTrackingScreenState extends State<ClientOrderTrackingScreen> {
  StreamSubscription<DocumentSnapshot>? _orderSub;
  StreamSubscription<DocumentSnapshot>? _driverSub;
  LatLng? _clientLocation;
  LatLng? _driverLocation;
  String? _driverName;
  String? _driverPhone;
  String? _driverId;
  bool _hasNotifiedArrival = false;
  bool _hasPromptedForRating = false;
  GoogleMapController? _mapController;
  List<LatLng> _routePoints = const [];
  int? _routeDurationMinutes;
  int _routeGeneration = 0;
  BitmapDescriptor? _driverMarkerIcon;
  BitmapDescriptor? _clientMarkerIcon;

  String get _clientId => FirebaseAuth.instance.currentUser?.uid ?? '';

  String _generateChatId(String a, String b) {
    final sorted = [a, b]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  static const Color _primary = ClientColors.primary;
  static const Color _bg = ClientColors.lightBackground;

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
    _initNotifications();
    _listenToOrder();
  }

  Future<void> _loadMarkerIcons() async {
    final icons = await Future.wait([
      MapMarkerIconFactory.create(
        icon: Icons.delivery_dining_rounded,
        color: ClientColors.primary,
      ),
      MapMarkerIconFactory.create(
        icon: Icons.person_pin_circle_rounded,
        color: const Color(0xFF12A150),
      ),
    ]);
    if (!mounted) return;
    setState(() {
      _driverMarkerIcon = icons[0];
      _clientMarkerIcon = icons[1];
    });
  }

  Future<void> _initNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notificationsPlugin.initialize(
        settings: const InitializationSettings(android: android));
  }

  void _listenToOrder() {
    _orderSub = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .snapshots()
        .listen((snap) {
      final data = snap.data();
      if (data == null) return;

      final status = _normalizeStatus(
          ((data['orderStatus'] ?? data['status']) as String? ?? '').trim());

      if (status == 'delivered' && !_hasNotifiedArrival) {
        _hasNotifiedArrival = true;
        _showArrivalNotification();
      }

      if (status == 'delivered' &&
          canSubmitOrderRating(data) &&
          !_hasPromptedForRating) {
        _hasPromptedForRating = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          await showOrderRatingSheet(context,
              orderId: widget.orderId, orderData: data);
        });
      }

      final clientLoc = data['clientLocation'];
      if (clientLoc is GeoPoint) {
        _clientLocation = LatLng(clientLoc.latitude, clientLoc.longitude);
        _refreshRoute();
      }

      final driverId = data['assignedDriverId'] as String?;
      if (driverId != null && _driverId != driverId) {
        setState(() => _driverId = driverId);
      }
      if ((status == 'courier_assigned' ||
              status == 'pickup_ready' ||
              status == 'picked_up' ||
              status == 'arrived_to_client') &&
          driverId != null) {
        _driverSub?.cancel();
        _driverSub = FirebaseFirestore.instance
            .collection('drivers')
            .doc(driverId)
            .snapshots()
            .listen((dSnap) {
          final d = dSnap.data();
          if (d != null) {
            _driverName = d['name'];
            _driverPhone = d['phone'];
            final cur = d['currentLocation'];
            final loc = d['location'];
            if (cur is Map && cur['lat'] != null && cur['lng'] != null) {
              _driverLocation = LatLng((cur['lat'] as num).toDouble(),
                  (cur['lng'] as num).toDouble());
            } else if (loc is GeoPoint) {
              _driverLocation = LatLng(loc.latitude, loc.longitude);
            }
            if (_driverLocation != null && _mapController != null) {
              _mapController!
                  .animateCamera(CameraUpdate.newLatLng(_driverLocation!));
            }
            _refreshRoute();
          }
          setState(() {});
        });
      }

      setState(() {});
    });
  }

  Future<void> _showArrivalNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'arrival_channel',
      'إشعارات الوصول',
      channelDescription: 'تنبيهات وصول الطلبات',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    await _notificationsPlugin.show(
        id: 0,
        title: 'وصل طلبك',
        body: 'تم توصيل طلبك بنجاح.',
        notificationDetails:
            const NotificationDetails(android: androidDetails));
  }

  Future<void> _refreshRoute() async {
    final driver = _driverLocation;
    final client = _clientLocation;
    if (driver == null || client == null) return;
    final generation = ++_routeGeneration;
    final estimate = await RouteEstimateService.estimate(
      origin: driver,
      destination: client,
      timeout: const Duration(seconds: 5),
    );
    if (!mounted || generation != _routeGeneration) return;
    final points = estimate.polylinePoints;
    setState(() {
      _routeDurationMinutes = estimate.durationMinutes;
      _routePoints = points.length >= 2 ? points : [driver, client];
    });
  }

  String _calculateETA() {
    if (_routeDurationMinutes != null) {
      return '$_routeDurationMinutes دقيقة';
    }
    if (_driverLocation == null || _clientLocation == null) return '—';
    const earthRadius = 6371.0;
    final lat1 = _driverLocation!.latitude * pi / 180;
    final lat2 = _clientLocation!.latitude * pi / 180;
    final dlat =
        (_clientLocation!.latitude - _driverLocation!.latitude) * pi / 180;
    final dlng =
        (_clientLocation!.longitude - _driverLocation!.longitude) * pi / 180;
    final a = sin(dlat / 2) * sin(dlat / 2) +
        cos(lat1) * cos(lat2) * sin(dlng / 2) * sin(dlng / 2);
    final distKm = earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a));
    final minutes = (distKm / 30 * 60).round();
    if (minutes < 1) return 'أقل من دقيقة';
    return '$minutes دقيقة';
  }

  @override
  void dispose() {
    _orderSub?.cancel();
    _driverSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        extendBodyBehindAppBar: true,
        appBar: _GlassAppBar(
          onChat: _driverId != null
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        currentUserId: _clientId,
                        otherUserId: _driverId!,
                        currentUserRole: 'client',
                        chatId: _generateChatId(_clientId, _driverId!),
                        currentUserName: 'العميل',
                      ),
                    ),
                  )
              : null,
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .doc(widget.orderId)
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: _primary));
            }
            if (!snap.hasData || !snap.data!.exists) {
              return const Center(
                  child: Text('لا توجد بيانات لهذا الطلب.',
                      style: TextStyle(color: ClientColors.lightTextPrimary)));
            }

            final data = snap.data!.data()! as Map<String, dynamic>;
            final rawStatus =
                ((data['orderStatus'] ?? data['status']) as String? ?? '')
                    .trim();
            final orderStatus = _normalizeStatus(rawStatus);
            final total =
                (data['totalWithDelivery'] as num?)?.toDouble() ?? 0.0;
            final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
            final canRateOrder = canSubmitOrderRating(data);
            final orderCode = formatUnifiedOrderCode(
                orderNumber: data['orderNumber'],
                orderId: data['orderId'],
                docId: widget.orderId);
            final restaurantName =
                (data['restaurantName'] ?? 'المطعم').toString();
            final showMap = _driverLocation != null || _clientLocation != null;
            final eta = _calculateETA();

            return Stack(
              children: [
                // ── Full-screen map or gradient background ──────────────
                if (showMap)
                  Positioned.fill(child: _buildMap())
                else
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFFFBF7), Color(0xFFFFF1E6)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),

                // ── Draggable glass panel ────────────────────────────────
                DraggableScrollableSheet(
                  initialChildSize: 0.52,
                  minChildSize: 0.25,
                  maxChildSize: 0.92,
                  builder: (ctx, scrollController) {
                    return ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(28)),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFAFFFFFF),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(28)),
                            border: const Border(
                              top: BorderSide(
                                  color: Color(0x33FF6B00), width: 1),
                              left: BorderSide(
                                  color: Color(0x1AFF6B00), width: 0.5),
                              right: BorderSide(
                                  color: Color(0x1AFF6B00), width: 0.5),
                            ),
                            boxShadow: ClientColors.softCardShadow(
                              opacity: 0.10,
                              blur: 24,
                              offset: const Offset(0, -8),
                            ),
                          ),
                          child: ListView(
                            controller: scrollController,
                            padding: EdgeInsets.zero,
                            children: [
                              // Drag handle
                              Center(
                                child: Container(
                                  margin:
                                      const EdgeInsets.only(top: 12, bottom: 8),
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: const Color(0x66FF6B00),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),

                              // ETA + driver info
                              if (_driverLocation != null &&
                                  _driverName != null)
                                _ETADriverRow(
                                  driverName: _driverName!,
                                  eta: eta,
                                  phone: _driverPhone,
                                ),

                              // Status progress bar
                              _GlassStatusBar(currentStatus: orderStatus),
                              const SizedBox(height: 10),

                              // Order info
                              _GlassInfoCard(
                                orderCode: orderCode,
                                restaurantName: restaurantName,
                                total: total,
                                driverName: _driverName,
                              ),
                              const SizedBox(height: 12),

                              // Items
                              if (items.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Text('الأصناف (${items.length})',
                                      style: const TextStyle(
                                          color:
                                              ClientColors.lightTextSecondary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                ),
                                const SizedBox(height: 8),
                                _GlassItemsList(items: items),
                                const SizedBox(height: 12),
                              ],

                              // Rating
                              if (canRateOrder)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: _GlassRatingCard(
                                    onRate: () => showOrderRatingSheet(context,
                                        orderId: widget.orderId,
                                        orderData: data),
                                  ),
                                )
                              else if ((data['restaurantRating'] as num?)
                                      ?.toDouble() !=
                                  null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: _GlassRatedBadge(),
                                ),

                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMap() {
    final markers = <Marker>{
      if (_driverLocation != null)
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverLocation!,
          infoWindow: InfoWindow(title: _driverName ?? 'المندوب'),
          icon: _driverMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ),
      if (_clientLocation != null)
        Marker(
          markerId: const MarkerId('client'),
          position: _clientLocation!,
          infoWindow: const InfoWindow(title: 'موقعك'),
          icon: _clientMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
    };

    final polylines = <Polyline>{
      if (_routePoints.length >= 2)
        Polyline(
          polylineId: const PolylineId('route'),
          points: _routePoints,
          width: 5,
          color: _primary,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
    };

    final initialTarget = _driverLocation ?? _clientLocation!;

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: initialTarget, zoom: 14),
      markers: markers,
      polylines: polylines,
      onMapCreated: (c) {
        _mapController = c;
        if (_driverLocation != null && _clientLocation != null) {
          _fitBounds([_driverLocation!, _clientLocation!]);
        }
      },
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      gestureRecognizers: {
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      },
    );
  }

  void _fitBounds(List<LatLng> pts) {
    if (_mapController == null || pts.isEmpty) return;
    if (pts.length == 1) {
      _mapController!.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: pts.first, zoom: 15)));
      return;
    }
    double minLat = pts.first.latitude,
        maxLat = minLat,
        minLng = pts.first.longitude,
        maxLng = minLng;
    for (final p in pts.skip(1)) {
      minLat = min(minLat, p.latitude);
      maxLat = max(maxLat, p.latitude);
      minLng = min(minLng, p.longitude);
      maxLng = max(maxLng, p.longitude);
    }
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng)),
        80));
  }
}

// ─── Glass AppBar ──────────────────────────────────────────────────────────

class _GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _GlassAppBar({this.onChat});
  final VoidCallback? onChat;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            boxShadow: ClientColors.softCardShadow(
              opacity: 0.05,
              blur: 12,
              offset: const Offset(0, 4),
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: ClientColors.lightTextPrimary, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Expanded(
                  child: Text('تتبع الطلب',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: ClientColors.lightTextPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          fontFamily: 'Tajawal')),
                ),
                if (onChat != null)
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0x33FF6B00),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0x4DFF6B00), width: 0.5),
                      ),
                      child: const Icon(Icons.chat_bubble_rounded,
                          color: ClientColors.primary, size: 18),
                    ),
                    onPressed: onChat,
                  )
                else
                  const SizedBox(width: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── ETA & Driver Row ──────────────────────────────────────────────────────

class _ETADriverRow extends StatelessWidget {
  const _ETADriverRow(
      {required this.driverName, required this.eta, this.phone});
  final String driverName;
  final String eta;
  final String? phone;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: _trackingCardDecoration(
        color: const Color(0xFFFFF8F3),
        borderColor: const Color(0x24FF6B00),
        shadowOpacity: 0.06,
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x4DFF6B00),
            ),
            child: const Icon(Icons.delivery_dining_rounded,
                color: ClientColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(driverName,
                    style: const TextStyle(
                        color: ClientColors.lightTextPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  textDirection: TextDirection.rtl,
                  children: [
                    const Icon(Icons.timer_outlined,
                        size: 13, color: ClientColors.primaryLight),
                    const SizedBox(width: 4),
                    Text('الوصول خلال $eta',
                        style: const TextStyle(
                            color: ClientColors.primaryLight, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          if (phone != null)
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('رقم المندوب: $phone'),
                      backgroundColor: ClientColors.primary),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ClientColors.primary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: ClientColors.primary.withValues(alpha: 0.4),
                        blurRadius: 10),
                  ],
                ),
                child: const Icon(Icons.phone_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Glass Status Bar ──────────────────────────────────────────────────────

class _GlassStatusBar extends StatelessWidget {
  const _GlassStatusBar({required this.currentStatus});
  final String currentStatus;

  static const _steps = [
    ('store_pending', 'مراجعة', Icons.pending_actions_rounded),
    ('courier_searching', 'بحث', Icons.search_rounded),
    ('courier_assigned', 'تعيين', Icons.person_pin_rounded),
    ('picked_up', 'في الطريق', Icons.delivery_dining_rounded),
    ('arrived_to_client', 'وصل', Icons.location_on_rounded),
    ('delivered', 'تم', Icons.check_circle_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _steps.indexWhere((s) => s.$1 == currentStatus);
    final progressIndex = currentIndex < 0 ? 0 : currentIndex;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: _trackingCardDecoration(
        borderColor: const Color(0x12000000),
        shadowOpacity: 0.06,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_steps.length, (i) {
              final done = i < progressIndex;
              final active = i == progressIndex;
              return Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done || active
                            ? ClientColors.primary
                            : const Color(0xFFF3F3F3),
                        boxShadow: active
                            ? [
                                BoxShadow(
                                    color: ClientColors.primary
                                        .withValues(alpha: 0.18),
                                    blurRadius: 10)
                              ]
                            : null,
                      ),
                      child: Icon(_steps[i].$3,
                          size: 14,
                          color: done || active
                              ? Colors.white
                              : ClientColors.lightTextSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(_steps[i].$2,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: active
                                ? ClientColors.primary
                                : ClientColors.lightTextSecondary,
                            fontSize: 9,
                            fontWeight:
                                active ? FontWeight.bold : FontWeight.normal)),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _steps.isEmpty ? 0 : (progressIndex + 1) / _steps.length,
              backgroundColor: const Color(0xFFEDEDED),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(ClientColors.primary),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Glass Info Card ───────────────────────────────────────────────────────

class _GlassInfoCard extends StatelessWidget {
  const _GlassInfoCard({
    required this.orderCode,
    required this.restaurantName,
    required this.total,
    this.driverName,
  });
  final String orderCode;
  final String restaurantName;
  final double total;
  final String? driverName;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: _trackingCardDecoration(
        borderColor: const Color(0x12000000),
        shadowOpacity: 0.06,
      ),
      child: Column(
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              const Icon(Icons.storefront_rounded,
                  size: 16, color: ClientColors.primary),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(restaurantName,
                      style: const TextStyle(
                          color: ClientColors.lightTextPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis)),
              Text('${total.toStringAsFixed(2)} ج.س',
                  style: const TextStyle(
                      color: ClientColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 14)),
            ],
          ),
          const Divider(color: Color(0xFFEDEDED), height: 16),
          Row(
            textDirection: TextDirection.rtl,
            children: [
              const Icon(Icons.receipt_long_outlined,
                  size: 14, color: ClientColors.lightTextSecondary),
              const SizedBox(width: 6),
              const Text('رقم الطلب',
                  style: TextStyle(
                      color: ClientColors.lightTextSecondary, fontSize: 12)),
              const Spacer(),
              Text(orderCode,
                  style: const TextStyle(
                      color: ClientColors.lightTextPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Glass Items List ──────────────────────────────────────────────────────

class _GlassItemsList extends StatelessWidget {
  const _GlassItemsList({required this.items});
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: _trackingCardDecoration(
        radius: 16,
        borderColor: const Color(0x12000000),
        shadowOpacity: 0.06,
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          final item = items[i];
          final isLast = i == items.length - 1;
          return Column(
            children: [
              ListTile(
                leading: const CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0x33FF6B00),
                  child: Icon(Icons.restaurant_menu_rounded,
                      size: 14, color: ClientColors.primary),
                ),
                title: Text(item['name'] ?? '',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ClientColors.lightTextPrimary)),
                subtitle: Text('x${item['quantity']}  •  ${item['price']} ج.س',
                    style: const TextStyle(
                        fontSize: 11, color: ClientColors.lightTextSecondary)),
                dense: true,
              ),
              if (!isLast)
                const Divider(height: 1, color: Color(0xFFEDEDED), indent: 56),
            ],
          );
        }),
      ),
    );
  }
}

// ─── Glass Rating Card ─────────────────────────────────────────────────────

class _GlassRatingCard extends StatelessWidget {
  const _GlassRatingCard({required this.onRate});
  final VoidCallback onRate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _trackingCardDecoration(
        radius: 16,
        borderColor: const Color(0x24FF6B00),
        shadowOpacity: 0.06,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Row(
            textDirection: TextDirection.rtl,
            children: [
              Icon(Icons.star_rounded, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text('قيّم تجربتك',
                  style: TextStyle(
                      color: ClientColors.lightTextPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('شاركنا رأيك في المطعم والمندوب لمساعدة بقية العملاء.',
              textAlign: TextAlign.right,
              style: TextStyle(
                  color: ClientColors.lightTextSecondary,
                  fontSize: 12,
                  height: 1.4)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onRate,
              style: ElevatedButton.styleFrom(
                backgroundColor: ClientColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
              icon: const Icon(Icons.star_rate_rounded, size: 18),
              label: const Text('إرسال تقييم',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Glass Rated Badge ─────────────────────────────────────────────────────

class _GlassRatedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFFFF5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x3300E676)),
        boxShadow: ClientColors.softCardShadow(
          opacity: 0.05,
          blur: 14,
          offset: const Offset(0, 6),
        ),
      ),
      child: const Row(
        textDirection: TextDirection.rtl,
        children: [
          Icon(Icons.check_circle_rounded,
              color: ClientColors.success, size: 18),
          SizedBox(width: 8),
          Text('تم إرسال تقييمك لهذا الطلب.',
              style: TextStyle(
                  color: ClientColors.success, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Status helpers ────────────────────────────────────────────────────────

String _normalizeStatus(String status) {
  switch (status) {
    case 'انتظار الدفع':
    case 'payment_review':
    case 'store_pending':
    case 'قيد المراجعة':
      return 'store_pending';
    case 'courier_searching':
    case 'قيد التجهيز':
      return 'courier_searching';
    case 'courier_offer_pending':
    case 'courier_assigned':
    case 'pickup_ready':
    case 'جاهز للتوصيل':
      return 'courier_assigned';
    case 'picked_up':
    case 'قيد التوصيل':
      return 'picked_up';
    case 'arrived_to_client':
    case 'وصل إلى العميل':
      return 'arrived_to_client';
    case 'delivered':
    case 'تم التوصيل':
      return 'delivered';
    case 'cancelled':
    case 'store_rejected':
    case 'ملغي':
      return 'cancelled';
    default:
      return 'store_pending';
  }
}
