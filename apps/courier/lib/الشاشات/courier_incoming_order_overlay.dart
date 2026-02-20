import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:get_storage/get_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // ✅ أُضيفت
import 'package:audioplayers/audioplayers.dart';

class CourierIncomingOrderOverlay extends StatefulWidget {
  final String driverId;
  final String orderId;
  final Map<String, dynamic> orderData;
  final LatLng driverLocation;
  final LatLng restaurantLocation;
  final LatLng clientLocation;
  final String? currentStage;

  const CourierIncomingOrderOverlay({
    Key? key,
    required this.driverId,
    required this.orderId,
    required this.orderData,
    required this.driverLocation,
    required this.restaurantLocation,
    required this.clientLocation,
    this.currentStage,
  }) : super(key: key);

  @override
  State<CourierIncomingOrderOverlay> createState() => _CourierIncomingOrderOverlayState();
}

class _CourierIncomingOrderOverlayState extends State<CourierIncomingOrderOverlay> {
  int _remainingSeconds = 50;
  Timer? _countdownTimer;
  Set<Polyline> _polylines = {};
  double _distanceToRestaurant = 0.0;
  double _distanceToClient = 0.0;
  int _driverFee = 0;
  String _currentStage = 'initial';
  final AudioPlayer _audioPlayer = AudioPlayer();
  GoogleMapController? _mapController;
  bool _isMapExpanded = false;

