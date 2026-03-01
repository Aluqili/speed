import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:getwidget/getwidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'package:speedstar_core/speedstar_core.dart' show formatUnifiedOrderCode;
import '../helpers/smart_location_tracker.dart';
import 'chat_screen.dart';
import 'courier_confirm_delivery_screen.dart';

class CourierGoToClientScreen extends StatefulWidget {
  final String orderId;
  final LatLng? clientLocation;
  final String driverId;

  const CourierGoToClientScreen({
    Key? key,
    required this.orderId,
    this.clientLocation,
    required this.driverId,
  }) : super(key: key);

  @override
  State<CourierGoToClientScreen> createState() =>
      _CourierGoToClientScreenState();
}

class _CourierGoToClientScreenState extends State<CourierGoToClientScreen> {
  SmartLocationTracker? tracker;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    final box = GetStorage();
    box.write('current_order', {
      'orderId': widget.orderId,
      'stage': 'going_to_client',
    });
    if (widget.clientLocation != null) {
      tracker = SmartLocationTracker(
        driverId: widget.driverId,
        orderId: widget.orderId,
        clientLocation: widget.clientLocation!,
      );
      tracker!.startTracking();
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    tracker?.stopTracking();
    super.dispose();
  }

  Future<void> _openGoogleMaps() async {
    if (widget.clientLocation == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('لا يوجد موقع عميل في هذا الطلب لفتحه على الخرائط')),
      );
      return;
    }
    final clientLocation = widget.clientLocation!;
    final Uri url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${clientLocation.latitude},${clientLocation.longitude}&travelmode=driving',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تعذر فتح خرائط Google على هذا الجهاز')),
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

  void _fitCameraToPoints(List<LatLng> points) {
    if (_mapController == null || points.isEmpty) return;
    if (points.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
            CameraPosition(target: points.first, zoom: 15)),
      );
      return;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
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

  Future<Map<String, dynamic>?> _fetchOrderData() async {
    final doc = await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .get();
    if (!doc.exists) return null;

    final data = Map<String, dynamic>.from(doc.data()!);
    final clientId = (data['clientId'] ?? '').toString();
    final hasClientName =
        (data['clientName'] ?? '').toString().trim().isNotEmpty;

    if (clientId.isNotEmpty && !hasClientName) {
      DocumentSnapshot<Map<String, dynamic>>? clientDoc;
      final directClientDoc = await FirebaseFirestore.instance
          .collection('clients')
          .doc(clientId)
          .get();
      if (directClientDoc.exists) {
        clientDoc = directClientDoc;
      } else {
        final byOwner = await FirebaseFirestore.instance
            .collection('clients')
            .where('ownerUid', isEqualTo: clientId)
            .limit(1)
            .get();
        if (byOwner.docs.isNotEmpty) {
          clientDoc = byOwner.docs.first;
        } else {
          final byUid = await FirebaseFirestore.instance
              .collection('clients')
              .where('uid', isEqualTo: clientId)
              .limit(1)
              .get();
          if (byUid.docs.isNotEmpty) {
            clientDoc = byUid.docs.first;
          } else {
            final byUserId = await FirebaseFirestore.instance
                .collection('clients')
                .where('userId', isEqualTo: clientId)
                .limit(1)
                .get();
            if (byUserId.docs.isNotEmpty) {
              clientDoc = byUserId.docs.first;
            }
          }
        }
      }

      if (clientDoc != null && clientDoc.exists) {
        final clientData = clientDoc.data() ?? <String, dynamic>{};
        final clientName = (clientData['name'] ?? clientData['fullName'] ?? '')
            .toString()
            .trim();
        if (clientName.isNotEmpty) {
          data['clientName'] = clientName;
        }
        if ((data['clientPhone'] ?? '').toString().trim().isEmpty) {
          final clientPhone =
              (clientData['phone'] ?? clientData['phoneNumber'] ?? '')
                  .toString()
                  .trim();
          if (clientPhone.isNotEmpty) {
            data['clientPhone'] = clientPhone;
          }
        }
      }
    }

    return data;
  }

  String _generateChatId(String user1, String user2) {
    final sorted = [user1, user2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Future<void> _openClientChat(Map<String, dynamic> orderData) async {
    final clientId = (orderData['clientId'] ?? '').toString().trim();
    if (clientId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('لا يمكن فتح الدردشة لعدم توفر معرف العميل')),
      );
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('drivers')
        .doc(widget.driverId)
        .get();
    final driverName = (doc.data()?['name'] ?? 'مندوب').toString();

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          currentUserId: widget.driverId,
          otherUserId: clientId,
          currentUserRole: 'driver',
          chatId: _generateChatId(widget.driverId, clientId),
          currentUserName: driverName,
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetails(Map<String, dynamic> orderData) {
    final items = (orderData['items'] as List?) ?? const [];
    final paymentMethod = (orderData['paymentMethod'] ?? 'غير محدد').toString();
    final totalWithDelivery =
        (orderData['totalWithDelivery'] ?? orderData['total'] ?? 0).toString();

    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        title: const Text(
          'تفاصيل الطلب',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        collapsedTextColor: Colors.black87,
        textColor: Colors.black87,
        iconColor: Colors.black87,
        collapsedIconColor: Colors.black87,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _detailRow(
            'رقم الطلب',
            formatUnifiedOrderCode(
              orderNumber: orderData['orderNumber'],
              orderId: orderData['orderId'],
              docId: widget.orderId,
            ),
          ),
          _detailRow(
              'العميل', (orderData['clientName'] ?? 'غير معروف').toString()),
          _detailRow('المطعم',
              (orderData['restaurantName'] ?? 'غير معروف').toString()),
          _detailRow('طريقة الدفع', paymentMethod),
          _detailRow('الإجمالي', '$totalWithDelivery ج.س'),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'العناصر',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
          const SizedBox(height: 6),
          if (items.isEmpty)
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'لا توجد عناصر',
                style: TextStyle(color: Colors.black87),
              ),
            )
          else
            ...items.map((item) {
              final map = (item is Map<String, dynamic>)
                  ? item
                  : Map<String, dynamic>.from(item as Map);
              final name = (map['name'] ?? 'عنصر').toString();
              final qty = (map['quantity'] ?? 1).toString();
              return Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '• $name × $qty',
                  style: const TextStyle(color: Colors.black87),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildJourneyHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppThemeArabic.clientPrimary.withOpacity(0.12),
            child: Icon(icon, color: AppThemeArabic.clientPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeArabic.clientBackground,
      appBar: AppBar(
        title: const Text('الذهاب إلى العميل',
            style: TextStyle(
                color: AppThemeArabic.clientPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                fontFamily: 'Tajawal')),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppThemeArabic.clientPrimary),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _fetchOrderData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: Text(
                'الطلب غير موجود أو تعذر تحميل بياناته',
                style: TextStyle(color: Colors.black87),
              ),
            );
          }

          final orderData = snapshot.data!;
          final String clientName = orderData['clientName'] ?? 'عميل غير معروف';
          final clientLocation = _resolvePoint(
                orderData,
                rawKey: 'clientLocation',
                latKey: 'clientLat',
                lngKey: 'clientLng',
              ) ??
              widget.clientLocation;
          final restaurantLocation = _resolvePoint(
            orderData,
            rawKey: 'restaurantLocation',
            latKey: 'restaurantLat',
            lngKey: 'restaurantLng',
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildJourneyHeader(
                title: 'المرحلة 2 من 3 · التوجه للعميل',
                subtitle: 'تابع الملاحة حتى تصل، ثم أكّد الوصول للعميل',
                icon: Icons.home_work_outlined,
              ),
              const SizedBox(height: 12),
              _buildOrderDetails(orderData),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openClientChat(orderData),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('الدردشة مع العميل'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeArabic.clientAccent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppThemeArabic.clientSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person,
                        color: AppThemeArabic.clientPrimary, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        clientName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (clientLocation != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 260,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: clientLocation,
                        zoom: restaurantLocation == null ? 15 : 12,
                      ),
                      markers: {
                        Marker(
                          markerId: const MarkerId('client'),
                          position: clientLocation,
                          infoWindow: const InfoWindow(title: '🏠 موقع العميل'),
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueGreen,
                          ),
                        ),
                        if (restaurantLocation != null)
                          Marker(
                            markerId: const MarkerId('restaurant'),
                            position: restaurantLocation,
                            infoWindow: const InfoWindow(title: '🍽️ المطعم'),
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueRed,
                            ),
                          ),
                      },
                      polylines: restaurantLocation == null
                          ? const {}
                          : {
                              Polyline(
                                polylineId:
                                    const PolylineId('restaurant_client'),
                                points: [restaurantLocation, clientLocation],
                                color: AppThemeArabic.clientPrimary,
                                width: 4,
                              ),
                            },
                      onMapCreated: (controller) {
                        _mapController = controller;
                        final points = <LatLng>[
                          clientLocation,
                          if (restaurantLocation != null) restaurantLocation,
                        ];
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _fitCameraToPoints(points);
                        });
                      },
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
                      gestureRecognizers: <Factory<
                          OneSequenceGestureRecognizer>>{
                        Factory<OneSequenceGestureRecognizer>(
                            () => EagerGestureRecognizer()),
                      },
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'لا توجد إحداثيات لموقع العميل في هذا الطلب، يمكنك المتابعة يدويًا.',
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.center,
                child: Material(
                  color: AppThemeArabic.clientPrimary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _openGoogleMaps,
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Icon(
                        Icons.navigation_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              GFButton(
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('orders')
                      .doc(widget.orderId)
                      .update({
                    'orderStatus': 'arrived_to_client',
                    'status': 'arrived_to_client',
                    'arrivedToClientAt': FieldValue.serverTimestamp(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  final box = GetStorage();
                  box.write('current_order', {
                    'orderId': widget.orderId,
                    'stage': 'arrived_to_client',
                  });

                  if (!context.mounted) return;
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => CourierConfirmDeliveryScreen(
                        orderId: widget.orderId,
                        driverId: widget.driverId,
                      ),
                    ),
                  );
                },
                text: 'تأكيد الوصول للعميل',
                icon: const Icon(Icons.check_circle),
                color: AppThemeArabic.clientSuccess,
                shape: GFButtonShape.pills,
                fullWidthButton: true,
                size: GFSize.LARGE,
                textStyle:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          );
        },
      ),
    );
  }
}
