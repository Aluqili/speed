import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:getwidget/getwidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import '../helpers/smart_location_tracker.dart';
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
  State<CourierGoToClientScreen> createState() => _CourierGoToClientScreenState();
}

class _CourierGoToClientScreenState extends State<CourierGoToClientScreen> {
  SmartLocationTracker? tracker;

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
    tracker?.stopTracking();
    super.dispose();
  }

  Future<void> _openGoogleMaps() async {
    if (widget.clientLocation == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد موقع عميل في هذا الطلب لفتحه على الخرائط')),
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

  Future<Map<String, dynamic>?> _fetchOrderData() async {
    final doc = await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).get();
    if (!doc.exists) return null;

    final data = Map<String, dynamic>.from(doc.data()!);
    final clientId = (data['clientId'] ?? '').toString();
    final hasClientName = (data['clientName'] ?? '').toString().trim().isNotEmpty;

    if (clientId.isNotEmpty && !hasClientName) {
      DocumentSnapshot<Map<String, dynamic>>? clientDoc;
      final directClientDoc =
          await FirebaseFirestore.instance.collection('clients').doc(clientId).get();
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
        final clientName =
            (clientData['name'] ?? clientData['fullName'] ?? '').toString().trim();
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
    final totalWithDelivery = (orderData['totalWithDelivery'] ?? orderData['total'] ?? 0).toString();

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
          _detailRow('رقم الطلب', (orderData['orderId'] ?? widget.orderId).toString()),
          _detailRow('العميل', (orderData['clientName'] ?? 'غير معروف').toString()),
          _detailRow('المطعم', (orderData['restaurantName'] ?? 'غير معروف').toString()),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeArabic.clientBackground,
      appBar: AppBar(
        title: const Text('الذهاب إلى العميل', style: TextStyle(color: AppThemeArabic.clientPrimary, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Tajawal')),
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

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildOrderDetails(orderData),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppThemeArabic.clientSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: AppThemeArabic.clientPrimary, size: 28),
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
              if (widget.clientLocation != null)
                SizedBox(
                  height: 240,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: widget.clientLocation!,
                      zoom: 15,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('client'),
                        position: widget.clientLocation!,
                        infoWindow: const InfoWindow(title: 'موقع العميل'),
                      ),
                    },
                    zoomControlsEnabled: false,
                    gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                      Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                    },
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
              GFButton(
                onPressed: _openGoogleMaps,
                text: 'افتح في خرائط Google',
                icon: const Icon(Icons.map_outlined),
                color: AppThemeArabic.clientPrimary,
                shape: GFButtonShape.pills,
                fullWidthButton: true,
                size: GFSize.LARGE,
                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
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
                text: 'وصلت إلى العميل',
                icon: const Icon(Icons.check_circle),
                color: AppThemeArabic.clientPrimary,
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
