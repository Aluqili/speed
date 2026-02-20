/// خدمة الموقع: تتبع موقع المندوب وتحديثه في السحابة.
import 'package:location/location.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocationServiceArabic {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// يبدأ تتبع الموقع عندما يصبح المندوب متاحًا.
  Future<void> startLocationUpdates(String driverId) async {
    final location = Location();

    // طلب صلاحيات الموقع
    var serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }

    var permission = await location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await location.requestPermission();
      if (permission != PermissionStatus.granted) return;
    }

    // الاستماع لتغيّر الموقع وتحديثه في Firestore
    location.onLocationChanged.listen((current) async {
      final lat = current.latitude;
      final lng = current.longitude;
      if (lat != null && lng != null) {
        await _updateDriverLocation(driverId, lat, lng);
      }
    });
  }

  /// تحديث موقع السائق في Firestore.
  Future<void> _updateDriverLocation(
    String driverId,
    double lat,
    double lng,
  ) async {
    await _firestore.collection('drivers').doc(driverId).update({
      'location': GeoPoint(lat, lng),
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  /// إيقاف تحديث الموقع (إلغاء الاشتراك خارجيًا عند الحاجة).
  Future<void> stopLocationUpdates() async {}
}
