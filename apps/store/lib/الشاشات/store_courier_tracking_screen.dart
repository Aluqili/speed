import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

class StoreCourierTrackingScreen extends StatefulWidget {
  final String orderId;

  const StoreCourierTrackingScreen({super.key, required this.orderId});

  @override
  State<StoreCourierTrackingScreen> createState() =>
      _StoreCourierTrackingScreenState();
}

class _StoreCourierTrackingScreenState
    extends State<StoreCourierTrackingScreen> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _orderSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _driverSubscription;
  GoogleMapController? _mapController;
  LatLng? _storeLocation;
  LatLng? _driverLocation;
  String _driverName = 'المندوب';
  String _status = '';
  String? _listeningDriverId;
  String? _loadedRestaurantId;

  @override
  void initState() {
    super.initState();
    _listenToOrder();
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    _driverSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  LatLng? _readLocation(dynamic value) {
    if (value is GeoPoint) return LatLng(value.latitude, value.longitude);
    if (value is Map && value['lat'] is num && value['lng'] is num) {
      return LatLng(
          (value['lat'] as num).toDouble(), (value['lng'] as num).toDouble());
    }
    return null;
  }

  bool _isTrackingFinished(String status) {
    return {
      'delivered',
      'completed',
      'partially_completed',
      'delivery_failed',
      'failed',
      'deferred',
      'returned',
      'cancelled',
      'store_rejected',
      'rejected_by_store',
      'تم التوصيل',
      'ملغي',
    }.contains(status.trim());
  }

  void _listenToOrder() {
    _orderSubscription = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .snapshots()
        .listen((snapshot) {
      final data = snapshot.data();
      if (data == null) return;
      final driverId = (data['assignedDriverId'] ?? '').toString().trim();
      final status = (data['orderStatus'] ?? data['status'] ?? '').toString();
      final trackingFinished = _isTrackingFinished(status);
      setState(() {
        _status = status;
        _storeLocation = _readLocation(data['restaurantLocation']) ??
            _readLocation(data['pickupLocation']) ??
            _readLocation(data['restaurantGeoPoint']) ??
            _storeLocation;
        _driverLocation = trackingFinished
            ? null
            : (_readLocation(data['driverLocation']) ??
                _readLocation(data['driverCurrentLocation']) ??
                _driverLocation);
      });
      final restaurantId = (data['restaurantId'] ?? '').toString().trim();
      if (_storeLocation == null &&
          restaurantId.isNotEmpty &&
          restaurantId != _loadedRestaurantId) {
        _loadStoreLocation(restaurantId);
      }
      if (trackingFinished) {
        _driverSubscription?.cancel();
        _driverSubscription = null;
        _listeningDriverId = null;
      } else if (driverId.isNotEmpty && driverId != _listeningDriverId) {
        _listenToDriver(driverId);
      }
      _focusMap();
    });
  }

  Future<void> _loadStoreLocation(String restaurantId) async {
    _loadedRestaurantId = restaurantId;
    final snapshot = await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(restaurantId)
        .get();
    final data = snapshot.data();
    if (!mounted || data == null || _storeLocation != null) return;
    setState(() {
      _storeLocation = _readLocation(data['location']) ??
          _readLocation(data['defaultLocation']) ??
          _storeLocation;
    });
    _focusMap();
  }

  void _listenToDriver(String driverId) {
    _listeningDriverId = driverId;
    _driverSubscription?.cancel();
    _driverSubscription = FirebaseFirestore.instance
        .collection('drivers')
        .doc(driverId)
        .snapshots()
        .listen((snapshot) {
      final data = snapshot.data();
      if (data == null) return;
      setState(() {
        _driverName = (data['name'] ?? 'المندوب').toString();
        _driverLocation = _readLocation(data['currentLocation']) ??
            _readLocation(data['location']) ??
            _driverLocation;
      });
      _focusMap();
    });
  }

  void _focusMap() {
    final map = _mapController;
    final points =
        [_storeLocation, _driverLocation].whereType<LatLng>().toList();
    if (map == null || points.isEmpty) return;
    if (points.length == 1) {
      map.animateCamera(CameraUpdate.newLatLngZoom(points.first, 15));
      return;
    }
    final minLat =
        points.map((point) => point.latitude).reduce((a, b) => a < b ? a : b);
    final maxLat =
        points.map((point) => point.latitude).reduce((a, b) => a > b ? a : b);
    final minLng =
        points.map((point) => point.longitude).reduce((a, b) => a < b ? a : b);
    final maxLng =
        points.map((point) => point.longitude).reduce((a, b) => a > b ? a : b);
    map.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      ),
      56,
    ));
  }

  String get _statusLabel {
    switch (_status) {
      case 'courier_assigned':
        return 'المندوب في طريقه إلى المتجر';
      case 'pickup_ready':
      case 'جاهز للتوصيل':
        return 'الطلب جاهز للاستلام';
      case 'picked_up':
      case 'قيد التوصيل':
        return 'المندوب في طريقه إلى العميل';
      case 'delivered':
      case 'completed':
      case 'تم التوصيل':
        return 'تم تسليم الطلب وانتهى التتبع';
      default:
        return _isTrackingFinished(_status)
            ? 'انتهى الطلب وتم إيقاف التتبع'
            : 'يتم تحديث موقع المندوب مباشرة';
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{
      if (_storeLocation != null)
        Marker(
          markerId: const MarkerId('store'),
          position: _storeLocation!,
          infoWindow: const InfoWindow(title: 'المتجر'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      if (_driverLocation != null)
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverLocation!,
          infoWindow: InfoWindow(title: _driverName),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ),
    };
    final target = _driverLocation ?? _storeLocation;

    return Scaffold(
      appBar: AppBar(title: const Text('تتبع المندوب')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppThemeArabic.storePrimary.withValues(alpha: 0.08),
            child: Row(
              children: [
                const Icon(Icons.delivery_dining_rounded,
                    color: AppThemeArabic.storePrimary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_driverName,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(_statusLabel,
                          style: const TextStyle(
                              color: AppThemeArabic.storeTextSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: target == null
                ? const Center(child: Text('بانتظار تحديث موقع المندوب.'))
                : GoogleMap(
                    initialCameraPosition:
                        CameraPosition(target: target, zoom: 14),
                    markers: markers,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    onMapCreated: (controller) {
                      _mapController = controller;
                      _focusMap();
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
