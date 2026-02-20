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
    _subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) async {
      await _updateDriverLocation(driverId, pos.latitude, pos.longitude);
    });
  }

  // تحديث موقع السائق في Firestore
  Future<void> _updateDriverLocation(String driverId, double latitude, double longitude) async {
    await _firestore.collection('drivers').doc(driverId).update({
      'location': GeoPoint(latitude, longitude),
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  // إيقاف تحديث الموقع
  Future<void> stopLocationUpdates() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
