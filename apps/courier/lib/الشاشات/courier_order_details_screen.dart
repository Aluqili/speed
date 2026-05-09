import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'dart:math';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'package:speedstar_core/speedstar_core.dart'
    show formatUnifiedOrderCode, OrderStatusPalette;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../helpers/courier_runtime_helpers.dart';

import 'chat_screen.dart' show ChatScreen;
import 'courier_go_to_restaurant_screen.dart';
import 'courier_go_to_client_screen.dart';
import 'courier_confirm_delivery_screen.dart';

class CourierOrderDetailsScreen extends StatefulWidget {
  final String orderId;
  final String driverId;

  const CourierOrderDetailsScreen({
    super.key,
    required this.orderId,
    required this.driverId,
  });

  @override
  State<CourierOrderDetailsScreen> createState() =>
      _CourierOrderDetailsScreenState();
}

class _CourierOrderDetailsScreenState extends State<CourierOrderDetailsScreen> {
  Map<String, dynamic>? orderData;
  double deliveryFee = 0;
  CourierMarkerIcons? _markerIcons;
  List<LatLng> _driverRestaurantRoute = const [];
  List<LatLng> _restaurantClientRoute = const [];
  double? _driverRestaurantRoadKm;
  double? _restaurantClientRoadKm;
  String _loadedRouteKey = '';
  bool _fetchingRoutes = false;
  GoogleMapController? _orderMapController;

  double get _driverBaseFee {
    try {
      final value = FirebaseRemoteConfig.instance
          .getDouble('pricing_driver_delivery_base_fee');
      return value >= 0 ? value : 4000.0;
    } catch (_) {
      return 4000.0;
    }
  }

  double get _driverBaseDistanceKm {
    try {
      final value = FirebaseRemoteConfig.instance
          .getDouble('pricing_driver_delivery_base_distance_km');
      return value >= 0 ? value : 6.0;
    } catch (_) {
      return 6.0;
    }
  }

  double get _driverExtraPerKm {
    try {
      final value = FirebaseRemoteConfig.instance
          .getDouble('pricing_driver_delivery_extra_per_km');
      return value >= 0 ? value : 500.0;
    } catch (_) {
      return 500.0;
    }
  }

  double _driverFeeByDistance(double distanceKm) {
    final safeDistance = distanceKm < 0 ? 0.0 : distanceKm;
    if (safeDistance <= _driverBaseDistanceKm) {
      return _driverBaseFee;
    }
    final extraKm = (safeDistance - _driverBaseDistanceKm).ceil();
    return _driverBaseFee + (extraKm * _driverExtraPerKm);
  }

  String _getOrderStatus(Map<String, dynamic> data) {
    return (data['orderStatus'] ?? data['status'] ?? '').toString().trim();
  }

  @override
  void initState() {
    super.initState();
    loadCourierMarkerIcons().then((icons) {
      if (!mounted) return;
      setState(() {
        _markerIcons = icons;
      });
    });
    _loadOrderData();
  }

