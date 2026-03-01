import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:math';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'package:speedstar_core/speedstar_core.dart'
    show formatUnifiedOrderCode, OrderStatusPalette;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'chat_screen.dart' show ChatScreen;
import 'courier_go_to_restaurant_screen.dart';
import 'courier_go_to_client_screen.dart';
import 'courier_confirm_delivery_screen.dart';

class CourierOrderDetailsScreen extends StatefulWidget {
  final String orderId;
  final String driverId;

  const CourierOrderDetailsScreen({
    Key? key,
    required this.orderId,
    required this.driverId,
  }) : super(key: key);

  @override
  State<CourierOrderDetailsScreen> createState() =>
      _CourierOrderDetailsScreenState();
}

class _CourierOrderDetailsScreenState extends State<CourierOrderDetailsScreen> {
  Map<String, dynamic>? orderData;
  double deliveryFee = 0;

  String _getOrderStatus(Map<String, dynamic> data) {
    return (data['orderStatus'] ?? data['status'] ?? '').toString().trim();
  }

  @override
  void initState() {
    super.initState();
    _loadOrderData();
  }

  Future<void> _loadOrderData() async {
    final docSnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .get();

    if (docSnapshot.exists) {
      final data = docSnapshot.data()!;
      final assignedDriverId = (data['assignedDriverId'] ?? '').toString();
      final offeredDriverId = (data['offeredDriverId'] ?? '').toString();
      final status = _getOrderStatus(data);

      final belongsToAnotherAssigned =
          assignedDriverId.isNotEmpty && assignedDriverId != widget.driverId;
      final belongsToAnotherOffer = status == 'courier_offer_pending' &&
          offeredDriverId.isNotEmpty &&
          offeredDriverId != widget.driverId;

      if (belongsToAnotherAssigned || belongsToAnotherOffer) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('تم استلام هذا الطلب بواسطة مندوب آخر')),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      if (data['restaurantLat'] != null &&
          data['restaurantLng'] != null &&
          data['clientLat'] != null &&
          data['clientLng'] != null) {
        double distanceInKm = _calculateDistance(
          data['restaurantLat'],
          data['restaurantLng'],
          data['clientLat'],
          data['clientLng'],
        );
        deliveryFee = 700 + (distanceInKm * 100).roundToDouble();
      }

      try {
        final driverDoc = await FirebaseFirestore.instance
            .collection('drivers')
            .doc(widget.driverId)
            .get();
        final driverData = driverDoc.data() ?? <String, dynamic>{};
        final loc = driverData['location'];
        if (loc is GeoPoint) {
          data['driverLat'] = loc.latitude;
          data['driverLng'] = loc.longitude;
        } else if (loc is Map<String, dynamic>) {
          data['driverLat'] = (loc['lat'] as num?)?.toDouble() ??
              (loc['latitude'] as num?)?.toDouble();
          data['driverLng'] = (loc['lng'] as num?)?.toDouble() ??
              (loc['longitude'] as num?)?.toDouble();
        }
      } catch (_) {}

      setState(() {
        orderData = data;
      });
    }
  }

  double _calculateDistance(
      double lat1, double lng1, double lat2, double lng2) {
    const double R = 6371;
    double dLat = _deg2rad(lat2 - lat1);
    double dLon = _deg2rad(lng2 - lng1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180);

  Future<void> _acceptOrder() async {
    if (orderData == null) return;

    final status = _getOrderStatus(orderData!);
    final offeredDriverId = (orderData!['offeredDriverId'] ?? '').toString();
    if (status != 'courier_offer_pending' ||
        offeredDriverId != widget.driverId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذا العرض غير متاح لك الآن')),
      );
      return;
    }

    await FirebaseFunctions.instanceFor(region: 'me-central1')
        .httpsCallable('courierRespondToOffer')
        .call({
      'orderId': widget.orderId,
      'driverId': widget.driverId,
      'decision': 'accept',
    });

    await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .update({
      'deliveryFeeForDriver': deliveryFee,
      'acceptedAt': Timestamp.now(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم قبول الطلب')),
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CourierGoToRestaurantScreen(
          orderId: widget.orderId,
          driverId: widget.driverId,
        ),
      ),
    );
  }

  LatLng? _resolvePoint(
    Map<String, dynamic> data, {
    required String rawKey,
    required String latKey,
    required String lngKey,
  }) {
    final raw = data[rawKey];
    if (raw is GeoPoint) return LatLng(raw.latitude, raw.longitude);
    if (raw is Map<String, dynamic>) {
      final lat = (raw['lat'] as num?)?.toDouble() ??
          (raw['latitude'] as num?)?.toDouble();
      final lng = (raw['lng'] as num?)?.toDouble() ??
          (raw['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    final lat = (data[latKey] as num?)?.toDouble();
    final lng = (data[lngKey] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  Future<void> _openProfessionalFlow() async {
    if (orderData == null || !mounted) return;
    final status = _getOrderStatus(orderData!);
    final clientLoc = _resolvePoint(
      orderData!,
      rawKey: 'clientLocation',
      latKey: 'clientLat',
      lngKey: 'clientLng',
    );

    if (status == 'courier_assigned' ||
        status == 'pickup_ready' ||
        status == 'جاهز للتوصيل') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CourierGoToRestaurantScreen(
            orderId: widget.orderId,
            driverId: widget.driverId,
          ),
        ),
      );
      return;
    }

    if (status == 'picked_up' || status == 'قيد التوصيل') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CourierGoToClientScreen(
            orderId: widget.orderId,
            clientLocation: clientLoc,
            driverId: widget.driverId,
          ),
        ),
      );
      return;
    }

    if (status == 'arrived_to_client' || status == 'وصل إلى العميل') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CourierConfirmDeliveryScreen(
            orderId: widget.orderId,
            driverId: widget.driverId,
          ),
        ),
      );
    }
  }

  Future<void> _rejectOffer() async {
    await FirebaseFunctions.instanceFor(region: 'me-central1')
        .httpsCallable('courierRespondToOffer')
        .call({
      'orderId': widget.orderId,
      'driverId': widget.driverId,
      'decision': 'reject',
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم رفض العرض وسيتم إرساله لمندوب آخر')),
    );
    Navigator.pop(context);
  }

  String _generateChatId(String user1, String user2) {
    final ids = [user1, user2]..sort();
    return ids.join('_');
  }

  bool _isOrderFinished(String status) {
    final normalized = status.trim().toLowerCase();
    return normalized == 'delivered' ||
        normalized == 'cancelled' ||
        normalized == 'store_rejected' ||
        status.trim() == 'تم التوصيل' ||
        status.trim() == 'ملغي';
  }

  @override
  Widget build(BuildContext context) {
    final data = orderData;
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الطلب',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppThemeArabic.clientPrimary,
                fontFamily: 'Tajawal',
                fontSize: 20)),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppThemeArabic.clientPrimary),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
        ),
      ),
      backgroundColor: AppThemeArabic.clientBackground,
      body: data == null
          ? const Center(child: CircularProgressIndicator())
          : Builder(builder: (context) {
              final status = _getOrderStatus(data);
              final clientId = (data['clientId'] ?? '').toString().trim();
              final isFinished = _isOrderFinished(status);
              final isOfferForMe = status == 'courier_offer_pending' &&
                  (data['offeredDriverId'] ?? '').toString() == widget.driverId;

              final restaurantLocation = _resolvePoint(
                data,
                rawKey: 'restaurantLocation',
                latKey: 'restaurantLat',
                lngKey: 'restaurantLng',
              );
              final clientLocation = _resolvePoint(
                data,
                rawKey: 'clientLocation',
                latKey: 'clientLat',
                lngKey: 'clientLng',
              );
              final driverLocation = _resolvePoint(
                data,
                rawKey: 'driverLocation',
                latKey: 'driverLat',
                lngKey: 'driverLng',
              );

              final restaurantToClientKm =
                  (restaurantLocation != null && clientLocation != null)
                      ? _calculateDistance(
                          restaurantLocation.latitude,
                          restaurantLocation.longitude,
                          clientLocation.latitude,
                          clientLocation.longitude,
                        )
                      : null;

              final driverToRestaurantKm =
                  (driverLocation != null && restaurantLocation != null)
                      ? _calculateDistance(
                          driverLocation.latitude,
                          driverLocation.longitude,
                          restaurantLocation.latitude,
                          restaurantLocation.longitude,
                        )
                      : null;

              final markers = <Marker>{
                if (restaurantLocation != null)
                  Marker(
                    markerId: const MarkerId('restaurant'),
                    position: restaurantLocation,
                    infoWindow: const InfoWindow(title: 'المطعم'),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueOrange),
                  ),
                if (clientLocation != null)
                  Marker(
                    markerId: const MarkerId('client'),
                    position: clientLocation,
                    infoWindow: const InfoWindow(title: 'العميل'),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueAzure),
                  ),
                if (driverLocation != null)
                  Marker(
                    markerId: const MarkerId('driver'),
                    position: driverLocation,
                    infoWindow: const InfoWindow(title: 'موقعك'),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueGreen),
                  ),
              };

              final polylines = <Polyline>{
                if (restaurantLocation != null && clientLocation != null)
                  Polyline(
                    polylineId: const PolylineId('restaurant_client'),
                    points: [restaurantLocation, clientLocation],
                    color: AppThemeArabic.clientPrimary,
                    width: 5,
                  ),
              };

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatUnifiedOrderCode(
                            orderNumber: data['orderNumber'],
                            orderId: data['orderId'],
                            docId: widget.orderId,
                          ),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppThemeArabic.clientPrimary,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'العميل: ${data['clientName'] ?? 'غير متوفر'}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Tajawal'),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color:
                                OrderStatusPalette.backgroundForStatus(status),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'الحالة: ${OrderStatusPalette.displayText(status)}',
                            style: TextStyle(
                              color: OrderStatusPalette.colorForStatus(status),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (markers.length >= 2)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: SizedBox(
                              height: 250,
                              child: GoogleMap(
                                initialCameraPosition: CameraPosition(
                                  target: restaurantLocation ?? clientLocation!,
                                  zoom: 12.5,
                                ),
                                markers: markers,
                                polylines: polylines,
                                zoomControlsEnabled: false,
                                myLocationButtonEnabled: false,
                              ),
                            ),
                          )
                        else
                          const Text('لا توجد بيانات موقع كافية لعرض الخريطة'),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (driverToRestaurantKm != null)
                              Chip(
                                label: Text(
                                  'يبعد المطعم عنك: ${driverToRestaurantKm.toStringAsFixed(1)} كم',
                                ),
                              ),
                            if (restaurantToClientKm != null)
                              Chip(
                                label: Text(
                                  'يبعد العميل عن المطعم: ${restaurantToClientKm.toStringAsFixed(1)} كم',
                                ),
                              ),
                            Chip(
                                label: Text(
                                    'رسومك: ${deliveryFee.toStringAsFixed(0)} ج.س')),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isOfferForMe) ...[
                    ElevatedButton.icon(
                      onPressed: _acceptOrder,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('قبول العرض وبدء الرحلة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppThemeArabic.clientSuccess,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _rejectOffer,
                      icon: const Icon(Icons.close),
                      label: const Text('رفض العرض'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ] else if ((data['assignedDriverId'] ?? '').toString() ==
                      widget.driverId) ...[
                    ElevatedButton.icon(
                      onPressed: _openProfessionalFlow,
                      icon: const Icon(Icons.navigation_outlined),
                      label: const Text('فتح شاشة التنفيذ الاحترافية'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppThemeArabic.clientPrimary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ] else
                    const Center(
                      child: Text('هذا الطلب تم استلامه بواسطة مندوب آخر.'),
                    ),
                  const SizedBox(height: 14),
                  if (!isFinished && clientId.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () async {
                        final doc = await FirebaseFirestore.instance
                            .collection('drivers')
                            .doc(widget.driverId)
                            .get();
                        final driverName = doc.data()?['name'] ?? 'مندوب';
                        final chatId =
                            _generateChatId(widget.driverId, clientId);
                        if (!mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              currentUserId: widget.driverId,
                              otherUserId: clientId,
                              currentUserRole: 'driver',
                              chatId: chatId,
                              currentUserName: driverName,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('الدردشة مع العميل'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppThemeArabic.clientAccent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                ],
              );
            }),
    );
  }
}
