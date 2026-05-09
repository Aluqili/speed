import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_storage/get_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'package:speedstar_core/speedstar_core.dart'
    show formatUnifiedOrderCode, OrderStatusPalette;
import 'courier_go_to_restaurant_screen.dart';

class CourierIncomingOrderOverlay extends StatefulWidget {
  final String driverId;
  final String orderId;
  final Map<String, dynamic> orderData;
  final LatLng driverLocation;
  final LatLng restaurantLocation;
  final LatLng clientLocation;
  final String? currentStage;

  const CourierIncomingOrderOverlay({
    super.key,
    required this.driverId,
    required this.orderId,
    required this.orderData,
    required this.driverLocation,
    required this.restaurantLocation,
    required this.clientLocation,
    this.currentStage,
  });

  @override
  State<CourierIncomingOrderOverlay> createState() =>
      _CourierIncomingOrderOverlayState();
}

class _CourierIncomingOrderOverlayState
    extends State<CourierIncomingOrderOverlay> {
  int _remainingSeconds = 50;
  Timer? _countdownTimer;
  StreamSubscription<RemoteMessage>? _messageSub;
  Set<Polyline> _polylines = {};
  double _distanceToRestaurant = 0.0;
  double _distanceToClient = 0.0;
  int _driverFee = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();
  GoogleMapController? _mapController;
  bool _isMapExpanded = false;

  int _calculateDriverFee(double routeKm) {
    if (routeKm < 2) return 2000;
    if (routeKm < 5) return 2500;
    if (routeKm < 10) return 3000;
    if (routeKm < 14) return 3500;
    return routeKm.ceil() * 250;
  }

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _drawRoute();
    _calculateDistancesAndFee();
    _setupNotificationListener();
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    _audioPlayer.setVolume(1.0);
    _audioPlayer.play(AssetSource('sounds/notification.mp3'));
    // تحريك الكاميرا تلقائياً بعد رسم المسار
    Future.delayed(const Duration(seconds: 1), _moveCameraToBounds);
  }

  Future<void> _moveCameraToBounds() async {
    if (_mapController == null) return;
    final points = [
      widget.driverLocation,
      widget.restaurantLocation,
      widget.clientLocation,
    ];
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

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    await _mapController!
        .animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  void _setupNotificationListener() {
    _messageSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data['type'] == 'order_offer' &&
          message.data['orderId'] == widget.orderId) {
        if (mounted) setState(() {});
      }
    });
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        await _handleTimeout();
      }
    });
  }

  Future<void> _handleTimeout() async {
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .update({
      'driverResponse': 'timeout',
    });
    _audioPlayer.stop();
    if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _acceptOrder() async {
    // تم حذف شرط readyByRestaurant، يمكن قبول الطلب مباشرة
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .update({
      'driverResponse': 'accepted',
      'driverResponded': true,
      'assignedDriverId': widget.driverId,
      'orderStatus': 'courier_assigned',
      'status': 'courier_assigned',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _countdownTimer?.cancel();
    _audioPlayer.stop();

    final box = GetStorage();
    box.write('current_order', {
      'orderId': widget.orderId,
      'stage': 'going_to_restaurant',
      'driverLocation': {
        'lat': widget.driverLocation.latitude,
        'lng': widget.driverLocation.longitude,
      },
      'restaurantLocation': {
        'lat': widget.restaurantLocation.latitude,
        'lng': widget.restaurantLocation.longitude,
      },
      'clientLocation': {
        'lat': widget.clientLocation.latitude,
        'lng': widget.clientLocation.longitude,
      },
      'orderData': widget.orderData,
      'assignedDriverId': widget.driverId,
    });

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

  Future<void> _rejectOrder() async {
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .update({
      'driverResponse': 'rejected',
    });
    _audioPlayer.stop();
    if (mounted) Navigator.of(context).pop();
  }

  Future<Map<String, dynamic>?> _estimateRoute(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'me-central1')
          .httpsCallable('estimateRoute');
      final result = await callable.call({
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

  Future<void> _drawRoute() async {
    final driverToRestaurant = await _estimateRoute(
      widget.driverLocation,
      widget.restaurantLocation,
    );
    final restaurantToClient = await _estimateRoute(
      widget.restaurantLocation,
      widget.clientLocation,
    );

    List<LatLng> routePoints(
      Map<String, dynamic>? route,
      LatLng fallbackStart,
      LatLng fallbackEnd,
    ) {
      final encoded = (route?['encodedPolyline'] ?? '').toString();
      final decoded = _decodePolyline(encoded);
      return decoded.length >= 2 ? decoded : [fallbackStart, fallbackEnd];
    }

    final toRestaurantKm = ((driverToRestaurant?['distanceKm'] ?? 0) as num?)
            ?.toDouble() ??
        0;
    final toClientKm =
        ((restaurantToClient?['distanceKm'] ?? 0) as num?)?.toDouble() ?? 0;

    if (!mounted) return;
    setState(() {
      if (toRestaurantKm > 0) _distanceToRestaurant = toRestaurantKm;
      if (toClientKm > 0) {
        _distanceToClient = toClientKm;
        _driverFee = _calculateDriverFee(toClientKm);
      }
      _polylines = {
        Polyline(
          polylineId: const PolylineId('driver_restaurant'),
          points: routePoints(
            driverToRestaurant,
            widget.driverLocation,
            widget.restaurantLocation,
          ),
          width: 7,
          color: Colors.green,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
        Polyline(
          polylineId: const PolylineId('restaurant_client'),
          points: routePoints(
            restaurantToClient,
            widget.restaurantLocation,
            widget.clientLocation,
          ),
          width: 7,
          color: Colors.blueAccent,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      };
    });
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, lat = 0, lng = 0;

    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  Future<void> _calculateDistancesAndFee() async {
    _distanceToRestaurant = Geolocator.distanceBetween(
          widget.driverLocation.latitude,
          widget.driverLocation.longitude,
          widget.restaurantLocation.latitude,
          widget.restaurantLocation.longitude,
        ) /
        1000;

    _distanceToClient = Geolocator.distanceBetween(
          widget.restaurantLocation.latitude,
          widget.restaurantLocation.longitude,
          widget.clientLocation.latitude,
          widget.clientLocation.longitude,
        ) /
        1000;

    _driverFee = _calculateDriverFee(_distanceToClient);

    setState(() {});
  }

  Widget _buildInitialOfferScreen() {
    final data = widget.orderData;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Card(
              margin: const EdgeInsets.all(16),
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Chip(
                          label: const Text(
                            'عرض جديد',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Tajawal',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          backgroundColor: OrderStatusPalette.colorForStatus(
                              'courier_offer_pending'),
                          avatar: const Icon(Icons.local_shipping,
                              color: Colors.white),
                        ),
                        const Spacer(),
                        Text(
                          '⏱ $_remainingSeconds ثانية',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: OrderStatusPalette.colorForStatus(
                                'courier_offer_pending'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'اقبل العرض للانتقال مباشرةً إلى شاشة التوجه للمطعم.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 12),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: _isMapExpanded ? 400 : 260,
                      width: double.infinity,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: GoogleMap(
                              initialCameraPosition: CameraPosition(
                                  target: widget.restaurantLocation, zoom: 13),
                              onMapCreated: (controller) {
                                _mapController = controller;
                                _moveCameraToBounds();
                              },
                              markers: {
                                Marker(
                                  markerId: const MarkerId('restaurant'),
                                  position: widget.restaurantLocation,
                                  infoWindow:
                                      const InfoWindow(title: '🍽️ المطعم'),
                                  icon: BitmapDescriptor.defaultMarkerWithHue(
                                      BitmapDescriptor.hueRed),
                                ),
                                Marker(
                                  markerId: const MarkerId('client'),
                                  position: widget.clientLocation,
                                  infoWindow:
                                      const InfoWindow(title: '🏠 العميل'),
                                  icon: BitmapDescriptor.defaultMarkerWithHue(
                                      BitmapDescriptor.hueAzure),
                                ),
                                Marker(
                                  markerId: const MarkerId('driver'),
                                  position: widget.driverLocation,
                                  infoWindow:
                                      const InfoWindow(title: '🧑‍✈️ موقعك'),
                                  icon: BitmapDescriptor.defaultMarkerWithHue(
                                      BitmapDescriptor.hueYellow),
                                ),
                              },
                              polylines: _polylines,
                              zoomControlsEnabled: true,
                              scrollGesturesEnabled: true,
                              rotateGesturesEnabled: true,
                              tiltGesturesEnabled: true,
                              myLocationEnabled: true,
                              myLocationButtonEnabled: true,
                              gestureRecognizers: {
                                Factory<OneSequenceGestureRecognizer>(
                                    () => EagerGestureRecognizer())
                              },
                            ),
                          ),
                          Positioned(
                            top: 8,
                            left: 8,
                            child: FloatingActionButton(
                              mini: true,
                              backgroundColor: Colors.white,
                              onPressed: () => setState(
                                  () => _isMapExpanded = !_isMapExpanded),
                              tooltip: _isMapExpanded
                                  ? 'تصغير الخريطة'
                                  : 'توسيع الخريطة',
                              child: Icon(
                                  _isMapExpanded
                                      ? Icons.fullscreen_exit
                                      : Icons.fullscreen,
                                  color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.store, color: Colors.deepOrange),
                        const SizedBox(width: 6),
                        const Text('المطعم: ',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(data['restaurantName'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.person_pin_circle,
                            color: Colors.blueAccent),
                        const SizedBox(width: 6),
                        const Text('العميل: ',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(data['clientName'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.directions_car, color: Colors.green),
                        const SizedBox(width: 6),
                        const Text('المسافة للمطعم: ',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('${_distanceToRestaurant.toStringAsFixed(1)} كم',
                            style: const TextStyle(color: Colors.black87)),
                        const Spacer(),
                        const Icon(Icons.navigation, color: Colors.orange),
                        const SizedBox(width: 6),
                        const Text('من المطعم للعميل: ',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('${_distanceToClient.toStringAsFixed(1)} كم',
                            style: const TextStyle(color: Colors.black87)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppThemeArabic.clientSurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '💰 رسوم التوصيل المتوقعة: $_driverFee ج.س',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppThemeArabic.clientPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      color: AppThemeArabic.clientSurface,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('تفاصيل الأصناف',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 6),
                            ...((data['items'] as List<dynamic>)
                                .map((item) => Row(
                                      children: [
                                        const Icon(Icons.fastfood,
                                            color: Colors.deepOrange, size: 18),
                                        const SizedBox(width: 6),
                                        Expanded(
                                            child: Text(
                                                '${item['name']} × ${item['quantity']} (${item['price']} ج.س)',
                                                style: const TextStyle(
                                                    fontSize: 15))),
                                      ],
                                    ))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'كود الطلب: ${formatUnifiedOrderCode(orderNumber: data['orderNumber'], orderId: data['orderId'], docId: widget.orderId)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _messageSub?.cancel();
    _mapController?.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeArabic.clientBackground,
      body: Column(
        children: [
          Expanded(
            child: _buildInitialOfferScreen(),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _rejectOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppThemeArabic.clientError,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.close),
                    label: const Text('رفض'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _acceptOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppThemeArabic.clientSuccess,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text(
                      'قبول الطلب وبدء الرحلة',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