  Future<void> _loadOrderData() async {
    final docSnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .get();

    if (docSnapshot.exists) {
      final data = docSnapshot.data()!;
      final assignedDriverId = (data['assignedDriverId'] ?? '').toString();
      final offeredDriverId = (data['offeredDriverId'] ?? '').toString();
      final status = _getOrderStatus(data);

      final belongsToAnotherAssigned =
          assignedDriverId.isNotEmpty && assignedDriverId != widget.driverId;
      final belongsToAnotherOffer = status == 'courier_offer_pending' &&
          offeredDriverId.isNotEmpty &&
          offeredDriverId != widget.driverId;

      if (belongsToAnotherAssigned || belongsToAnotherOffer) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('تم استلام هذا الطلب بواسطة مندوب آخر')),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      if (data['restaurantLat'] != null &&
          data['restaurantLng'] != null &&
          data['clientLat'] != null &&
          data['clientLng'] != null) {
        double distanceInKm = _calculateDistance(
          data['restaurantLat'],
          data['restaurantLng'],
          data['clientLat'],
          data['clientLng'],
        );
        deliveryFee = _driverFeeByDistance(distanceInKm);
      }

      try {
        final driverDoc = await FirebaseFirestore.instance
            .collection('drivers')
            .doc(widget.driverId)
            .get();
        final driverData = driverDoc.data() ?? <String, dynamic>{};
        final loc = driverData['location'];
        if (loc is GeoPoint) {
          data['driverLat'] = loc.latitude;
          data['driverLng'] = loc.longitude;
        } else if (loc is Map<String, dynamic>) {
          data['driverLat'] = (loc['lat'] as num?)?.toDouble() ??
              (loc['latitude'] as num?)?.toDouble();
          data['driverLng'] = (loc['lng'] as num?)?.toDouble() ??
              (loc['longitude'] as num?)?.toDouble();
        }
      } catch (_) {}

      setState(() {
        orderData = data;
      });
    }
  }

  double _calculateDistance(
      double lat1, double lng1, double lat2, double lng2) {
    const double R = 6371;
    double dLat = _deg2rad(lat2 - lat1);
    double dLon = _deg2rad(lng2 - lng1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180);

  List<LatLng> _decodePolyline(String encoded) {
    if (encoded.isEmpty) return const [];
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      var shift = 0;
      var result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20 && index < encoded.length);
      lat += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20 && index < encoded.length);
      lng += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  Future<Map<String, dynamic>?> _estimateRoute(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final result = await FirebaseFunctions.instanceFor(region: 'me-central1')
          .httpsCallable('estimateRoute')
          .call({
        'origin': {'lat': origin.latitude, 'lng': origin.longitude},
        'destination': {
          'lat': destination.latitude,
          'lng': destination.longitude,
        },
      }).timeout(const Duration(seconds: 5));
      return Map<String, dynamic>.from(result.data as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> _fitOrderMapBounds({
    required LatLng? driverLocation,
    required LatLng? restaurantLocation,
    required LatLng? clientLocation,
  }) async {
    final controller = _orderMapController;
    if (controller == null) return;
    final points = [
      if (driverLocation != null) driverLocation,
      if (restaurantLocation != null) restaurantLocation,
      if (clientLocation != null) clientLocation,
    ];
    if (points.isEmpty) return;
    if (points.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 14),
      );
      return;
    }

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points.skip(1)) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    if (minLat == maxLat) {
      minLat -= 0.002;
      maxLat += 0.002;
    }
    if (minLng == maxLng) {
      minLng -= 0.002;
      maxLng += 0.002;
    }

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        54,
      ),
    );
  }

  Future<void> _loadRoadRoutes({
    required LatLng? driverLocation,
    required LatLng? restaurantLocation,
    required LatLng? clientLocation,
  }) async {
    if (_fetchingRoutes) return;
    if (restaurantLocation == null || clientLocation == null) return;
    final routeKey = [
      driverLocation?.latitude.toStringAsFixed(6) ?? 'no-driver',
      driverLocation?.longitude.toStringAsFixed(6) ?? 'no-driver',
      restaurantLocation.latitude.toStringAsFixed(6),
      restaurantLocation.longitude.toStringAsFixed(6),
      clientLocation.latitude.toStringAsFixed(6),
      clientLocation.longitude.toStringAsFixed(6),
    ].join('|');
    final hasCachedRestaurantClient = _restaurantClientRoute.length >= 2;
    final hasCachedDriverRestaurant =
        driverLocation == null || _driverRestaurantRoute.length >= 2;
    if (_loadedRouteKey == routeKey &&
        hasCachedRestaurantClient &&
        hasCachedDriverRestaurant) {
      return;
    }

    _fetchingRoutes = true;
    try {
      final driverRestaurant = driverLocation == null
          ? null
          : await _estimateRoute(driverLocation, restaurantLocation);
      final restaurantClient =
          await _estimateRoute(restaurantLocation, clientLocation);

      List<LatLng> routePoints(
        Map<String, dynamic>? route,
        LatLng start,
        LatLng end,
      ) {
        final decoded =
            _decodePolyline((route?['encodedPolyline'] ?? '').toString());
        return decoded.length >= 2 ? decoded : [start, end];
      }

      final restaurantClientKm =
          ((restaurantClient?['distanceKm'] ?? 0) as num?)?.toDouble();

      if (!mounted) return;
      setState(() {
        _loadedRouteKey = routeKey;
        if (driverLocation != null) {
          _driverRestaurantRoute = routePoints(
            driverRestaurant,
            driverLocation,
            restaurantLocation,
          );
          _driverRestaurantRoadKm =
              ((driverRestaurant?['distanceKm'] ?? 0) as num?)?.toDouble();
        }
        _restaurantClientRoute = routePoints(
          restaurantClient,
          restaurantLocation,
          clientLocation,
        );
        _restaurantClientRoadKm = restaurantClientKm;
        if (restaurantClientKm != null && restaurantClientKm > 0) {
          deliveryFee = _driverFeeByDistance(restaurantClientKm);
        }
      });
    } finally {
      _fetchingRoutes = false;
    }
  }

  Future<void> _acceptOrder() async {
    if (orderData == null) return;

    final status = _getOrderStatus(orderData!);
    final offeredDriverId = (orderData!['offeredDriverId'] ?? '').toString();
    if (status != 'courier_offer_pending' ||
        offeredDriverId != widget.driverId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذا العرض غير متاح لك الآن')),
      );
      return;
    }

    await FirebaseFunctions.instanceFor(region: 'me-central1')
        .httpsCallable('courierRespondToOffer')
        .call({
      'orderId': widget.orderId,
      'driverId': widget.driverId,
      'decision': 'accept',
    });

    await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .update({
      'deliveryFeeForDriver': deliveryFee,
      'acceptedAt': Timestamp.now(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم قبول الطلب')),
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CourierGoToRestaurantScreen(
          orderId: widget.orderId,
          driverId: widget.driverId,
        ),
      ),
    );
  }

  LatLng? _resolvePoint(
    Map<String, dynamic> data, {
    required String rawKey,
    required String latKey,
    required String lngKey,
  }) {
    final raw = data[rawKey];
    if (raw is GeoPoint) return LatLng(raw.latitude, raw.longitude);
    if (raw is Map<String, dynamic>) {
      final lat = (raw['lat'] as num?)?.toDouble() ??
          (raw['latitude'] as num?)?.toDouble();
      final lng = (raw['lng'] as num?)?.toDouble() ??
          (raw['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    final lat = (data[latKey] as num?)?.toDouble();
    final lng = (data[lngKey] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  Future<void> _openProfessionalFlow() async {
    if (orderData == null || !mounted) return;
    final status = _getOrderStatus(orderData!);
    final clientLoc = _resolvePoint(
      orderData!,
      rawKey: 'clientLocation',
      latKey: 'clientLat',
      lngKey: 'clientLng',
    );

    if (status == 'courier_assigned' ||
        status == 'pickup_ready' ||
        status == 'جاهز للتوصيل') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CourierGoToRestaurantScreen(
            orderId: widget.orderId,
            driverId: widget.driverId,
          ),
        ),
      );
      return;
    }

    if (status == 'picked_up' || status == 'قيد التوصيل') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CourierGoToClientScreen(
            orderId: widget.orderId,
            clientLocation: clientLoc,
            driverId: widget.driverId,
          ),
        ),
      );
      return;
    }

    if (status == 'arrived_to_client' || status == 'وصل إلى العميل') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CourierConfirmDeliveryScreen(
            orderId: widget.orderId,
            driverId: widget.driverId,
          ),
        ),
      );
    }
  }

  Future<void> _rejectOffer() async {
    await FirebaseFunctions.instanceFor(region: 'me-central1')
        .httpsCallable('courierRespondToOffer')
        .call({
      'orderId': widget.orderId,
      'driverId': widget.driverId,
      'decision': 'reject',
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم رفض العرض وسيتم إرساله لمندوب آخر')),
    );
    Navigator.pop(context);
  }

  String _generateChatId(String user1, String user2) {
    final ids = [user1, user2]..sort();
    return ids.join('_');
  }

  bool _isOrderFinished(String status) {
    final normalized = status.trim().toLowerCase();
    return normalized == 'delivered' ||
        normalized == 'cancelled' ||
        normalized == 'store_rejected' ||
        status.trim() == 'تم التوصيل' ||
        status.trim() == 'ملغي';
  }

  @override
  Widget build(BuildContext context) {
    final data = orderData;
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الطلب',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppThemeArabic.courierPrimary,
                fontFamily: 'Tajawal',
                fontSize: 20)),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppThemeArabic.courierPrimary),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
        ),
      ),
      backgroundColor: AppThemeArabic.courierBackground,
      body: data == null
          ? const Center(child: CircularProgressIndicator())
          : Builder(builder: (context) {
              final status = _getOrderStatus(data);
              final clientId = (data['clientId'] ?? '').toString().trim();
              final isFinished = _isOrderFinished(status);
              final isOfferForMe = status == 'courier_offer_pending' &&
                  (data['offeredDriverId'] ?? '').toString() == widget.driverId;

              final restaurantLocation = _resolvePoint(
                data,
                rawKey: 'restaurantLocation',
                latKey: 'restaurantLat',
                lngKey: 'restaurantLng',
              );
              final clientLocation = _resolvePoint(
                data,
                rawKey: 'clientLocation',
                latKey: 'clientLat',
                lngKey: 'clientLng',
              );
              final driverLocation = _resolvePoint(
                data,
                rawKey: 'driverLocation',
                latKey: 'driverLat',
                lngKey: 'driverLng',
              );

              final restaurantToClientKm =
                  _restaurantClientRoadKm ??
                  (restaurantLocation != null && clientLocation != null
                      ? courierHaversineKm(restaurantLocation, clientLocation)
                      : null);

              final driverToRestaurantKm =
                  _driverRestaurantRoadKm ??
                  (driverLocation != null && restaurantLocation != null
                      ? courierHaversineKm(driverLocation, restaurantLocation)
                      : null);

              if (restaurantLocation != null && clientLocation != null) {
                Future.microtask(
                  () => _loadRoadRoutes(
                    driverLocation: driverLocation,
                    restaurantLocation: restaurantLocation,
                    clientLocation: clientLocation,
                  ),
                );
              }

              final markers = buildCourierTripMarkers(
                restaurantLocation: restaurantLocation,
                clientLocation: clientLocation,
                driverLocation: driverLocation,
                showDriverMarker: true,
                icons: _markerIcons,
              );

              final polylines = <Polyline>{
                if (driverLocation != null && restaurantLocation != null)
                  Polyline(
                    polylineId: const PolylineId('driver_restaurant'),
                    points: _driverRestaurantRoute.length >= 2
                        ? _driverRestaurantRoute
                        : [driverLocation, restaurantLocation],
                    color: AppThemeArabic.courierAccent,
                    width: 5,
                    startCap: Cap.roundCap,
                    endCap: Cap.roundCap,
                    jointType: JointType.round,
                  ),
                if (restaurantLocation != null && clientLocation != null)
                  Polyline(
                    polylineId: const PolylineId('restaurant_client'),
                    points: _restaurantClientRoute.length >= 2
                        ? _restaurantClientRoute
                        : [restaurantLocation, clientLocation],
                    color: AppThemeArabic.courierPrimary,
                    width: 5,
                    startCap: Cap.roundCap,
                    endCap: Cap.roundCap,
                    jointType: JointType.round,
                  ),
              };

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatUnifiedOrderCode(
                            orderNumber: data['orderNumber'],
                            orderId: data['orderId'],
                            docId: widget.orderId,
                          ),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppThemeArabic.courierPrimary,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'العميل: ${data['clientName'] ?? 'غير متوفر'}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Tajawal'),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color:
                                OrderStatusPalette.backgroundForStatus(status),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'الحالة: ${OrderStatusPalette.displayText(status)}',
                            style: TextStyle(
                              color: OrderStatusPalette.colorForStatus(status),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (restaurantLocation != null ||
                            clientLocation != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: SizedBox(
                              height: 280,
                              child: GoogleMap(
                                initialCameraPosition: CameraPosition(
                                  target: restaurantLocation ?? clientLocation!,
                                  zoom: 12.5,
                                ),
                                onMapCreated: (controller) {
                                  _orderMapController = controller;
                                  Future.delayed(
                                    const Duration(milliseconds: 300),
                                    () => _fitOrderMapBounds(
                                      driverLocation: driverLocation,
                                      restaurantLocation: restaurantLocation,
                                      clientLocation: clientLocation,
                                    ),
                                  );
                                },
                                markers: markers,
                                polylines: polylines,
                                zoomControlsEnabled: true,
                                myLocationEnabled: true,
                                myLocationButtonEnabled: true,
                                compassEnabled: true,
                                rotateGesturesEnabled: true,
                                tiltGesturesEnabled: true,
                                mapToolbarEnabled: false,
                              ),
                            ),
                          )
                        else
                          const Text('لا توجد بيانات موقع كافية لعرض الخريطة'),
                        const SizedBox(height: 12),
                        if (restaurantLocation != null ||
                            clientLocation != null)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppThemeArabic.courierPrimary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.storefront_rounded, size: 16),
                                    SizedBox(width: 6),
                                    Text('المطعم'),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppThemeArabic.courierAccent
                                      .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.person_rounded, size: 16),
                                    SizedBox(width: 6),
                                    Text('العميل'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        if (restaurantLocation != null ||
                            clientLocation != null)
                          const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (driverToRestaurantKm != null)
                              Chip(
                                label: Text(
                                  'يبعد المطعم عنك: ${courierFormatDistance(driverToRestaurantKm)}',
                                ),
                              ),
                            if (restaurantToClientKm != null)
                              Chip(
                                label: Text(
                                  'يبعد العميل عن المطعم: ${courierFormatDistance(restaurantToClientKm)}',
                                ),
                              ),
                            Chip(
                                label: Text(
                                    'رسومك: ${courierFormatMoney(deliveryFee)} ج.س')),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isOfferForMe) ...[
                    ElevatedButton.icon(
                      onPressed: _acceptOrder,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('قبول العرض وبدء الرحلة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppThemeArabic.courierAccent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _rejectOffer,
                      icon: const Icon(Icons.close),
                      label: const Text('رفض العرض'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ] else if ((data['assignedDriverId'] ?? '').toString() ==
                      widget.driverId) ...[
                    ElevatedButton.icon(
                      onPressed: _openProfessionalFlow,
                      icon: const Icon(Icons.navigation_outlined),
                      label: const Text('فتح شاشة التنفيذ الاحترافية'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppThemeArabic.courierPrimary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ] else
                    const Center(
                      child: Text('هذا الطلب تم استلامه بواسطة مندوب آخر.'),
                    ),
                  const SizedBox(height: 14),
                  if (!isFinished && clientId.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () async {
                        final doc = await FirebaseFirestore.instance
                            .collection('drivers')
                            .doc(widget.driverId)
                            .get();
                        final driverName = doc.data()?['name'] ?? 'مندوب';
                        final chatId =
                            _generateChatId(widget.driverId, clientId);
                        if (!mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              currentUserId: widget.driverId,
                              otherUserId: clientId,
                              currentUserRole: 'driver',
                              chatId: chatId,
                              currentUserName: driverName,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('الدردشة مع العميل'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppThemeArabic.courierAccent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                ],
              );
            }),
    );
  }
}
