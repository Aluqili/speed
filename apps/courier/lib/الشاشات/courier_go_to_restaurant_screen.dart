import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:getwidget/getwidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

class CourierGoToRestaurantScreen extends StatelessWidget {
  final String orderId;
  final String driverId;

  const CourierGoToRestaurantScreen({
    Key? key,
    required this.orderId,
    required this.driverId,
  }) : super(key: key);

  Future<void> _openGoogleMaps(LatLng location) async {
    final Uri url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${location.latitude},${location.longitude}&travelmode=driving');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<Map<String, dynamic>?> _fetchOrderData() async {
    final doc = await FirebaseFirestore.instance.collection('orders').doc(orderId).get();
    if (doc.exists) return doc.data();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'الذهاب إلى المطعم',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _fetchOrderData(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final orderData = snapshot.data!;
          final String restaurantName = orderData['restaurantName'] ?? 'اسم غير معروف';

          final double? restaurantLat = (orderData['restaurantLat'] as num?)?.toDouble();
          final double? restaurantLng = (orderData['restaurantLng'] as num?)?.toDouble();
          final double? clientLat = (orderData['clientLat'] as num?)?.toDouble();
          final double? clientLng = (orderData['clientLng'] as num?)?.toDouble();

          if (restaurantLat == null || restaurantLng == null || clientLat == null || clientLng == null) {
            return const Center(
              child: Text('🚫 لا يمكن تحميل مواقع الطلب، تأكد من صحة البيانات.'),
            );
          }

          final LatLng restaurantLocation = LatLng(restaurantLat, restaurantLng);
          final LatLng clientLocation = LatLng(clientLat, clientLng);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.store, color: Color(0xFFF57C00), size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        restaurantName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 240,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: restaurantLocation,
                    zoom: 15,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('restaurant'),
                      position: restaurantLocation,
                      infoWindow: const InfoWindow(title: 'المطعم'),
                    ),
                  },
                  zoomControlsEnabled: false,
                  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                    Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                  },
                ),
              ),
              const SizedBox(height: 20),
              GFButton(
                onPressed: () => _openGoogleMaps(restaurantLocation),
                text: 'افتح في خرائط Google',
                icon: const Icon(Icons.map_outlined),
                color: const Color(0xFFF57C00),
                shape: GFButtonShape.pills,
                fullWidthButton: true,
                size: GFSize.LARGE,
                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 20),
              GFButton(
                onPressed: () {
                  Get.offNamed('/driverGoToClient', arguments: {
                    'orderId': orderId,
                    'clientLocation': clientLocation,
                    'driverId': driverId,
                  });
                },
                text: 'وصلت إلى المطعم',
                icon: const Icon(Icons.check_circle),
                color: GFColors.SUCCESS,
                shape: GFButtonShape.pills,
                fullWidthButton: true,
                size: GFSize.LARGE,
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          );
        },
      ),
    );
  }
}
