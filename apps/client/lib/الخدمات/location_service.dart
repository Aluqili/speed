import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // تشغيل الموقع عندما يصبح المندوب متاحًا
  StreamSubscription<Position>? _subscription;

  Future<void> startLocationUpdates(String driverId) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // لا يمكن طلب تشغيل الخدمة برمجياً في geolocator
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    _subscription?.cancel();
    _subscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen(
          (pos) async {
            await _updateDriverLocation(driverId, pos.latitude, pos.longitude);
          },
          onError: (error) {
            // نتجاهل أخطاء البث لتفادي إسقاط التطبيق.
          },
        );
  }

  // تحديث موقع السائق في Firestore
  Future<void> _updateDriverLocation(
    String driverId,
    double latitude,
    double longitude,
  ) async {
    try {
      await _firestore.collection('drivers').doc(driverId).set({
        'location': GeoPoint(latitude, longitude),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' || e.code == 'not-found') {
        return;
      }
      rethrow;
    }
  }

  // إيقاف تحديث الموقع
  Future<void> stopLocationUpdates() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
