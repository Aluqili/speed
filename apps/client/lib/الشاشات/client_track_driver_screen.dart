import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:getwidget/getwidget.dart';
import 'package:url_launcher/url_launcher.dart';

import 'chat_screen.dart';

class ClientTrackDriverScreen extends StatefulWidget {
  final String orderId;

  const ClientTrackDriverScreen({Key? key, required this.orderId})
      : super(key: key);

  @override
  State<ClientTrackDriverScreen> createState() =>
      _ClientTrackDriverScreenState();
}

class _ClientTrackDriverScreenState extends State<ClientTrackDriverScreen> {
  GoogleMapController? _mapController;
  bool _notifiedClient = false;
  bool _closedAfterFinish = false;

  String _generateChatId(String user1, String user2) {
    final sorted = [user1, user2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  String _resolveDriverPhone(
    Map<String, dynamic> orderData,
    Map<String, dynamic>? driverData,
  ) {
    final candidates = [
      orderData['driverPhone'],
      orderData['driverPhoneNumber'],
      driverData?['phone'],
      driverData?['phoneNumber'],
    ];

    for (final candidate in candidates) {
      final value = (candidate ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  Future<void> _callDriver(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    final launched = await launchUrl(uri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح تطبيق الاتصال.')),
      );
    }
  }

  LatLng? _latLngFromOrder(dynamic raw, String latKey, String lngKey) {
    if (raw is GeoPoint) {
      return LatLng(raw.latitude, raw.longitude);
    }
    if (raw is Map<String, dynamic>) {
      final lat = (raw['lat'] as num?)?.toDouble() ??
          (raw['latitude'] as num?)?.toDouble();
      final lng = (raw['lng'] as num?)?.toDouble() ??
          (raw['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        return LatLng(lat, lng);
      }
    }
    final lat = (raw is Map<String, dynamic>)
        ? (raw[latKey] as num?)?.toDouble()
        : null;
    final lng = (raw is Map<String, dynamic>)
        ? (raw[lngKey] as num?)?.toDouble()
        : null;
    if (lat != null && lng != null) {
      return LatLng(lat, lng);
    }
    return null;
  }

  LatLng? _locationFromOrderFields(Map<String, dynamic> orderData,
      {required String rawKey,
      required String latKey,
      required String lngKey}) {
    final direct = _latLngFromOrder(orderData[rawKey], latKey, lngKey);
    if (direct != null) return direct;
    final lat = (orderData[latKey] as num?)?.toDouble();
    final lng = (orderData[lngKey] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  LatLng? _driverLocationFromSources(
    Map<String, dynamic> orderData,
    Map<String, dynamic>? driverData,
  ) {
    final orderDriver = _locationFromOrderFields(
      orderData,
      rawKey: 'driverLocation',
      latKey: 'driverLat',
      lngKey: 'driverLng',
    );

    if (driverData == null) return orderDriver;

    final fromCurrent =
        _latLngFromOrder(driverData['currentLocation'], 'lat', 'lng');
    if (fromCurrent != null) return fromCurrent;

    final fromLocation = _latLngFromOrder(driverData['location'], 'lat', 'lng');
    if (fromLocation != null) return fromLocation;

    return orderDriver;
  }

  Set<Marker> _buildMarkers({
    required LatLng? driverLocation,
    required LatLng? clientLocation,
    required LatLng? restaurantLocation,
  }) {
    final markers = <Marker>{};

    if (driverLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: driverLocation,
          infoWindow: const InfoWindow(title: '🛵 موقع المندوب'),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        ),
      );
    }

    if (restaurantLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('restaurant'),
          position: restaurantLocation,
          infoWindow: const InfoWindow(title: '🍽️ المطعم'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    if (clientLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('client'),
          position: clientLocation,
          infoWindow: const InfoWindow(title: '🏠 موقع العميل'),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }

    return markers;
  }

  Set<Polyline> _buildPolylines({
    required LatLng? driverLocation,
    required LatLng? clientLocation,
  }) {
    if (driverLocation == null || clientLocation == null) return {};
    return {
      Polyline(
        polylineId: const PolylineId('driver_to_client'),
        color: Colors.amber,
        width: 5,
        points: [driverLocation, clientLocation],
      ),
    };
  }

  void _fitCameraToPoints(List<LatLng> points) {
    if (_mapController == null || points.isEmpty) return;
    if (points.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: points.first, zoom: 15),
        ),
      );
      return;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points.skip(1)) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GFAppBar(
        title: const Text('تتبع المندوب'),
        backgroundColor: GFColors.SUCCESS,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: GFLoader(type: GFLoaderType.circle));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
                child: Text('لا توجد بيانات متوفرة لهذا الطلب.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final assignedDriverId =
              (data['assignedDriverId'] ?? '').toString().trim();

          final clientLocation = _locationFromOrderFields(
            data,
            rawKey: 'clientLocation',
            latKey: 'clientLat',
            lngKey: 'clientLng',
          );
          final restaurantLocation = _locationFromOrderFields(
            data,
            rawKey: 'restaurantLocation',
            latKey: 'restaurantLat',
            lngKey: 'restaurantLng',
          );
          final orderStatus =
              (data['orderStatus'] ?? data['status'] ?? '').toString();

          const finishedStatuses = {
            'delivered',
            'cancelled',
            'store_rejected',
            'rejected_by_store',
          };

          if (finishedStatuses.contains(orderStatus)) {
            if (!_closedAfterFinish) {
              _closedAfterFinish = true;
              Future.microtask(() {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('انتهى الطلب، تم إيقاف تتبع المندوب.'),
                  ),
                );
                Navigator.of(context).maybePop();
              });
            }

            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'انتهى الطلب، لم يعد تتبع المندوب متاحًا.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (clientLocation == null) {
            return const Center(child: Text('موقع العميل غير متاح بعد.'));
          }

          if (assignedDriverId.isEmpty) {
            return const Center(
              child: Text('لم يتم تعيين مندوب للطلب بعد.'),
            );
          }

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('drivers')
                .doc(assignedDriverId)
                .snapshots(),
            builder: (context, driverSnapshot) {
              final driverData =
                  driverSnapshot.data?.data() as Map<String, dynamic>?;
              final driverLocation =
                  _driverLocationFromSources(data, driverData);

              if (driverLocation == null) {
                return Center(
                  child: Text(
                    orderStatus == 'courier_assigned' ||
                            orderStatus == 'pickup_ready'
                        ? 'تم تعيين المندوب، بانتظار بدء التوصيل وتحديث موقعه...'
                        : 'موقع المندوب غير متاح بعد.',
                  ),
                );
              }

              final distance =
                  _calculateDistance(driverLocation, clientLocation);

              if (distance <= 200 && !_notifiedClient) {
                _notifiedClient = true;
                Future.microtask(() {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('🚚 المندوب قريب منك! استعد لاستلام طلبك 🎉'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 4),
                    ),
                  );
                });
              }

              final mapPoints = <LatLng>[
                driverLocation,
                clientLocation,
                if (restaurantLocation != null) restaurantLocation,
              ];

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _fitCameraToPoints(mapPoints);
              });

              final driverName =
                  (data['driverName'] ?? driverData?['name'] ?? 'المندوب')
                      .toString();
              final driverPhone = _resolveDriverPhone(data, driverData);
              final clientId = (data['clientId'] ??
                      FirebaseAuth.instance.currentUser?.uid ??
                      '')
                  .toString()
                  .trim();

              return Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: driverLocation,
                      zoom: 15,
                    ),
                    markers: _buildMarkers(
                      driverLocation: driverLocation,
                      clientLocation: clientLocation,
                      restaurantLocation: restaurantLocation,
                    ),
                    polylines: _buildPolylines(
                      driverLocation: driverLocation,
                      clientLocation: clientLocation,
                    ),
                    onMapCreated: (GoogleMapController controller) {
                      _mapController = controller;
                      _fitCameraToPoints(mapPoints);
                    },
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'تواصل مع $driverName',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          IconButton.filledTonal(
                            onPressed: clientId.isEmpty
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatScreen(
                                          currentUserId: clientId,
                                          otherUserId: assignedDriverId,
                                          currentUserRole: 'client',
                                          chatId: _generateChatId(
                                            clientId,
                                            assignedDriverId,
                                          ),
                                          currentUserName: 'العميل',
                                        ),
                                      ),
                                    );
                                  },
                            tooltip: 'دردشة مع المندوب',
                            icon: const Icon(Icons.chat_bubble_outline),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            onPressed: driverPhone.isEmpty
                                ? null
                                : () => _callDriver(driverPhone),
                            tooltip: 'اتصال بالمندوب',
                            icon: const Icon(Icons.call_outlined),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  double _deg2rad(double deg) => deg * (pi / 180.0);

  double _calculateDistance(LatLng start, LatLng end) {
    const double R = 6371000; // Earth radius in meters
    final double dLat = _deg2rad(end.latitude - start.latitude);
    final double dLon = _deg2rad(end.longitude - start.longitude);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(start.latitude)) *
            cos(_deg2rad(end.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
