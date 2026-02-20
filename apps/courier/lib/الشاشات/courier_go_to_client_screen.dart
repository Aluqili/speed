import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:getwidget/getwidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import '../helpers/smart_location_tracker.dart';

class CourierGoToClientScreen extends StatefulWidget {
  final String orderId;
  final LatLng clientLocation;
  final String driverId;

  const CourierGoToClientScreen({
    Key? key,
    required this.orderId,
    required this.clientLocation,
    required this.driverId,
  }) : super(key: key);

  @override
  State<CourierGoToClientScreen> createState() => _CourierGoToClientScreenState();
}

class _CourierGoToClientScreenState extends State<CourierGoToClientScreen> {
  SmartLocationTracker? tracker;

  @override
  void initState() {
    super.initState();
    tracker = SmartLocationTracker(
      driverId: widget.driverId,
      orderId: widget.orderId,
      clientLocation: widget.clientLocation,
    );
    tracker!.startTracking();
  }

  @override
  void dispose() {
    tracker?.stopTracking();
    super.dispose();
  }

  Future<void> _openGoogleMaps() async {
    final Uri url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${widget.clientLocation.latitude},${widget.clientLocation.longitude}&travelmode=driving',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<Map<String, dynamic>?> _fetchOrderData() async {
    final doc = await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).get();
    if (doc.exists) return doc.data();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('الذهاب إلى العميل', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
          final String clientName = orderData['clientName'] ?? 'عميل غير معروف';

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
                    const Icon(Icons.person, color: Color(0xFFF57C00), size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        clientName,
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
                    target: widget.clientLocation,
                    zoom: 15,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('client'),
                      position: widget.clientLocation,
                      infoWindow: const InfoWindow(title: 'موقع العميل'),
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
                onPressed: _openGoogleMaps,
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
                  Get.toNamed('/driverConfirmDelivery', arguments: {
                    'orderId': widget.orderId,
                    'driverId': widget.driverId,
                  });
                },
                text: 'وصلت إلى العميل',
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
