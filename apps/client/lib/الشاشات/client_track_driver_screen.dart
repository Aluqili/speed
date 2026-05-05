import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

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
  static const Color _primary = AppThemeArabic.clientPrimary;

  GoogleMapController? _mapController;
  bool _notifiedClient = false;
  bool _closedAfterFinish = false;

  // Route caching — refetch only when driver moves significantly
  List<LatLng> _routePoints = [];
  LatLng? _lastRouteFetchOrigin;
  bool _fetchingRoute = false;

  // ─── helpers ──────────────────────────────────────────────────────────────

  String _generateChatId(String u1, String u2) {
    final s = [u1, u2]..sort();
    return '${s[0]}_${s[1]}';
  }

  String _resolveDriverPhone(
      Map<String, dynamic> order, Map<String, dynamic>? driver) {
    for (final v in [
      order['driverPhone'],
      order['driverPhoneNumber'],
      driver?['phone'],
      driver?['phoneNumber'],
    ]) {
      final s = (v ?? '').toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  LatLng? _geoFromRaw(dynamic raw) {
    if (raw is GeoPoint) return LatLng(raw.latitude, raw.longitude);
    if (raw is Map) {
      final lat = (raw['lat'] ?? raw['latitude'] as num?)?.toDouble();
      final lng = (raw['lng'] ?? raw['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    return null;
  }

  LatLng? _locationFromFields(Map<String, dynamic> d,
      {required String rawKey, required String latKey, required String lngKey}) {
    final direct = _geoFromRaw(d[rawKey]);
    if (direct != null) return direct;
    final lat = (d[latKey] as num?)?.toDouble();
    final lng = (d[lngKey] as num?)?.toDouble();
    if (lat != null && lng != null) return LatLng(lat, lng);
    return null;
  }

  LatLng? _driverLoc(Map<String, dynamic> order, Map<String, dynamic>? driver) {
    if (driver != null) {
      final cur = _geoFromRaw(driver['currentLocation']);
      if (cur != null) return cur;
      final loc = _geoFromRaw(driver['location']);
      if (loc != null) return loc;
    }
    return _locationFromFields(order,
        rawKey: 'driverLocation', latKey: 'driverLat', lngKey: 'driverLng');
  }

  double _distanceM(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLng = (b.longitude - a.longitude) * pi / 180;
    final x = sin(dLat / 2) * sin(dLat / 2) +
        cos(a.latitude * pi / 180) *
            cos(b.latitude * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return R * 2 * atan2(sqrt(x), sqrt(1 - x));
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.toInt()} م';
    return '${(meters / 1000).toStringAsFixed(1)} كم';
  }

  // ─── Google Directions API ─────────────────────────────────────────────────

  Future<void> _fetchRoute(LatLng origin, LatLng dest) async {
    if (_fetchingRoute) return;

    // Don't refetch if driver hasn't moved more than 80 m
    if (_lastRouteFetchOrigin != null &&
        _distanceM(_lastRouteFetchOrigin!, origin) < 80 &&
        _routePoints.isNotEmpty) { return; }

    _fetchingRoute = true;
    try {
      String apiKey = '';
      try {
        apiKey = FirebaseRemoteConfig.instance
            .getString('google_directions_api_key')
            .trim();
      } catch (_) {}

      if (apiKey.isEmpty) {
        if (mounted) {
          setState(() {
            _routePoints = [origin, dest];
            _lastRouteFetchOrigin = origin;
          });
        }
        return;
      }

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${dest.latitude},${dest.longitude}'
        '&mode=driving'
        '&key=$apiKey',
      );

      final response =
          await http.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = json['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final encoded =
              routes[0]['overview_polyline']['points'] as String;
          final points = _decodePolyline(encoded);
          if (mounted) {
            setState(() {
              _routePoints = points;
              _lastRouteFetchOrigin = origin;
            });
          }
          return;
        }
      }
    } catch (_) {}

    // fallback: straight line
    if (mounted) {
      setState(() {
        _routePoints = [origin, dest];
        _lastRouteFetchOrigin = origin;
      });
    }
    _fetchingRoute = false;
  }

  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    int lat = 0, lng = 0;
    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  // ─── Map helpers ──────────────────────────────────────────────────────────

  void _fitBounds(List<LatLng> points) {
    if (_mapController == null || points.isEmpty) return;
    if (points.length == 1) {
      _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
              CameraPosition(target: points.first, zoom: 15)));
      return;
    }
    double minLat = points.first.latitude, maxLat = minLat;
    double minLng = points.first.longitude, maxLng = minLng;
    for (final p in points.skip(1)) {
      minLat = min(minLat, p.latitude);
      maxLat = max(maxLat, p.latitude);
      minLng = min(minLng, p.longitude);
      maxLng = max(maxLng, p.longitude);
    }
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng)),
      100,
    ));
  }

  Future<void> _callDriver(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح تطبيق الاتصال.')));
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // ─── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .doc(widget.orderId)
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return _buildLoading();
            }
            if (!snap.hasData || !snap.data!.exists) {
              return _buildError('لا توجد بيانات لهذا الطلب.');
            }

            final order = snap.data!.data() as Map<String, dynamic>;
            final status =
                (order['orderStatus'] ?? order['status'] ?? '').toString();

            const finished = {
              'delivered', 'cancelled', 'store_rejected', 'rejected_by_store'
            };
            if (finished.contains(status)) {
              if (!_closedAfterFinish) {
                _closedAfterFinish = true;
                Future.microtask(() {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('انتهى الطلب، تم إيقاف التتبع.')));
                  Navigator.of(context).maybePop();
                });
              }
              return _buildError('انتهى الطلب.');
            }

            final clientLoc = _locationFromFields(order,
                rawKey: 'clientLocation',
                latKey: 'clientLat',
                lngKey: 'clientLng');
            if (clientLoc == null) {
              return _buildError('موقع العميل غير متاح.');
            }

            final driverId =
                (order['assignedDriverId'] ?? '').toString().trim();
            if (driverId.isEmpty) {
              return _buildWaiting('لم يتم تعيين مندوب بعد...');
            }

            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('drivers')
                  .doc(driverId)
                  .snapshots(),
              builder: (context, dSnap) {
                final driverData =
                    dSnap.data?.data() as Map<String, dynamic>?;
                final driverLoc = _driverLoc(order, driverData);

                if (driverLoc == null) {
                  return _buildWaiting(
                      status == 'courier_assigned' ||
                              status == 'pickup_ready'
                          ? 'تم تعيين المندوب، بانتظار تحديث موقعه...'
                          : 'موقع المندوب غير متاح بعد.');
                }

                // proximity notification
                final dist = _distanceM(driverLoc, clientLoc);
                if (dist <= 200 && !_notifiedClient) {
                  _notifiedClient = true;
                  Future.microtask(() {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('المندوب قريب منك! استعد لاستلام طلبك'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 4),
                    ));
                  });
                }

                // fetch route when driver moves
                _fetchRoute(driverLoc, clientLoc);

                // fit camera
                final mapPoints = [driverLoc, clientLoc];
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _fitBounds(mapPoints);
                });

                final driverName =
                    (order['driverName'] ?? driverData?['name'] ?? 'المندوب')
                        .toString();
                final driverPhone = _resolveDriverPhone(order, driverData);
                final clientId = (order['clientId'] ??
                        FirebaseAuth.instance.currentUser?.uid ??
                        '')
                    .toString()
                    .trim();
                final restaurantLoc = _locationFromFields(order,
                    rawKey: 'restaurantLocation',
                    latKey: 'restaurantLat',
                    lngKey: 'restaurantLng');

                return _buildTrackingView(
                  order: order,
                  driverLoc: driverLoc,
                  clientLoc: clientLoc,
                  restaurantLoc: restaurantLoc,
                  driverName: driverName,
                  driverPhone: driverPhone,
                  clientId: clientId,
                  driverId: driverId,
                  distanceM: dist,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildTrackingView({
    required Map<String, dynamic> order,
    required LatLng driverLoc,
    required LatLng clientLoc,
    LatLng? restaurantLoc,
    required String driverName,
    required String driverPhone,
    required String clientId,
    required String driverId,
    required double distanceM,
  }) {
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('driver'),
        position: driverLoc,
        infoWindow: InfoWindow(title: driverName),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ),
      Marker(
        markerId: const MarkerId('client'),
        position: clientLoc,
        infoWindow: const InfoWindow(title: 'موقعك'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
      if (restaurantLoc != null)
        Marker(
          markerId: const MarkerId('restaurant'),
          position: restaurantLoc,
          infoWindow: InfoWindow(
              title: (order['restaurantName'] ?? 'المطعم').toString()),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
    };

    final polylines = <Polyline>{
      if (_routePoints.length >= 2)
        Polyline(
          polylineId: const PolylineId('route'),
          points: _routePoints,
          width: 5,
          color: _primary,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
    };

    // ETA estimate: assume ~25 km/h average speed in city
    final etaMins = (distanceM / 1000 / 25 * 60).ceil();

    return Stack(
      children: [
        // ── Full-screen map ───────────────────────────────────────────
        GoogleMap(
          initialCameraPosition:
              CameraPosition(target: driverLoc, zoom: 14),
          markers: markers,
          polylines: polylines,
          onMapCreated: (c) {
            _mapController = c;
            _fitBounds([driverLoc, clientLoc]);
          },
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),

        // ── Back button ───────────────────────────────────────────────
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          right: 16,
          child: _floatingIconBtn(
            icon: Icons.arrow_forward_ios_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),

        // ── "Fit all" button ──────────────────────────────────────────
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 16,
          child: _floatingIconBtn(
            icon: Icons.fit_screen_rounded,
            onTap: () => _fitBounds([driverLoc, clientLoc]),
          ),
        ),

        // ── Distance chip ─────────────────────────────────────────────
        Positioned(
          top: MediaQuery.of(context).padding.top + 68,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 6)
                ],
              ),
              child: Text(
                '${_formatDistance(distanceM)} متبقي  •  ~$etaMins د',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),

        // ── Bottom driver panel ───────────────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _DriverBottomPanel(
            driverName: driverName,
            driverPhone: driverPhone,
            canCall: driverPhone.isNotEmpty,
            canChat: clientId.isNotEmpty,
            onCall: () => _callDriver(driverPhone),
            onChat: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  currentUserId: clientId,
                  otherUserId: driverId,
                  currentUserRole: 'client',
                  chatId: _generateChatId(clientId, driverId),
                  currentUserName: 'العميل',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── helpers ─────────────────────────────────────────────────────────────

  Widget _floatingIconBtn(
      {required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: Icon(icon, size: 18, color: Colors.black87),
      ),
    );
  }

  Widget _buildLoading() => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );

  Widget _buildError(String msg) => Scaffold(
        appBar: AppBar(
          backgroundColor: _primary,
          title: const Text('تتبع المندوب',
              style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(child: Text(msg, textAlign: TextAlign.center)),
      );

  Widget _buildWaiting(String msg) => Scaffold(
        appBar: AppBar(
          backgroundColor: _primary,
          title: const Text('تتبع المندوب',
              style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(msg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15)),
            ],
          ),
        ),
      );
}

