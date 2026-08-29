import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'dart:math';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'package:speedstar_core/speedstar_core.dart'
    show formatUnifiedOrderCode, OrderStatusPalette, SpeedstarBusinessTypeConfig;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../helpers/courier_runtime_helpers.dart';

import 'courier_batch_trip_screen.dart';
import 'courier_client_contact_card.dart';
import 'courier_go_to_restaurant_screen.dart';
import 'courier_go_to_client_screen.dart';
import 'courier_confirm_delivery_screen.dart';
import 'courier_ui.dart';

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
  bool _reloadingOrder = false;
  String? _offerActionInProgress;
  bool _reportingIssue = false;
  double deliveryFee = 0;
  CourierMarkerIcons? _markerIcons;
  List<LatLng> _driverRestaurantRoute = const [];
  List<LatLng> _restaurantClientRoute = const [];
  double? _driverRestaurantRoadKm;
  double? _restaurantClientRoadKm;
  String _loadedRouteKey = '';
  bool _fetchingRoutes = false;
  bool _detailsExpanded = false;
  GoogleMapController? _orderMapController;

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _distanceText(double? km) {
    final value = km ?? 0;
    if (value <= 0) return 'غير متاح';
    if (value < 1) return '${(value * 1000).round()} م';
    return '${value.toStringAsFixed(1)} كم';
  }

  String _etaText(Map<String, dynamic> data) {
    final eta = _toInt(data['estimatedDeliveryMinutes']);
    if (eta > 0) return '$eta دقيقة';
    final route = _toInt(data['routeDurationMinutes']);
    if (route > 0) return '$route دقيقة';
    return 'غير متاح';
  }

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

  bool _isOfferForDriver(Map<String, dynamic> data) {
    final offeredDriverId = (data['offeredDriverId'] ?? '').toString();
    final offerDriverIds =
        (data['offerDriverIds'] as List?)?.map((id) => id.toString()).toSet() ??
            <String>{};
    return offeredDriverId == widget.driverId ||
        offerDriverIds.contains(widget.driverId);
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
    final orderRef =
        FirebaseFirestore.instance.collection('orders').doc(widget.orderId);

    DocumentSnapshot<Map<String, dynamic>> docSnapshot;
    try {
      docSnapshot = await orderRef.get(
        const GetOptions(source: Source.server),
      );
    } catch (_) {
      docSnapshot = await orderRef.get();
    }

    if (docSnapshot.exists) {
      final data = docSnapshot.data()!;
      final assignedDriverId =
          (data['assignedDriverId'] ?? '').toString().trim();
      final status = _getOrderStatus(data);
      final selfDriverId = widget.driverId.trim();

      final belongsToAnotherAssigned =
          assignedDriverId.isNotEmpty && assignedDriverId != selfDriverId;
      final belongsToAnotherOffer =
          status == 'courier_offer_pending' && !_isOfferForDriver(data);

      if (belongsToAnotherAssigned || belongsToAnotherOffer) {
        // Recheck from server once before blocking, because local cache can be stale
        // right after accepting the offer.
        try {
          final fresh =
              await orderRef.get(const GetOptions(source: Source.server));
          if (fresh.exists) {
            final freshData = fresh.data()!;
            final freshAssigned =
                (freshData['assignedDriverId'] ?? '').toString().trim();
            final freshStatus = _getOrderStatus(freshData);
            final stillAnotherAssigned =
                freshAssigned.isNotEmpty && freshAssigned != selfDriverId;
            final stillAnotherOffer = freshStatus == 'courier_offer_pending' &&
                !_isOfferForDriver(freshData);
            if (!(stillAnotherAssigned || stillAnotherOffer)) {
              setState(() {
                orderData = freshData;
              });
              return;
            }
          }
        } catch (_) {}

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

  Future<void> _refreshOrderData() async {
    if (_reloadingOrder) return;
    setState(() => _reloadingOrder = true);
    try {
      await _loadOrderData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث حالة الطلب')),
      );
    } finally {
      if (mounted) {
        setState(() => _reloadingOrder = false);
      }
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
      final result = await courierInvokeCallable(
        'estimateRoute',
        {
          'origin': {'lat': origin.latitude, 'lng': origin.longitude},
          'destination': {
            'lat': destination.latitude,
            'lng': destination.longitude,
          },
        },
        timeout: const Duration(seconds: 5),
        maxAttempts: 2,
      );
      return Map<String, dynamic>.from(result as Map);
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
    if (_offerActionInProgress != null) return;

    final status = _getOrderStatus(orderData!);
    if (status != 'courier_offer_pending' || !_isOfferForDriver(orderData!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذا العرض غير متاح لك الآن')),
      );
      return;
    }

    setState(() => _offerActionInProgress = 'accept');
    try {
      await courierInvokeCallable(
        'courierRespondToOffer',
        {
          'orderId': widget.orderId,
          'driverId': widget.driverId,
          'decision': 'accept',
        },
        timeout: const Duration(seconds: 12),
        maxAttempts: 2,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            courierFriendlyFunctionsError(
              e,
              fallback: 'تعذر قبول الطلب الآن. حاول مرة أخرى.',
            ),
          ),
        ),
      );
      return;
    } finally {
      if (mounted) {
        setState(() => _offerActionInProgress = null);
      }
    }

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

  LatLng? _pickupPointForOrder(Map<String, dynamic> data) {
    final source = (data['orderSource'] ?? '').toString().trim();
    if (source == 'client_parcel_delivery') {
      return _resolvePoint(
        data,
        rawKey: 'pickupLocation',
        latKey: 'pickupLat',
        lngKey: 'pickupLng',
      );
    }
    return _resolvePoint(
      data,
      rawKey: 'restaurantLocation',
      latKey: 'restaurantLat',
      lngKey: 'restaurantLng',
    );
  }

  LatLng? _dropoffPointForOrder(Map<String, dynamic> data) {
    return _resolvePoint(
      data,
      rawKey: 'clientLocation',
      latKey: 'clientLat',
      lngKey: 'clientLng',
    );
  }

  String _pickupNameForOrder(Map<String, dynamic> data) {
    final source = (data['orderSource'] ?? '').toString().trim();
    if (source == 'client_parcel_delivery') return 'نقطة الاستلام';
    return (data['restaurantName'] ?? 'نقطة الاستلام').toString();
  }

  String _serviceLabelForOrder(Map<String, dynamic> data) {
    final source = (data['orderSource'] ?? '').toString().trim();
    if (source == 'client_parcel_delivery') return 'وصّلها من عميل';
    if (source == 'store_direct_delivery') return 'وصّلها من متجر';
    if (source == 'store_batch_delivery') return 'رحلة متجر مجمعة';
    return 'طلب توصيل';
  }

  List<Map<String, dynamic>> _batchStops(Map<String, dynamic> data) {
    return ((data['batchStops'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList()
      ..sort((a, b) {
        final sequenceA = (a['sequence'] as num?)?.toInt() ?? 0;
        final sequenceB = (b['sequence'] as num?)?.toInt() ?? 0;
        return sequenceA.compareTo(sequenceB);
      });
  }

  LatLng? _batchStopPoint(Map<String, dynamic> stop) {
    final lat = courierToDouble(stop['clientLat'] ?? stop['lat']);
    final lng = courierToDouble(stop['clientLng'] ?? stop['lng']);
    if (lat == 0 || lng == 0) return null;
    return LatLng(lat, lng);
  }

  void _fitBatchMapBounds(List<LatLng> points) {
    final controller = _orderMapController;
    if (controller == null || points.isEmpty) return;
    if (points.length == 1) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(points.first, 15));
      return;
    }
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points.skip(1)) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }
    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        64,
      ),
    );
  }

  Widget _buildBatchOfferPreviewMap(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> stops,
  ) {
    final pickupLocation = _pickupPointForOrder(data);
    final stopPoints = stops.map(_batchStopPoint).whereType<LatLng>().toList();
    final points = <LatLng>[
      if (pickupLocation != null) pickupLocation,
      ...stopPoints,
    ];
    if (points.isEmpty) {
      return const Text('لا توجد بيانات موقع كافية لعرض خط سير الرحلة.');
    }

    final markers = <Marker>{
      if (pickupLocation != null)
        Marker(
          markerId: const MarkerId('batch-pickup'),
          position: pickupLocation,
          icon: _markerIcons?.restaurant ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: (data['restaurantName'] ?? 'نقطة الاستلام').toString(),
          ),
        ),
      for (var i = 0; i < stops.length; i += 1)
        if (_batchStopPoint(stops[i]) != null)
          Marker(
            markerId: MarkerId('batch-stop-$i'),
            position: _batchStopPoint(stops[i])!,
            icon: _markerIcons?.client ??
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            infoWindow: InfoWindow(
              title: '${i + 1}. ${stops[i]['clientName'] ?? 'عميل'}',
              snippet: (stops[i]['zoneName'] ?? '').toString(),
            ),
          ),
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 300,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: points.first, zoom: 12),
          onMapCreated: (controller) {
            _orderMapController = controller;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _fitBatchMapBounds(points),
            );
          },
          markers: markers,
          polylines: points.length < 2
              ? const <Polyline>{}
              : {
                  Polyline(
                    polylineId: const PolylineId('batch-preview-route'),
                    points: points,
                    color: AppThemeArabic.courierPrimary,
                    width: 5,
                    startCap: Cap.roundCap,
                    endCap: Cap.roundCap,
                    jointType: JointType.round,
                  ),
                },
          zoomControlsEnabled: true,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          compassEnabled: true,
          mapToolbarEnabled: false,
        ),
      ),
    );
  }

  Widget _buildBatchStopsPreview(List<Map<String, dynamic>> stops) {
    if (stops.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'العملاء في خط السير',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: AppThemeArabic.courierTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        ...stops.asMap().entries.map((entry) {
          final stop = entry.value;
          final name = (stop['clientName'] ?? 'عميل').toString();
          final zone = (stop['zoneName'] ?? '').toString();
          final phone = (stop['clientPhone'] ?? '').toString();
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppThemeArabic.courierPrimary
                      .withValues(alpha: 0.12),
                  child: Text(
                    '${entry.key + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppThemeArabic.courierPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    [
                      name,
                      if (zone.trim().isNotEmpty) zone,
                      if (phone.trim().isNotEmpty) phone,
                    ].join(' - '),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Future<void> _openProfessionalFlow() async {
    if (orderData == null || !mounted) return;
    final status = _getOrderStatus(orderData!);
    final isBatchDelivery =
        (orderData!['orderSource'] ?? '').toString() == 'store_batch_delivery';
    final clientLoc = _dropoffPointForOrder(orderData!);

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
      if (isBatchDelivery) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => CourierBatchTripScreen(
              orderId: widget.orderId,
              driverId: widget.driverId,
            ),
          ),
        );
        return;
      }

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
    if (_offerActionInProgress != null) return;
    setState(() => _offerActionInProgress = 'reject');
    try {
      await courierInvokeCallable(
        'courierRespondToOffer',
        {
          'orderId': widget.orderId,
          'driverId': widget.driverId,
          'decision': 'reject',
        },
        timeout: const Duration(seconds: 10),
        maxAttempts: 2,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            courierFriendlyFunctionsError(
              e,
              fallback: 'تعذر رفض العرض الآن. حاول مرة أخرى.',
            ),
          ),
        ),
      );
      return;
    } finally {
      if (mounted) {
        setState(() => _offerActionInProgress = null);
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم رفض العرض وسيتم إرساله لمندوب آخر')),
    );
    Navigator.pop(context);
  }

  Future<void> _reportOrderIssue() async {
    if (_reportingIssue) return;

    final storeClosedLabel = orderData == null
        ? 'المتجر مغلق'
        : _businessConfigForOrder(orderData!).closedLabel;
    final reasons = {
      'client_not_responding': 'العميل لا يرد',
      'incorrect_address': 'العنوان غير صحيح',
      'store_closed': storeClosedLabel,
      'cannot_complete_delivery': 'تعذر إتمام التوصيل',
      'other': 'مشكلة أخرى',
    };
    var selectedReason = reasons.keys.first;
    final noteController = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('الإبلاغ عن مشكلة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedReason,
                decoration: const InputDecoration(labelText: 'سبب المشكلة'),
                items: reasons.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedReason = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'ملاحظة إضافية (اختياري)',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'reason': selectedReason,
                'note': noteController.text.trim(),
              }),
              child: const Text('إرسال البلاغ'),
            ),
          ],
        ),
      ),
    );
    noteController.dispose();
    if (result == null || !mounted) return;

    setState(() => _reportingIssue = true);
    try {
      await courierInvokeCallable(
        'courierReportOrderIssue',
        {
          'orderId': widget.orderId,
          'driverId': widget.driverId,
          ...result,
        },
        timeout: const Duration(seconds: 12),
        maxAttempts: 2,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال البلاغ إلى فريق العمليات')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            courierFriendlyFunctionsError(
              error,
              fallback: 'تعذر إرسال البلاغ الآن. حاول مرة أخرى.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _reportingIssue = false);
    }
  }

  bool _isOrderFinished(String status) {
    final normalized = status.trim().toLowerCase();
    return normalized == 'delivered' ||
        normalized == 'cancelled' ||
        normalized == 'store_rejected' ||
        status.trim() == 'تم التوصيل' ||
        status.trim() == 'ملغي';
  }

  SpeedstarBusinessTypeConfig _businessConfigForOrder(Map<String, dynamic> data) {
    return SpeedstarBusinessTypeConfig.resolve(
      data['businessType'] ?? data['storeType'],
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = orderData;
    return Scaffold(
      appBar: buildCourierAppBar(
        'تفاصيل الطلب',
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _reloadingOrder ? null : _refreshOrderData,
            icon: _reloadingOrder
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      backgroundColor: Colors.transparent,
      body: CourierPageBackground(
        child: data == null
            ? const Center(child: CircularProgressIndicator())
            : Builder(builder: (context) {
                final status = _getOrderStatus(data);
                final accepting = _offerActionInProgress == 'accept';
                final rejecting = _offerActionInProgress == 'reject';
                final offerBusy = _offerActionInProgress != null;
                final isFinished = _isOrderFinished(status);
                final isOfferForMe = status == 'courier_offer_pending' &&
                    _isOfferForDriver(data);
                final isAssignedToMe =
                    (data['assignedDriverId'] ?? '').toString() ==
                        widget.driverId;
                final businessConfig = _businessConfigForOrder(data);
                final isDirectDelivery =
                    data['orderSource'] == 'store_direct_delivery';
                final isBatchDelivery =
                    data['orderSource'] == 'store_batch_delivery';
                final isParcelDelivery =
                    data['orderSource'] == 'client_parcel_delivery';
                final serviceLabel = _serviceLabelForOrder(data);
                final pickupLabel = isDirectDelivery || isParcelDelivery
                    ? 'نقطة الاستلام'
                    : businessConfig.placeLabel;
                final executionLabel =
                    status == 'picked_up' || status == 'قيد التوصيل'
                        ? 'الذهاب إلى العميل'
                        : status == 'arrived_to_client' ||
                                status == 'وصل إلى العميل'
                            ? 'تأكيد تسليم الطلب'
                            : 'الذهاب إلى $pickupLabel';
                final courierIssue = data['courierIssue'];
                final issueResolved = courierIssue is Map &&
                    (courierIssue['status'] ?? '').toString() == 'resolved';
                final issueResolutionNote =
                    (data['courierIssueResolutionNote'] ?? '')
                        .toString()
                        .trim();

                final restaurantLocation = _pickupPointForOrder(data);
                final clientLocation = _dropoffPointForOrder(data);
                final driverLocation = _resolvePoint(
                  data,
                  rawKey: 'driverLocation',
                  latKey: 'driverLat',
                  lngKey: 'driverLng',
                );

                final restaurantToClientKm = _restaurantClientRoadKm ??
                    (restaurantLocation != null && clientLocation != null
                        ? courierHaversineKm(restaurantLocation, clientLocation)
                        : null);

                final driverToRestaurantKm = _driverRestaurantRoadKm ??
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
                  pickupLabel: pickupLabel,
                );

                final total = (data['totalWithDelivery'] ?? data['total'] ?? 0)
                    .toString();
                final itemsCount = (data['items'] as List?)?.length ?? 0;
                final batchStops =
                    isBatchDelivery ? _batchStops(data) : const <Map<String, dynamic>>[];
                final restaurantName =
                    _pickupNameForOrder(data);
                final packageDescription =
                    (data['packageDescription'] ?? data['itemDescription'] ?? '')
                        .toString()
                        .trim();
                final courierEarnings =
                    (data['deliveryFeeForDriver'] ?? data['driverShare'] ?? 0)
                        .toString();
                final routeDistanceKm = _toDouble(data['routeDistanceKm']) > 0
                    ? _toDouble(data['routeDistanceKm'])
                    : restaurantToClientKm;

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
                            serviceLabel,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppThemeArabic.courierAccent,
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
                              color: OrderStatusPalette.backgroundForStatus(
                                  status),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'الحالة: ${OrderStatusPalette.displayText(status)}',
                              style: TextStyle(
                                color:
                                    OrderStatusPalette.colorForStatus(status),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7FAF8),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: const Color(0xFFD7E4DD)),
                            ),
                            child: Theme(
                              data: Theme.of(context)
                                  .copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                initiallyExpanded: _detailsExpanded,
                                onExpansionChanged: (value) => setState(
                                    () => _detailsExpanded = value),
                                tilePadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 0),
                                childrenPadding: const EdgeInsets.fromLTRB(
                                    12, 0, 12, 12),
                                title: const Text(
                                  'تفاصيل الطلب',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: AppThemeArabic.courierTextPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  _detailsExpanded
                                      ? 'اضغط للإخفاء'
                                      : 'اضغط لعرض الأصناف والمبالغ',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        AppThemeArabic.courierTextSecondary,
                                  ),
                                ),
                                children: [
                                  _OrderInfoRow(
                                    label: pickupLabel,
                                    value: restaurantName,
                                  ),
                                  const SizedBox(height: 8),
                                  _OrderInfoRow(
                                    label: isDirectDelivery ||
                                            isParcelDelivery
                                        ? 'أجرك المتوقع'
                                        : 'الإجمالي',
                                    value:
                                        '${isDirectDelivery || isParcelDelivery ? courierEarnings : total} ج.س',
                                  ),
                                  const SizedBox(height: 8),
                                  _OrderInfoRow(
                                    label: isDirectDelivery ||
                                            isParcelDelivery
                                        ? 'الإرسالية'
                                        : 'العناصر',
                                    value: isDirectDelivery ||
                                            isParcelDelivery
                                        ? (packageDescription.isEmpty
                                            ? serviceLabel
                                            : packageDescription)
                                        : '$itemsCount',
                                  ),
                                  const SizedBox(height: 8),
                                  _OrderInfoRow(
                                    label: 'المسافة',
                                    value: _distanceText(routeDistanceKm),
                                  ),
                                  const SizedBox(height: 8),
                                  _OrderInfoRow(
                                    label: 'الزمن',
                                    value: _etaText(data),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (isBatchDelivery) ...[
                            _buildBatchOfferPreviewMap(data, batchStops),
                            const SizedBox(height: 12),
                            _buildBatchStopsPreview(batchStops),
                          ] else if (restaurantLocation != null ||
                              clientLocation != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: SizedBox(
                                height: 280,
                                child: GoogleMap(
                                  initialCameraPosition: CameraPosition(
                                    target:
                                        restaurantLocation ?? clientLocation!,
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
                            const Text(
                                'لا توجد بيانات موقع كافية لعرض الخريطة'),
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
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.storefront_rounded,
                                          size: 16),
                                      const SizedBox(width: 6),
                                      Text(pickupLabel),
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
                          Row(
                            children: [
                              Expanded(
                                child: CourierCompactMetric(
                                  icon: Icons.my_location_rounded,
                                  label: '$pickupLabel عنك',
                                  value: driverToRestaurantKm == null
                                      ? 'غير متاح'
                                      : courierFormatDistance(
                                          driverToRestaurantKm),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: CourierCompactMetric(
                                  icon: Icons.person_pin_circle_outlined,
                                  label: 'العميل عن $pickupLabel',
                                  value: restaurantToClientKm == null
                                      ? 'غير متاح'
                                      : courierFormatDistance(
                                          restaurantToClientKm),
                                  tone: AppThemeArabic.courierAccent,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: CourierCompactMetric(
                                  icon: Icons.payments_outlined,
                                  label: 'رسومك',
                                  value:
                                      '${courierFormatMoney(deliveryFee)} ج.س',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (isAssignedToMe) ...[
                      CourierClientContactCard(
                        orderData: data,
                        orderId: widget.orderId,
                        driverId: widget.driverId,
                        showPhone: true,
                      ),
                      const SizedBox(height: 16),
                      if (issueResolved) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.green.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.task_alt_rounded,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  issueResolutionNote.isNotEmpty
                                      ? 'تمت معالجة بلاغك: $issueResolutionNote'
                                      : 'تمت معالجة بلاغك من فريق العمليات.',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Tajawal',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                    if (isOfferForMe) ...[
                      ElevatedButton.icon(
                        onPressed: offerBusy ? null : _acceptOrder,
                        icon: accepting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(
                          accepting
                              ? 'جاري قبول العرض...'
                              : 'قبول العرض وبدء الرحلة',
                        ),
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
                        onPressed: offerBusy ? null : _rejectOffer,
                        icon: rejecting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.close),
                        label:
                            Text(rejecting ? 'جاري رفض العرض...' : 'رفض العرض'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ] else if (isAssignedToMe) ...[
                      ElevatedButton.icon(
                        onPressed: _openProfessionalFlow,
                        icon: const Icon(Icons.navigation_outlined),
                        label: Text(executionLabel),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppThemeArabic.courierPrimary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _reportingIssue ? null : _reportOrderIssue,
                        icon: _reportingIssue
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.report_problem_outlined),
                        label: Text(
                          _reportingIssue
                              ? 'جاري إرسال البلاغ...'
                              : 'الإبلاغ عن مشكلة',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
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
                    if (!isFinished) const SizedBox(height: 14),
                  ],
                );
              }),
      ),
    );
  }
}

class _OrderInfoRow extends StatelessWidget {
  const _OrderInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7A6857),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
