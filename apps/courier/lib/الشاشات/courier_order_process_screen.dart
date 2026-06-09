import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:speedstar_core/speedstar_core.dart'
    show OrderStatusPalette, formatUnifiedOrderCode;
import 'package:speedstar_core/Ø§Ù„Ø«ÙŠÙ…/Ø«ÙŠÙ…_Ø§Ù„ØªØ·Ø¨ÙŠÙ‚.dart';

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

  static const List<String> _stageFlow = <String>[
    'going_to_restaurant',
    'going_to_client',
    'arrived_to_client',
  ];

  String _statusFromData(Map<String, dynamic> data) {
    return (data['orderStatus'] ?? data['status'] ?? '').toString();
  }

  String _stageFromStatus(String status) {
    switch (status) {
      case 'courier_assigned':
      case 'pickup_ready':
      case 'Ø¬Ø§Ù‡Ø² Ù„Ù„ØªÙˆØµÙŠÙ„':
        return 'going_to_restaurant';
      case 'picked_up':
      case 'Ù‚ÙŠØ¯ Ø§Ù„ØªÙˆØµÙŠÙ„':
        return 'going_to_client';
      case 'arrived_to_client':
      case 'ÙˆØµÙ„ Ø¥Ù„Ù‰ Ø§Ù„Ø¹Ù…ÙŠÙ„':
        return 'arrived_to_client';
      default:
        return widget.stage;
    }
  }

  String _stageLabel(String stage) {
    switch (stage) {
      case 'going_to_restaurant':
        return 'Ø§Ù„ØªÙˆØ¬Ù‡ Ø¥Ù„Ù‰ Ø§Ù„Ù…Ø·Ø¹Ù…';
      case 'going_to_client':
        return 'Ø§Ù„ØªÙˆØ¬Ù‡ Ø¥Ù„Ù‰ Ø§Ù„Ø¹Ù…ÙŠÙ„';
      case 'arrived_to_client':
        return 'Ø¥Ø«Ø¨Ø§Øª Ø§Ù„ØªØ³Ù„ÙŠÙ…';
      default:
        return 'Ù…ØªØ§Ø¨Ø¹Ø© Ø§Ù„Ø·Ù„Ø¨';
    }
  }

  String _stageDescription(String stage) {
    switch (stage) {
      case 'going_to_restaurant':
        return 'ØªØ¬Ù‡ÙŠØ² Ø§Ù„Ù…Ù„Ø§Ø­Ø© ÙˆØ§Ù„ÙˆØµÙˆÙ„ Ø¥Ù„Ù‰ Ø§Ù„Ù…Ø·Ø¹Ù… Ù„Ø§Ø³ØªÙ„Ø§Ù… Ø§Ù„Ø·Ù„Ø¨.';
      case 'going_to_client':
        return 'Ø¹Ø±Ø¶ Ø®Ø· Ø§Ù„Ø³ÙŠØ± Ø¥Ù„Ù‰ Ø§Ù„Ø¹Ù…ÙŠÙ„ ÙˆØªØ­Ø¯ÙŠØ« Ø§Ù„Ø±Ø­Ù„Ø© Ø¨Ø´ÙƒÙ„ Ù…Ø¨Ø§Ø´Ø±.';
      case 'arrived_to_client':
        return 'Ø§Ù„ØªØ£ÙƒØ¯ Ù…Ù† Ø¨ÙŠØ§Ù†Ø§Øª Ø§Ù„Ø¹Ù…ÙŠÙ„ ÙˆØ¥ØªÙ…Ø§Ù… Ø§Ù„ØªØ³Ù„ÙŠÙ… Ø¨Ù†Ø¬Ø§Ø­.';
      default:
        return 'Ø¬Ø§Ø± ØªØ¬Ù‡ÙŠØ² ØªÙØ§ØµÙŠÙ„ Ø§Ù„Ø±Ø­Ù„Ø© Ø§Ù„Ø­Ø§Ù„ÙŠØ©.';
    }
  }

  IconData _stageIcon(String stage) {
    switch (stage) {
      case 'going_to_restaurant':
        return Icons.storefront_rounded;
      case 'going_to_client':
        return Icons.route_rounded;
      case 'arrived_to_client':
        return Icons.verified_rounded;
      default:
        return Icons.delivery_dining_rounded;
    }
  }

  int _stageIndex(String stage) {
    final index = _stageFlow.indexOf(stage);
    return index == -1 ? 0 : index;
  }

  Widget _buildCenteredState({
    required IconData icon,
    required String title,
    required String message,
    Color iconColor = AppThemeArabic.courierPrimary,
    String actionLabel = 'Ø§Ù„Ø¹ÙˆØ¯Ø©',
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
      ),
      ),
    );
  }

  Widget _buildStageTimeline(String currentStage) {
    final activeIndex = _stageIndex(currentStage);
    return Column(
      children: List.generate(_stageFlow.length, (index) {
        final stage = _stageFlow[index];
        final isActive = index == activeIndex;
        final isCompleted = index < activeIndex;
        final markerColor = isCompleted || isActive
            ? AppThemeArabic.courierPrimary
            : AppThemeArabic.courierTextSecondary.withValues(alpha: 0.35);

        return Padding(
          padding:
              EdgeInsets.only(bottom: index == _stageFlow.length - 1 ? 0 : 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: (isCompleted || isActive)
                          ? markerColor.withValues(alpha: 0.12)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: markerColor, width: 1.4),
                    ),
                    child: Icon(
                      isCompleted ? Icons.check_rounded : _stageIcon(stage),
                      color: markerColor,
                      size: 20,
                    ),
                  ),
                  if (index != _stageFlow.length - 1)
                    Container(
                      width: 2,
                      height: 28,
                      color: isCompleted
                          ? AppThemeArabic.courierPrimary
                              .withValues(alpha: 0.45)
                          : AppThemeArabic.courierTextSecondary
                              .withValues(alpha: 0.18),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _stageLabel(stage),
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontWeight:
                              isActive ? FontWeight.w800 : FontWeight.w700,
                          fontSize: 15,
                          color: isActive
                              ? AppThemeArabic.courierTextPrimary
                              : AppThemeArabic.courierTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _stageDescription(stage),
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 13,
                          color: AppThemeArabic.courierTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
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
            return const Center(child: Text('Ø§Ù„Ø·Ù„Ø¨ ØºÙŠØ± Ù…ÙˆØ¬ÙˆØ¯.'));
          }

          final data = doc.data() ?? <String, dynamic>{};
          final status = _statusFromData(data);

          if (_routeError != null) {
            return _buildCenteredState(
              icon: Icons.warning_amber_rounded,
              title: 'ØªØ¹Ø°Ø± ÙØªØ­ Ù…Ø±Ø­Ù„Ø© Ø§Ù„ØªÙ†ÙÙŠØ°',
              message: _routeError!,
              iconColor: OrderStatusPalette.pending,
            );
          }

          if (status == 'delivered' || status == 'ØªÙ… Ø§Ù„ØªÙˆØµÙŠÙ„') {
            GetStorage().remove('current_order');
            return _buildCenteredState(
              icon: Icons.check_circle,
              title: 'ØªÙ… Ø¥Ù†Ù‡Ø§Ø¡ Ù‡Ø°Ø§ Ø§Ù„Ø·Ù„Ø¨ Ø¨Ø§Ù„ÙØ¹Ù„',
              message:
                  'ØªÙ… ØªØ³Ù„ÙŠÙ… Ø§Ù„Ø·Ù„Ø¨ Ø£Ùˆ Ø¥ØºÙ„Ø§Ù‚Ù‡ØŒ ÙˆÙ„Ù† ØªØ¸Ù‡Ø± Ù„Ùƒ Ù…Ø±Ø­Ù„Ø© ØªÙ†ÙÙŠØ° Ø¬Ø¯ÙŠØ¯Ø© Ù„Ù‡.',
              iconColor: OrderStatusPalette.delivered,
            );
          }

          final stage = _stageFromStatus(status);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _goToStage(data, stage);
          });

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppThemeArabic.courierPrimary,
                      AppThemeArabic.courierAccent,
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            _stageIcon(stage),
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ø±Ø­Ù„Ø© Ø§Ù„Ø·Ù„Ø¨ Ø§Ù„Ø¬Ø§Ø±ÙŠØ©',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Tajawal',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _stageLabel(stage),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Tajawal',
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      formatUnifiedOrderCode(
                        orderNumber: data['orderNumber'],
                        orderId: data['orderId'],
                        docId: widget.orderId,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Tajawal',
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Ø§Ù„Ø­Ø§Ù„Ø©: ${OrderStatusPalette.displayText(status)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Tajawal',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if ((data['clientName'] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Ø§Ù„Ø¹Ù…ÙŠÙ„: ${data['clientName']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Tajawal',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 14,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ø³ÙŠØ± Ø§Ù„ØªÙ†ÙÙŠØ°',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppThemeArabic.courierTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _stageDescription(stage),
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 14,
                        color: AppThemeArabic.courierTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildStageTimeline(stage),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        AppThemeArabic.courierPrimary.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ø¬Ø§Ø± ÙØªØ­ Ø´Ø§Ø´Ø© Ø§Ù„ØªÙ†ÙÙŠØ° Ø§Ù„Ù…Ù†Ø§Ø³Ø¨Ø©',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontWeight: FontWeight.w800,
                              color: AppThemeArabic.courierTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ø³ÙŠØªÙ… ØªØ­ÙˆÙŠÙ„Ùƒ ØªÙ„Ù‚Ø§Ø¦ÙŠÙ‹Ø§ Ø¥Ù„Ù‰ ${_stageLabel(stage)} Ø®Ù„Ø§Ù„ Ù„Ø­Ø¸Ø§Øª.',
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              color: AppThemeArabic.courierTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      ),
    );
  }
}