  @override
  void initState() {
    super.initState();
    _currentStage = widget.currentStage ?? 'initial';
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
    final bounds = LatLngBounds(
      southwest: LatLng(
        (widget.restaurantLocation.latitude < widget.clientLocation.latitude)
            ? widget.restaurantLocation.latitude
            : widget.clientLocation.latitude,
        (widget.restaurantLocation.longitude < widget.clientLocation.longitude)
            ? widget.restaurantLocation.longitude
            : widget.clientLocation.longitude,
      ),
      northeast: LatLng(
        (widget.restaurantLocation.latitude > widget.clientLocation.latitude)
            ? widget.restaurantLocation.latitude
            : widget.clientLocation.latitude,
        (widget.restaurantLocation.longitude > widget.clientLocation.longitude)
            ? widget.restaurantLocation.longitude
            : widget.clientLocation.longitude,
      ),
    );
    await _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  void _setupNotificationListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data['type'] == 'order_offer' && message.data['orderId'] == widget.orderId) {
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
    await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
      'driverResponse': 'timeout',
    });
    _audioPlayer.stop();
    if (mounted) Get.back();
  }

  Future<void> _acceptOrder() async {
    // تم حذف شرط readyByRestaurant، يمكن قبول الطلب مباشرة
    await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
      'driverResponse': 'accepted',
      'orderStatus': 'قيد التوصيل',
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

    Get.offNamed('/driver_order_process', arguments: {
      'orderId': widget.orderId,
      'stage': 'going_to_restaurant',
    });
  }

  Future<void> _rejectOrder() async {
    await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
      'driverResponse': 'rejected',
    });
    _audioPlayer.stop();
    if (mounted) Get.back();
  }

  Future<void> _drawRoute() async {
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=${widget.restaurantLocation.latitude},${widget.restaurantLocation.longitude}'
      '&destination=${widget.clientLocation.latitude},${widget.clientLocation.longitude}'
      '&mode=driving&key=$apiKey',
    );
    final response = await http.get(url);
    final data = json.decode(response.body);
    if (data['routes'] != null && data['routes'].isNotEmpty) {
      final points = data['routes'][0]['overview_polyline']['points'];
      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: _decodePolyline(points),
            width: 8,
            color: Colors.blueAccent,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        };
      });
    }
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
        ) / 1000;

    _distanceToClient = Geolocator.distanceBetween(
          widget.restaurantLocation.latitude,
          widget.restaurantLocation.longitude,
          widget.clientLocation.latitude,
          widget.clientLocation.longitude,
        ) / 1000;

    if (_distanceToClient < 2) {
      _driverFee = 2000;
    } else if (_distanceToClient < 5) {
      _driverFee = 2500;
    } else if (_distanceToClient < 10) {
      _driverFee = 3000;
    } else if (_distanceToClient < 14) {
      _driverFee = 3500;
    } else {
      _driverFee = (_distanceToClient.ceil() * 250);
    }

    setState(() {});
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F8F8),
      body: Column(
        children: [
          Expanded(
            child: _buildContentBasedOnStage(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _acceptOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(Icons.check, color: Colors.white),
                    label: Text('قبول الطلب', style: TextStyle(color: Colors.white, fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _rejectOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(Icons.close, color: Colors.white),
                    label: Text('رفض الطلب', style: TextStyle(color: Colors.white, fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildContentBasedOnStage() {
    switch (_currentStage) {
      case 'going_to_restaurant':
        return _buildRestaurantNavigationScreen();
      case 'order_picked_up':
        return _buildDeliveryNavigationScreen();
      case 'delivered':
        return _buildDeliveryCompleteScreen();
      default:
        return _buildInitialOfferScreen();
    }
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // شارة حالة الطلب
                    Row(
                      children: [
                        Chip(
                          label: Text('بانتظار قبولك', style: TextStyle(color: Colors.white, fontFamily: 'Tajawal')),
                          backgroundColor: Colors.orange,
                          avatar: Icon(Icons.timer, color: Colors.white),
                        ),
                        Spacer(),
                        Text('⏱ $_remainingSeconds ثانية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange)),
                      ],
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
                              initialCameraPosition: CameraPosition(target: widget.restaurantLocation, zoom: 13),
                              onMapCreated: (controller) {
                                _mapController = controller;
                                _moveCameraToBounds();
                              },
                              markers: {
                                Marker(
                                  markerId: const MarkerId('restaurant'),
                                  position: widget.restaurantLocation,
                                  infoWindow: const InfoWindow(title: '🍽️ المطعم'),
                                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                                ),
                                Marker(
                                  markerId: const MarkerId('client'),
                                  position: widget.clientLocation,
                                  infoWindow: const InfoWindow(title: '🏠 العميل'),
                                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                                ),
                                Marker(
                                  markerId: const MarkerId('driver'),
                                  position: widget.driverLocation,
                                  infoWindow: const InfoWindow(title: '🧑‍✈️ موقعك'),
                                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
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
                                Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer())
                              },
                            ),
                          ),
                          Positioned(
                            top: 8,
                            left: 8,
                            child: FloatingActionButton(
                              mini: true,
                              backgroundColor: Colors.white,
                              onPressed: () => setState(() => _isMapExpanded = !_isMapExpanded),
                              child: Icon(_isMapExpanded ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.blue),
                              tooltip: _isMapExpanded ? 'تصغير الخريطة' : 'توسيع الخريطة',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.store, color: Colors.deepOrange),
                        SizedBox(width: 6),
                        Text('المطعم: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(data['restaurantName'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.person_pin_circle, color: Colors.blueAccent),
                        SizedBox(width: 6),
                        Text('العميل: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(data['clientName'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.directions_car, color: Colors.green),
                        SizedBox(width: 6),
                        Text('المسافة للمطعم: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('${_distanceToRestaurant.toStringAsFixed(1)} كم', style: TextStyle(color: Colors.black87)),
                        Spacer(),
                        Icon(Icons.navigation, color: Colors.orange),
                        SizedBox(width: 6),
                        Text('من المطعم للعميل: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('${_distanceToClient.toStringAsFixed(1)} كم', style: TextStyle(color: Colors.black87)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Divider(),
                    Text('💰 رسوم التوصيل: $_driverFee ج.س', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                    const SizedBox(height: 12),
                    Card(
                      color: Color(0xFFFFF3E0),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('تفاصيل الأصناف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 6),
                            ...((data['items'] as List<dynamic>).map((item) => Row(
                              children: [
                                Icon(Icons.fastfood, color: Colors.deepOrange, size: 18),
                                SizedBox(width: 6),
                                Expanded(child: Text('${item['name']} × ${item['quantity']} (${item['price']} ج.س)', style: TextStyle(fontSize: 15))),
                              ],
                            ))),
                          ],
                        ),
                      ),
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

  Widget _buildRestaurantNavigationScreen() {
    return const Center(child: Text('🚕 جاري التوجه إلى المطعم...'));
  }

  Widget _buildDeliveryNavigationScreen() {
    return const Center(child: Text('📦 تم استلام الطلب، جارٍ التوصيل...'));
  }

  Widget _buildDeliveryCompleteScreen() {
    final data = widget.orderData;
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 64),
              const SizedBox(height: 16),
              const Text('تم تسليم الطلب بنجاح!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text('رقم الطلب: ${widget.orderId}', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Text('العميل: ${data['clientName'] ?? ''}', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Text('المبلغ الإجمالي: ${data['total'] ?? ''} ج.س', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Get.offAllNamed('/driver_home');
                },
                icon: const Icon(Icons.home),
                label: const Text('العودة للرئيسية'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