// ─── Driver Bottom Panel ───────────────────────────────────────────────────

class _DriverBottomPanel extends StatelessWidget {
  const _DriverBottomPanel({
    required this.driverName,
    required this.driverPhone,
    required this.canCall,
    required this.canChat,
    required this.onCall,
    required this.onChat,
  });

  final String driverName;
  final String driverPhone;
  final bool canCall;
  final bool canChat;
  final VoidCallback onCall;
  final VoidCallback onChat;

  static const Color _primary = AppThemeArabic.clientPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 20, offset: Offset(0, -4))
        ],
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // driver info row
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: _primary.withValues(alpha: 0.12),
                child:
                    const Icon(Icons.delivery_dining_rounded, color: _primary, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverName,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      driverPhone.isNotEmpty ? driverPhone : 'مندوب التوصيل',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              // online indicator
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    color: Colors.green, shape: BoxShape.circle),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // action buttons
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'دردشة',
                  enabled: canChat,
                  filled: false,
                  onTap: onChat,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: Icons.call_rounded,
                  label: 'اتصال',
                  enabled: canCall,
                  filled: true,
                  onTap: onCall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final bool filled;
  final VoidCallback onTap;

  static const Color _primary = AppThemeArabic.clientPrimary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: !enabled
              ? Colors.grey[100]
              : filled
                  ? _primary
                  : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: filled
              ? null
              : Border.all(color: enabled ? _primary : Colors.grey[300]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: !enabled
                    ? Colors.grey[400]
                    : filled
                        ? Colors.white
                        : _primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: !enabled
                    ? Colors.grey[400]
                    : filled
                        ? Colors.white
                        : _primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
