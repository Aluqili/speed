import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'package:speedstar_core/speedstar_core.dart'
    show formatUnifiedOrderCode;
import 'order_rating_sheet.dart';

class ClientOrderTrackingScreen extends StatefulWidget {
  final String orderId;
  const ClientOrderTrackingScreen({Key? key, required this.orderId})
      : super(key: key);

  @override
  State<ClientOrderTrackingScreen> createState() =>
      _ClientOrderTrackingScreenState();
}

class _ClientOrderTrackingScreenState
    extends State<ClientOrderTrackingScreen> {
  StreamSubscription<DocumentSnapshot>? _orderSub;
  StreamSubscription<DocumentSnapshot>? _driverSub;
  LatLng? _clientLocation;
  LatLng? _driverLocation;
  String? _driverName;
  bool _hasNotifiedArrival = false;
  bool _hasPromptedForRating = false;
  GoogleMapController? _mapController;

  static const Color _primary = AppThemeArabic.clientPrimary;
  static const Color _bg = AppThemeArabic.clientBackground;

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _listenToOrder();
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
      }

      final driverId = data['assignedDriverId'];
      if ((status == 'picked_up' || status == 'arrived_to_client') &&
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
            final cur = d['currentLocation'];
            final loc = d['location'];
            if (cur is Map && cur['lat'] != null && cur['lng'] != null) {
              _driverLocation = LatLng(
                  (cur['lat'] as num).toDouble(),
                  (cur['lng'] as num).toDouble());
            } else if (loc is GeoPoint) {
              _driverLocation = LatLng(loc.latitude, loc.longitude);
            }
            if (_driverLocation != null && _mapController != null) {
              _mapController!.animateCamera(
                  CameraUpdate.newLatLng(_driverLocation!));
            }
          }
          setState(() {});
        });
      }

      setState(() {});
    });
  }

  Future<void> _showArrivalNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'arrival_channel', 'إشعارات الوصول',
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
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: const Text('تتبع الطلب',
              style: TextStyle(
                  color: _primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  fontFamily: 'Tajawal')),
          iconTheme: const IconThemeData(color: _primary),
          shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .doc(widget.orderId)
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snap.hasData || !snap.data!.exists) {
              return const Center(child: Text('لا توجد بيانات لهذا الطلب.'));
            }

            final data = snap.data!.data()! as Map<String, dynamic>;
            final rawStatus =
                ((data['orderStatus'] ?? data['status']) as String? ?? '')
                    .trim();
            final orderStatus = _normalizeStatus(rawStatus);
            final total =
                (data['totalWithDelivery'] as num?)?.toDouble() ?? 0.0;
            final items =
                List<Map<String, dynamic>>.from(data['items'] ?? []);
            final canRateOrder = canSubmitOrderRating(data);
            final orderCode = formatUnifiedOrderCode(
                orderNumber: data['orderNumber'],
                orderId: data['orderId'],
                docId: widget.orderId);
            final restaurantName =
                (data['restaurantName'] ?? 'المطعم').toString();

            final showMap = _driverLocation != null ||
                _clientLocation != null;

            return Column(
              children: [
                // ── Map section ──────────────────────────────────────
                if (showMap)
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.38,
                    child: _buildMap(),
                  ),

                // ── Scrollable content ───────────────────────────────
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Order info card
                      _InfoCard(
                        orderCode: orderCode,
                        restaurantName: restaurantName,
                        total: total,
                        driverName: _driverName,
                      ),
                      const SizedBox(height: 16),

                      // Status timeline
                      _StatusTimeline(currentStatus: orderStatus),
                      const SizedBox(height: 16),

                      // Items
                      if (items.isNotEmpty) ...[
                        _SectionHeader(title: 'الأصناف (${items.length})'),
                        const SizedBox(height: 8),
                        _ItemsList(items: items),
                        const SizedBox(height: 16),
                      ],

                      // Rating card
                      if (canRateOrder)
                        _RatingCard(
                          onRate: () => showOrderRatingSheet(context,
                              orderId: widget.orderId, orderData: data),
                        )
                      else if ((data['restaurantRating'] as num?)
                              ?.toDouble() !=
                          null)
                        _RatedBadge(),

                      const SizedBox(height: 32),
                    ],
                  ),
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
          infoWindow:
              InfoWindow(title: _driverName ?? 'المندوب'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange),
        ),
      if (_clientLocation != null)
        Marker(
          markerId: const MarkerId('client'),
          position: _clientLocation!,
          infoWindow: const InfoWindow(title: 'موقعك'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen),
        ),
    };

    final polylines = <Polyline>{
      if (_driverLocation != null && _clientLocation != null)
        Polyline(
          polylineId: const PolylineId('route'),
          points: [_driverLocation!, _clientLocation!],
          width: 4,
          color: _primary,
          patterns: [PatternItem.dot, PatternItem.gap(8)],
        ),
    };

    final initialTarget = _driverLocation ?? _clientLocation!;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20)),
      child: GoogleMap(
        initialCameraPosition:
            CameraPosition(target: initialTarget, zoom: 14),
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
          Factory<OneSequenceGestureRecognizer>(
              () => EagerGestureRecognizer()),
        },
      ),
    );
  }

  void _fitBounds(List<LatLng> pts) {
    if (_mapController == null || pts.isEmpty) return;
    if (pts.length == 1) {
      _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
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

// ─── Sub-widgets ───────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard(
      {required this.orderCode,
      required this.restaurantName,
      required this.total,
      this.driverName});

  final String orderCode;
  final String restaurantName;
  final double total;
  final String? driverName;

  static const _primary = AppThemeArabic.clientPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0E000000), blurRadius: 12, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          // رأس البطاقة - اسم المطعم
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.storefront_rounded,
                      size: 16, color: _primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    restaurantName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF1A1D26)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${total.toStringAsFixed(2)} ج.س',
                  style: const TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          // تفاصيل إضافية
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                _Row(
                    icon: Icons.receipt_long_outlined,
                    label: 'رقم الطلب',
                    value: orderCode),
                if (driverName != null) ...[
                  const Divider(height: 14, thickness: 0.5),
                  _Row(
                      icon: Icons.delivery_dining_outlined,
                      label: 'المندوب',
                      value: driverName!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  static const _primary = AppThemeArabic.clientPrimary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _primary),
        const SizedBox(width: 8),
        Text(label,
            style:
                const TextStyle(color: Colors.grey, fontSize: 13)),
        const Spacer(),
        Flexible(
          child: Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.currentStatus});
  final String currentStatus;
  static const _primary = AppThemeArabic.clientPrimary;

  static const _steps = [
    ('store_pending', 'قيد المراجعة', Icons.pending_actions_rounded),
    ('courier_searching', 'جاري البحث عن مندوب', Icons.search_rounded),
    ('courier_assigned', 'تم تعيين المندوب', Icons.person_pin_rounded),
    ('picked_up', 'الطلب في الطريق', Icons.delivery_dining_rounded),
    ('arrived_to_client', 'وصل المندوب', Icons.location_on_rounded),
    ('delivered', 'تم التوصيل', Icons.check_circle_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex =
        _steps.indexWhere((s) => s.$1 == currentStatus);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('تقدم الطلب',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _primary)),
          const SizedBox(height: 12),
          ...List.generate(_steps.length, (i) {
            if (_steps[i].$1 == 'cancelled') return const SizedBox.shrink();
            final done = currentIndex >= 0 && i < currentIndex;
            final active = i == currentIndex;
            final pending = !done && !active;
            final isLast = i == _steps.length - 1;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // icon + line
                  Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: done
                              ? _primary
                              : active
                                  ? _primary
                                  : Colors.grey[100],
                          border: active
                              ? Border.all(color: _primary, width: 2.5)
                              : null,
                        ),
                        child: Icon(
                          done
                              ? Icons.check_rounded
                              : _steps[i].$3,
                          size: 16,
                          color: done || active
                              ? Colors.white
                              : Colors.grey[400],
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: done
                                ? _primary.withValues(alpha: 0.4)
                                : Colors.grey[200],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // label
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          bottom: isLast ? 0 : 20, top: 6),
                      child: Text(
                        _steps[i].$2,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: active
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: pending
                              ? Colors.grey[400]
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ItemsList extends StatelessWidget {
  const _ItemsList({required this.items});
  final List<Map<String, dynamic>> items;
  static const _primary = AppThemeArabic.clientPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          final item = items[i];
          final isLast = i == items.length - 1;
          return Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: _primary.withValues(alpha: 0.1),
                  child: const Icon(Icons.restaurant_menu_rounded,
                      size: 14, color: _primary),
                ),
                title: Text(item['name'] ?? '',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
                subtitle: Text(
                  'x${item['quantity']}  •  ${item['price']} ج.س',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey[600]),
                ),
                dense: true,
              ),
              if (!isLast)
                const Divider(height: 1, indent: 56),
            ],
          );
        }),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.black87));
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({required this.onRate});
  final VoidCallback onRate;
  static const _primary = AppThemeArabic.clientPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _primary.withValues(alpha: 0.08),
            _primary.withValues(alpha: 0.02)
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.star_rounded, color: Colors.amber, size: 22),
              SizedBox(width: 8),
              Text('قيّم تجربتك',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'شاركنا رأيك في المطعم والمندوب لمساعدة بقية العملاء.',
            style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onRate,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
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

class _RatedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
          SizedBox(width: 8),
          Text('تم إرسال تقييمك لهذا الطلب.',
              style: TextStyle(
                  color: Colors.green, fontWeight: FontWeight.w600)),
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
