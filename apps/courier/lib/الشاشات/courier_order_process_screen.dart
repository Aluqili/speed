import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:speedstar_core/speedstar_core.dart' show OrderStatusPalette;
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

import 'courier_confirm_delivery_screen.dart';
import 'courier_go_to_client_screen.dart';
import 'courier_go_to_restaurant_screen.dart';
import 'courier_ui.dart';

class CourierOrderProcessScreen extends StatefulWidget {
  final String orderId;
  final String stage;
  const CourierOrderProcessScreen({
    super.key,
    required this.orderId,
    required this.stage,
  });

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

  String _stageLabel(String stage) {
    switch (stage) {
      case 'going_to_restaurant':
        return 'التوجه إلى نقطة الاستلام';
      case 'going_to_client':
        return 'التوجه إلى العميل';
      case 'arrived_to_client':
        return 'إثبات التسليم';
      default:
        return 'متابعة الطلب';
    }
  }

  Widget _buildCenteredState({
    required IconData icon,
    required String title,
    required String message,
    Color iconColor = AppThemeArabic.courierPrimary,
    String actionLabel = 'العودة',
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: iconColor.withValues(alpha: 0.12),
                child: Icon(icon, color: iconColor, size: 34),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: AppThemeArabic.courierTextPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 14,
                  color: AppThemeArabic.courierTextSecondary,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeArabic.courierPrimary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(actionLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      final LatLng? clientLocation = (clientLat != null && clientLng != null)
          ? LatLng(clientLat, clientLng)
          : null;

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
      backgroundColor: Colors.transparent,
      appBar: buildCourierAppBar('مسار الطلب'),
      body: CourierPageBackground(
        child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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
              return _buildCenteredState(
                icon: Icons.warning_amber_rounded,
                title: 'تعذر فتح مرحلة التنفيذ',
                message: _routeError!,
                iconColor: OrderStatusPalette.pending,
              );
            }

            if (status == 'delivered' || status == 'تم التوصيل') {
              GetStorage().remove('current_order');
              return _buildCenteredState(
                icon: Icons.check_circle,
                title: 'تم إنهاء هذا الطلب بالفعل',
                message:
                    'تم تسليم الطلب أو إغلاقه، ولن تظهر لك مرحلة تنفيذ جديدة له.',
                iconColor: OrderStatusPalette.delivered,
              );
            }

            final stage = _stageFromStatus(status);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _goToStage(data, stage);
            });

            return Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppThemeArabic.courierPrimary.withValues(alpha: 0.10),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'جار فتح ${_stageLabel(stage)}...',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.w800,
                          color: AppThemeArabic.courierTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}


