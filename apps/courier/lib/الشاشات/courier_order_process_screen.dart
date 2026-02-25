import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

import 'courier_confirm_delivery_screen.dart';
import 'courier_go_to_client_screen.dart';
import 'courier_go_to_restaurant_screen.dart';

class CourierOrderProcessScreen extends StatefulWidget {
  final String orderId;
  final String stage;
  const CourierOrderProcessScreen({
    Key? key,
    required this.orderId,
    required this.stage,
  }) : super(key: key);

  @override
  State<CourierOrderProcessScreen> createState() =>
      _CourierOrderProcessScreenState();
}

class _CourierOrderProcessScreenState extends State<CourierOrderProcessScreen> {
  bool _navigated = false;
  String? _routeError;

  String _statusFromData(Map<String, dynamic> data) {
    return (data['orderStatus'] ?? data['status'] ?? '').toString();
  }

  String _stageFromStatus(String status) {
    switch (status) {
      case 'courier_assigned':
      case 'pickup_ready':
      case 'جاهز للتوصيل':
        return 'going_to_restaurant';
      case 'picked_up':
      case 'قيد التوصيل':
        return 'going_to_client';
      case 'arrived_to_client':
      case 'وصل إلى العميل':
        return 'arrived_to_client';
      default:
        return widget.stage;
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _fetchOrder() {
    return FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .get();
  }

  void _goToStage(Map<String, dynamic> data, String stage) {
    if (_navigated || !mounted) return;
    _navigated = true;

    final box = GetStorage();
    box.write('current_order', {
      'orderId': widget.orderId,
      'stage': stage,
    });

    if (stage == 'going_to_restaurant') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CourierGoToRestaurantScreen(
            orderId: widget.orderId,
            driverId: (data['assignedDriverId'] ?? '').toString(),
          ),
        ),
      );
      return;
    }

    if (stage == 'going_to_client') {
      final clientLocationRaw = data['clientLocation'];
      final clientLat = (data['clientLat'] as num?)?.toDouble() ??
        (clientLocationRaw is GeoPoint
          ? clientLocationRaw.latitude
          : (clientLocationRaw is Map<String, dynamic>
            ? (clientLocationRaw['lat'] as num?)?.toDouble() ??
              (clientLocationRaw['latitude'] as num?)?.toDouble()
            : null));
      final clientLng = (data['clientLng'] as num?)?.toDouble() ??
        (clientLocationRaw is GeoPoint
          ? clientLocationRaw.longitude
          : (clientLocationRaw is Map<String, dynamic>
            ? (clientLocationRaw['lng'] as num?)?.toDouble() ??
              (clientLocationRaw['longitude'] as num?)?.toDouble()
            : null));
      final LatLng? clientLocation =
          (clientLat != null && clientLng != null) ? LatLng(clientLat, clientLng) : null;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CourierGoToClientScreen(
            orderId: widget.orderId,
            clientLocation: clientLocation,
            driverId: (data['assignedDriverId'] ?? '').toString(),
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CourierConfirmDeliveryScreen(
          orderId: widget.orderId,
          driverId: (data['assignedDriverId'] ?? '').toString(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeArabic.clientBackground,
      appBar: AppBar(
        title: const Text('متابعة الطلب الحالي', style: TextStyle(color: AppThemeArabic.clientPrimary, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Tajawal')),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 1,
        iconTheme: const IconThemeData(color: AppThemeArabic.clientPrimary),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
        ),
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _fetchOrder(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final doc = snapshot.data!;
          if (!doc.exists) {
            GetStorage().remove('current_order');
            return const Center(child: Text('الطلب غير موجود.'));
          }

          final data = doc.data() ?? <String, dynamic>{};
          final status = _statusFromData(data);

          if (_routeError != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange, size: 52),
                    const SizedBox(height: 12),
                    Text(
                      _routeError!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('العودة'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (status == 'delivered' || status == 'تم التوصيل') {
            GetStorage().remove('current_order');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 56),
                    const SizedBox(height: 12),
                    const Text('تم إنهاء هذا الطلب بالفعل'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('العودة'),
                    ),
                  ],
                ),
              ),
            );
          }

          final stage = _stageFromStatus(status);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _goToStage(data, stage);
          });

          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
