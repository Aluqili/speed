import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:getwidget/getwidget.dart';

class ClientTrackDriverScreen extends StatefulWidget {
  final String orderId;

  const ClientTrackDriverScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  State<ClientTrackDriverScreen> createState() => _ClientTrackDriverScreenState();
}

class _ClientTrackDriverScreenState extends State<ClientTrackDriverScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  LatLng? driverLocation;
  LatLng? clientLocation;
  bool _notifiedClient = false;
  Set<Polyline> _polylines = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GFAppBar(
        title: const Text('تتبع المندوب'),
        backgroundColor: GFColors.SUCCESS,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').doc(widget.orderId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: GFLoader(type: GFLoaderType.circle));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('لا توجد بيانات متوفرة لهذا الطلب.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final driverLoc = data['driverLocation'];
          final clientLat = data['clientLat'];
          final clientLng = data['clientLng'];

          if (driverLoc == null || clientLat == null || clientLng == null) {
            return const Center(child: Text('موقع السائق أو العميل غير متاح بعد.'));
          }

          driverLocation = LatLng(driverLoc['latitude'], driverLoc['longitude']);
          clientLocation = LatLng(clientLat, clientLng);

          _createPolyline(driverLocation!, clientLocation!);

          final distance = _calculateDistance(driverLocation!, clientLocation!);

          if (distance <= 200 && !_notifiedClient) {
            _notifiedClient = true;
            Future.microtask(() {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🚚 المندوب قريب منك! استعد لاستلام طلبك 🎉'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 4),
                ),
              );
            });
          }

          return GoogleMap(
            initialCameraPosition: CameraPosition(
              target: driverLocation!,
              zoom: 15,
            ),
            markers: _buildMarkers(),
            polylines: _polylines,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
              Future.delayed(const Duration(milliseconds: 500), () {
                _moveCamera(controller, driverLocation!, clientLocation!);
              });
            },
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          );
        },
      ),
    );
  }

  Set<Marker> _buildMarkers() {
    return {
      Marker(
        markerId: const MarkerId('driver'),
        position: driverLocation!,
        infoWindow: const InfoWindow(title: 'موقع المندوب'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
      Marker(
        markerId: const MarkerId('client'),
        position: clientLocation!,
        infoWindow: const InfoWindow(title: 'موقع العميل'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
    };
  }

  void _createPolyline(LatLng start, LatLng end) {
    final polyline = Polyline(
      polylineId: const PolylineId('route'),
      color: Colors.amber,
      width: 5,
      points: [start, end],
    );
    setState(() {
      _polylines = {polyline};
    });
  }

  Future<void> _moveCamera(GoogleMapController controller, LatLng driver, LatLng client) async {
    final bounds = LatLngBounds(
      southwest: LatLng(
        min(driver.latitude, client.latitude),
        min(driver.longitude, client.longitude),
      ),
      northeast: LatLng(
        max(driver.latitude, client.latitude),
        max(driver.longitude, client.longitude),
      ),
    );

    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  double _deg2rad(double deg) => deg * (pi / 180.0);

  double _calculateDistance(LatLng start, LatLng end) {
    const double R = 6371000; // Earth radius in meters
    final double dLat = _deg2rad(end.latitude - start.latitude);
    final double dLon = _deg2rad(end.longitude - start.longitude);
    final double a = 
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_deg2rad(start.latitude)) * cos(_deg2rad(end.latitude)) *
      sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }
}
