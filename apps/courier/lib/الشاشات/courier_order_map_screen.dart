import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class CourierOrderMapScreen extends StatefulWidget {
  final double restaurantLat;
  final double restaurantLng;
  final double clientLat;
  final double clientLng;

  const CourierOrderMapScreen({
    Key? key,
    required this.restaurantLat,
    required this.restaurantLng,
    required this.clientLat,
    required this.clientLng,
  }) : super(key: key);

  @override
  State<CourierOrderMapScreen> createState() => _CourierOrderMapScreenState();
}

class _CourierOrderMapScreenState extends State<CourierOrderMapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  StreamSubscription<Position>? _positionStream;
  LatLng? _driverPosition;
  bool _notifiedClient = false; // متغير لمنع التكرار في الإشعارات

  @override
  void initState() {
    super.initState();
    _setupInitialMarkers();
    _startTrackingDriver();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  void _setupInitialMarkers() {
    _markers.add(
      Marker(
        markerId: const MarkerId('restaurant'),
        position: LatLng(widget.restaurantLat, widget.restaurantLng),
        infoWindow: const InfoWindow(title: 'المطعم'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );

    _markers.add(
      Marker(
        markerId: const MarkerId('client'),
        position: LatLng(widget.clientLat, widget.clientLng),
        infoWindow: const InfoWindow(title: 'العميل'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
    );

    _polylines.add(
      Polyline(
        polylineId: const PolylineId('route'),
        points: [
          LatLng(widget.restaurantLat, widget.restaurantLng),
          LatLng(widget.clientLat, widget.clientLng),
        ],
        width: 5,
        color: Colors.deepOrange,
      ),
    );
  }

  void _startTrackingDriver() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // يحدث كل 10 متر
      ),
    ).listen((Position position) async {
      _driverPosition = LatLng(position.latitude, position.longitude);

      final GoogleMapController mapController = await _controller.future;

      setState(() {
        _markers.removeWhere((marker) => marker.markerId.value == 'driver');
        _markers.add(
          Marker(
            markerId: const MarkerId('driver'),
            position: _driverPosition!,
            infoWindow: const InfoWindow(title: 'موقعي الحالي'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          ),
        );
      });

      // تحديث الكاميرا لموقع المندوب
      mapController.animateCamera(
        CameraUpdate.newLatLng(_driverPosition!),
      );

      // 🔥 التحقق من المسافة
      _checkProximityToClient();
    });
  }

  void _checkProximityToClient() {
    if (_driverPosition == null) return;

    double distance = Geolocator.distanceBetween(
      _driverPosition!.latitude,
      _driverPosition!.longitude,
      widget.clientLat,
      widget.clientLng,
    );

    if (distance <= 200 && !_notifiedClient) {
      _notifiedClient = true; // منع تكرار الإشعار
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أنت قريب جداً من موقع العميل!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تتبع التوصيل'),
        backgroundColor: Colors.green,
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(widget.restaurantLat, widget.restaurantLng),
          zoom: 13,
        ),
        markers: _markers,
        polylines: _polylines,
        myLocationEnabled: true,
        onMapCreated: (GoogleMapController controller) {
          _controller.complete(controller);
        },
      ),
    );
  }
}
