import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SmartLocationTracker {
  final String driverId;
  final String orderId;
  final LatLng clientLocation;

  double? _lastLat;
  double? _lastLng;
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<DocumentSnapshot>? _orderListener;
  bool _notifiedClient = false;

  SmartLocationTracker({
    required this.driverId,
    required this.orderId,
    required this.clientLocation,
  });

  Future<void> startTracking() async {
    await _requestLocationPermission();

    // راقب حالة الطلب أولاً
    _orderListener = FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;

      final status = snapshot.data()?['status'];
      if (status == 'قيد التوصيل') {
        _startLocationStream(); // يبدأ التتبع
      } else if (status == 'تم التوصيل') {
        stopTracking(); // يوقف التتبع تلقائيًا
      }
    });
  }

  void _startLocationStream() {
    if (_positionStream != null) return; // لا تبدأ مرتين

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      _maybeUpdateLocation(position);
    });
  }

  void _maybeUpdateLocation(Position pos) async {
    final lat = pos.latitude;
    final lng = pos.longitude;

    if (_lastLat != null && _lastLng != null) {
      final distance = Geolocator.distanceBetween(_lastLat!, _lastLng!, lat, lng);
      if (distance < 50) return; // لا تحدّث إلا إذا تحرك أكثر من 50 متر
    }

    // تحديث Firestore بموقع المندوب
    await FirebaseFirestore.instance.collection('drivers').doc(driverId).update({
      'location': GeoPoint(lat, lng),
      'lastUpdated': Timestamp.now(),
    });

    _lastLat = lat;
    _lastLng = lng;

    // التحقق من الاقتراب من العميل (مثلاً لإرسال إشعار لاحقًا)
    if (!_notifiedClient) {
      final distanceToClient = Geolocator.distanceBetween(
        lat,
        lng,
        clientLocation.latitude,
        clientLocation.longitude,
      );

      if (distanceToClient < 100) {
        _notifiedClient = true;
        _notifyClientArrived();
      }
    }
  }

  void _notifyClientArrived() {
    // هنا يمكن إرسال إشعار سحابي إلى العميل أو طباعة/تنبيه
    print("🚀 المندوب اقترب من العميل (أقل من 100 متر)");
  }

  Future<void> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  void stopTracking() {
    _positionStream?.cancel();
    _orderListener?.cancel();
    _positionStream = null;
    _orderListener = null;
  }
}
